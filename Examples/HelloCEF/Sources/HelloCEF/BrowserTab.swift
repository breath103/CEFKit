import AppKit
import CEFKit
import Foundation
import Observation

@Observable
final class BrowserTab: Identifiable {
    let id = UUID()
    private(set) var webView: CEFWebView?

    @ObservationIgnored weak var navigationDelegate: CEFNavigationDelegate? {
        didSet { webView?.navigationDelegate = navigationDelegate }
    }

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

    /// Adopts a CEFWebView whose CefBrowser will arrive via OnAfterCreated
    /// (e.g. the shell view handed back from OnBeforePopup).
    init(adopting view: CEFWebView, targetURL: URL) {
        snapshotURL = targetURL
        webView = view
    }

    func hibernate() {
        guard let webView else { return }
        snapshotTitle = webView.observable.title
        if let liveURL = webView.observable.url { snapshotURL = liveURL }
        snapshotFaviconImage = webView.observable.favicon?.image
        self.webView = nil
    }

    func wake(loading url: URL? = nil) {
        guard webView == nil else { return }
        if let url { snapshotURL = url }
        let view = CEFWebView(frame: .zero, url: snapshotURL)
        view.navigationDelegate = navigationDelegate
        webView = view
    }

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
