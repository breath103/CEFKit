import CEFKit
import SwiftUI

/// Every tab's CEFWebViewRepresentable stays mounted in the ZStack; only the
/// selected one is visible and hit-testable. Tearing down + recreating CEF
/// views on tab-switch would be expensive and would lose page state.
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
                        CEFWebViewRepresentable(tab.webView)
                            .opacity(tab.id == store.selectedID ? 1 : 0)
                            .allowsHitTesting(tab.id == store.selectedID)
                    }
                }
            }
        }
    }
}
