// A tab normally owns its CEFWebView for its whole lifetime so switching
// tabs is a visibility toggle. Hibernation breaks that on purpose: webView
// is released (CEF browser dies), a snapshot of last-known state is kept
// so the sidebar row still has something to render, and wake() builds a
// fresh CEFWebView pointed at the snapshotted URL.

import AppKit
import CEFKit
import Foundation
import Observation

@Observable
final class BrowserTab: Identifiable {
    let id = UUID()
    private(set) var webView: CEFWebView?

    private var snapshotURL: URL
    private var snapshotTitle: String?
    private var snapshotFaviconImage: NSImage?

    var isHibernated: Bool {
        webView == nil
    }

    init(url: URL) {
        snapshotURL = url
        webView = CEFWebView(frame: .zero, url: url)
    }

    func hibernate() {
        guard let webView else { return }
        snapshotTitle = webView.observable.title
        if let liveURL = webView.observable.url { snapshotURL = liveURL }
        snapshotFaviconImage = webView.observable.favicon?.image
        // Releasing the only strong reference triggers CEFWebView.deinit,
        // which closes the CEF browser and reclaims its renderer process.
        self.webView = nil
    }

    func wake(loading url: URL? = nil) {
        guard webView == nil else { return }
        if let url { snapshotURL = url }
        webView = CEFWebView(frame: .zero, url: snapshotURL)
    }

    // Single source for "what to show in chrome" — collapses the live ↔ snapshot
    // dispatch so views don't each re-implement it.

    var displayTitle: String {
        let title = webView?.observable.title ?? snapshotTitle
        if let title, !title.isEmpty { return title }
        return displayURL.host ?? "new tab"
    }

    var displayURL: URL {
        webView?.observable.url ?? snapshotURL
    }

    var displayFavicon: NSImage? {
        webView?.observable.favicon?.image ?? snapshotFaviconImage
    }
}
