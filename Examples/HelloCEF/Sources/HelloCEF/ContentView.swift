import CEFKit
import SwiftUI

/// Every awake tab's CEFWebViewRepresentable stays mounted in the ZStack;
/// only the selected one is visible and hit-testable. Hibernated tabs are
/// absent from the ZStack (no CEFView to mount) and auto-wake when selected.
struct ContentView: View {
    @Bindable var store: TabStore

    var body: some View {
        NavigationSplitView {
            List(selection: $store.selectedID) {
                ForEach(store.tabs) { tab in
                    TabRow(tab: tab).tag(tab.id)
                }
            }
            .navigationTitle("Tabs")
            .toolbar {
                ToolbarItem {
                    Button { store.newTab() } label: { Image(systemName: "plus") }
                        .help("New tab")
                }
            }
            .frame(minWidth: 220)
        } detail: {
            VStack(spacing: 0) {
                AddressBar(tab: store.tabs.first { $0.id == store.selectedID })
                ZStack {
                    ForEach(store.tabs) { tab in
                        if let webView = tab.webView {
                            CEFWebViewRepresentable(webView)
                                .opacity(tab.id == store.selectedID ? 1 : 0)
                                .allowsHitTesting(tab.id == store.selectedID)
                        }
                    }
                }
            }
        }
        .onChange(of: store.selectedID) { _, newID in
            // Selecting a hibernated tab wakes it immediately so the user
            // sees a live page instead of an empty detail area.
            guard let id = newID,
                  let tab = store.tabs.first(where: { $0.id == id }),
                  tab.isHibernated
            else { return }
            tab.wake()
        }
    }
}
