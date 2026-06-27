import AppKit
import ChromiumKit
import Foundation
import Observation

@Observable
final class BrowserTab: Identifiable {
    let id = UUID()
    private(set) var webView: ChromiumWebView?

    @ObservationIgnored weak var navigationDelegate: ChromiumNavigationDelegate? {
        didSet { webView?.navigationDelegate = navigationDelegate }
    }

    @ObservationIgnored weak var uiDelegate: ChromiumUIDelegate? {
        didSet { webView?.uiDelegate = uiDelegate }
    }

    private var snapshotURL: URL
    private var snapshotTitle: String?
    private var snapshotFaviconImage: NSImage?

    var isHibernated: Bool {
        webView == nil
    }

    init(url: URL) {
        snapshotURL = url
        let view = ChromiumWebView(frame: .zero, url: url)
        webView = view
    }

    /// Adopts a ChromiumWebView whose CefBrowser will arrive via OnAfterCreated
    /// (e.g. the shell view handed back from OnBeforePopup).
    init(adopting view: ChromiumWebView, targetURL: URL) {
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
        let view = ChromiumWebView(frame: .zero, url: snapshotURL)
        view.navigationDelegate = navigationDelegate
        view.uiDelegate = uiDelegate
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
