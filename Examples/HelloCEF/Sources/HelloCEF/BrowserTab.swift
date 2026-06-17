// Model layer: a tab owns its CEFWebView for the tab's whole lifetime, so
// switching tabs in the UI is a visibility toggle rather than a teardown.

import CEFKit
import Foundation

final class BrowserTab: Identifiable {
    let id = UUID()
    let webView: CEFWebView

    init(url: URL) {
        webView = CEFWebView(frame: .zero, url: url)
    }
}

final class TabStore: ObservableObject {
    @Published var tabs: [BrowserTab] = []
    @Published var selectedID: BrowserTab.ID?

    func newTab(_ url: URL = URL(string: "https://example.com")!) {
        let tab = BrowserTab(url: url)
        tabs.append(tab)
        selectedID = tab.id
    }
}
