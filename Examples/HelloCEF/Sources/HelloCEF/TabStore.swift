import Foundation
import Observation

@Observable
final class TabStore {
    var tabs: [BrowserTab] = []
    var selectedID: BrowserTab.ID?

    func newTab(_ url: URL = URL(string: "https://example.com")!) {
        let tab = BrowserTab(url: url)
        tabs.append(tab)
        selectedID = tab.id
    }
}
