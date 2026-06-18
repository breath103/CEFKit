import CEFKit
import Foundation
import Observation

@Observable
final class TabStore: NSObject {
    var tabs: [BrowserTab] = []

    var selectedID: BrowserTab.ID? {
        didSet { selectedTab?.wake() }
    }

    var selectedTab: BrowserTab? {
        tabs.first { $0.id == selectedID }
    }

    func newTab(_ url: URL = URL(string: "https://example.com")!) {
        let tab = BrowserTab(url: url)
        tab.navigationDelegate = self
        tabs.append(tab)
        selectedID = tab.id
    }
}

extension TabStore: CEFNavigationDelegate {
    func webView(
        _: CEFWebView,
        requestsNewTabFor url: URL?,
        userGesture _: Bool,
        disposition: CEFTabDisposition
    ) -> CEFWebView? {
        let shell = CEFWebView.popupView()
        let target = url ?? URL(string: "about:blank")!
        let tab = BrowserTab(adopting: shell, targetURL: target)
        tab.navigationDelegate = self
        tabs.append(tab)
        if disposition == .newForegroundTab {
            selectedID = tab.id
        }
        return shell
    }
}
