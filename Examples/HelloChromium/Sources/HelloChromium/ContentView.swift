import ChromiumKit
import SwiftUI

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
                AddressBar(tab: store.selectedTab)
                ZStack {
                    ForEach(store.tabs) { tab in
                        if let webView = tab.webView {
                            ChromiumWebViewRepresentable(webView)
                                .opacity(tab.id == store.selectedID ? 1 : 0)
                                .allowsHitTesting(tab.id == store.selectedID)
                        }
                    }
                }
            }
        }
        .sheet(item: $store.pendingDialog) { dialog in
            JSDialogSheet(dialog: dialog)
        }
    }
}

private struct JSDialogSheet: View {
    @Bindable var dialog: PendingDialog

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let host = dialog.origin?.host {
                Text(host).font(.caption).foregroundStyle(.secondary)
            }
            Text(dialog.message).font(.body)
            if case .prompt = dialog.kind {
                TextField("", text: $dialog.promptText).textFieldStyle(.roundedBorder)
            }
            HStack {
                Spacer()
                if case .alert = dialog.kind {
                    Button("OK") { dialog.respond(.ok) }.keyboardShortcut(.defaultAction)
                } else {
                    Button("Cancel") { dialog.respond(.cancel) }.keyboardShortcut(.cancelAction)
                    if case .prompt = dialog.kind {
                        Button("OK") { dialog.respond(.okWithText(dialog.promptText)) }
                            .keyboardShortcut(.defaultAction)
                    } else {
                        Button("OK") { dialog.respond(.ok) }.keyboardShortcut(.defaultAction)
                    }
                }
            }
        }
        .padding(20)
        .frame(minWidth: 360)
    }
}
