import Foundation
import Observation

@Observable
final class TabStore {
    var tabs: [BrowserTab] = []

    var selectedID: BrowserTab.ID? {
        didSet { selectedTab?.wake() }
    }

    var selectedTab: BrowserTab? {
        tabs.first { $0.id == selectedID }
    }

    func newTab(_ url: URL = URL(string: "https://example.com")!) {
        let tab = BrowserTab(url: url)
        tabs.append(tab)
        selectedID = tab.id
    }
}
