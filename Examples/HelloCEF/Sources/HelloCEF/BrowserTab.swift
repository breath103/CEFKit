// A tab owns its CEFWebView for the tab's whole lifetime, so switching
// tabs in the UI is a visibility toggle rather than a teardown.

import CEFKit
import Foundation

final class BrowserTab: Identifiable {
    let id = UUID()
    let webView: CEFWebView

    init(url: URL) {
        webView = CEFWebView(frame: .zero, url: url)
    }
}
