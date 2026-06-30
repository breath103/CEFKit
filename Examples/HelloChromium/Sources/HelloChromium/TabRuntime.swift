import AppKit
import ChromiumKit
import Foundation
import Observation
import SwiftData

/// Owns the live, non-persistable `ChromiumWebView`s and keeps each one synced
/// into its `TabRecord`. The web view is an NSView-backed browser that must NOT
/// be persisted, so it lives here (keyed by the record's stable
/// `persistentModelID`) rather than on the model. Creating a web view = waking
/// the tab; dropping it = hibernating. Whenever the page navigates, KVO
/// callbacks write `url` / `title` / `faviconPNG` back into the record, which
/// persists and re-renders through SwiftData's Observation.
@MainActor
@Observable
final class TabRuntime: NSObject {
    private var live: [PersistentIdentifier: LiveTab] = [:]

    /// Set once at launch. The context new tabs (incl. popups) are inserted into.
    @ObservationIgnored var context: ModelContext!
    /// The current session new tabs belong to.
    @ObservationIgnored var session: Session!

    /// The live web view for a record, or nil if the tab is hibernated. Pure
    /// lookup — safe to call from a SwiftUI view body.
    func liveWebView(for record: TabRecord) -> ChromiumWebView? {
        live[record.persistentModelID]?.webView
    }

    func isAwake(_ record: TabRecord) -> Bool {
        live[record.persistentModelID] != nil
    }

    /// Wake a tab: create its web view (loading the record's URL) if absent, and
    /// start syncing navigation back into the record. Idempotent.
    @discardableResult
    func wake(_ record: TabRecord) -> ChromiumWebView {
        if let existing = live[record.persistentModelID] { return existing.webView }
        let webView = ChromiumWebView(frame: .zero, url: record.url)
        webView.navigationDelegate = self
        live[record.persistentModelID] = LiveTab(webView: webView, record: record)
        return webView
    }

    /// Hibernate a tab: drop the live web view. The record keeps the last
    /// url/title/favicon, so the row still renders and a later `wake` restores it.
    func hibernate(_ record: TabRecord) {
        live[record.persistentModelID] = nil
    }

    /// Open a new foreground tab in the session and select it.
    @discardableResult
    func newTab(in session: Session, url: URL = URL(string: "https://example.com")!) -> TabRecord {
        let record = insertTab(url: url, into: session)
        session.selectedTabID = record.id
        return record
    }

    private func insertTab(url: URL, into session: Session) -> TabRecord {
        let nextIndex = (session.tabs.map(\.sortIndex).max() ?? -1) + 1
        let record = TabRecord(url: url, sortIndex: nextIndex, session: session)
        context.insert(record)
        return record
    }

    /// Adopt an already-built web view (a popup shell) for a record.
    private func adopt(_ webView: ChromiumWebView, for record: TabRecord) {
        webView.navigationDelegate = self
        live[record.persistentModelID] = LiveTab(webView: webView, record: record)
    }

    /// A live web view plus the KVO observations that mirror its navigation
    /// state into a `TabRecord`. Scopes those observations to the web view's
    /// lifetime in the registry — dropping the `LiveTab` invalidates them.
    private final class LiveTab {
        let webView: ChromiumWebView
        private weak var record: TabRecord?
        private var observations: [NSKeyValueObservation] = []
        private var faviconImageObservation: NSKeyValueObservation?

        init(webView: ChromiumWebView, record: TabRecord) {
            self.webView = webView
            self.record = record

            observations.append(webView.observe(\.url, options: [.new]) { [weak self] _, change in
                guard let newURL = change.newValue ?? nil else { return }
                MainActor.assumeIsolated { self?.record?.url = newURL }
            })
            observations.append(webView.observe(\.title, options: [.new]) { [weak self] _, change in
                MainActor.assumeIsolated { self?.record?.title = (change.newValue ?? nil) ?? "" }
            })
            // The favicon ref is replaced on each favicon-URL change; its image
            // lands asynchronously, so re-bind to the new ref's image each time.
            observations.append(webView.observe(\.favicon, options: [.new, .initial]) { [weak self] view, _ in
                MainActor.assumeIsolated { self?.bindFavicon(view.favicon) }
            })
        }

        private func bindFavicon(_ favicon: CEFFaviconRef?) {
            faviconImageObservation = favicon?.observe(\.image, options: [.new, .initial]) { [weak self] _, change in
                let image = change.newValue ?? nil
                MainActor.assumeIsolated { self?.record?.faviconPNG = image?.pngData }
            }
        }
    }
}

extension TabRuntime: ChromiumNavigationDelegate {
    // CEF invokes this on the main thread; hop into the actor to touch the
    // context and session safely.
    nonisolated func webView(
        _: ChromiumWebView,
        requestsNewTabFor url: URL?,
        userGesture _: Bool,
        disposition: CEFTabDisposition
    ) -> ChromiumWebView? {
        MainActor.assumeIsolated {
            let shell = ChromiumWebView.popupView()
            let target = url ?? URL(string: "about:blank")!
            let record = insertTab(url: target, into: session)
            adopt(shell, for: record)
            if disposition == .newForegroundTab {
                session.selectedTabID = record.id
            }
            return shell
        }
    }
}

private extension NSImage {
    var pngData: Data? {
        guard let tiff = tiffRepresentation, let rep = NSBitmapImageRep(data: tiff) else { return nil }
        return rep.representation(using: .png, properties: [:])
    }
}
