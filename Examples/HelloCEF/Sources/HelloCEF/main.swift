// HelloCEF — basic SwiftUI tabbed-browser shell on top of CEFKit.
//
// Each BrowserTab owns its CEFWebView for the tab's whole lifetime. Every
// tab's view stays mounted in a ZStack; only the selected one is visible
// and hit-testable. This preserves renderer state (scroll, JS heap, forms,
// WebSockets) across tab switches.

import AppKit
import CEFKit
import SwiftUI

final class BrowserTab: Identifiable {
    let id = UUID()
    let webView: CEFWebView

    init(url: URL) {
        self.webView = CEFWebView(frame: .zero, url: url)
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

struct ContentView: View {
    @ObservedObject var store: TabStore

    var body: some View {
        NavigationSplitView {
            List(selection: $store.selectedID) {
                ForEach(store.tabs) { tab in
                    Text(tab.webView.url?.host ?? "new tab")
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .tag(tab.id)
                }
            }
            .navigationTitle("Tabs")
            .toolbar {
                ToolbarItem {
                    Button { store.newTab() } label: { Image(systemName: "plus") }
                        .help("New tab")
                }
            }
            .frame(minWidth: 180)
        } detail: {
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

final class AppDelegate: NSObject, NSApplicationDelegate {
    let store = TabStore()
    var window: NSWindow!

    func makeWindow() {
        store.newTab(URL(string: "https://news.ycombinator.com")!)
        store.newTab(URL(string: "https://example.com")!)

        window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1200, height: 800),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered, defer: false)
        window.title = "HelloCEF"
        window.center()
        window.contentView = NSHostingView(rootView: ContentView(store: store))
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}

let delegate = AppDelegate()

let config = CEFConfiguration(
    userAgent: "HelloCEF/0.2 (CEFKit; macOS)",
    cachePath: FileManager.default
        .urls(for: .cachesDirectory, in: .userDomainMask)[0]
        .appendingPathComponent(Bundle.main.bundleIdentifier ?? "org.example.HelloCEF"))

exit(Int32(CEFApplication.run(configuration: config) {
    NSApp.delegate = delegate
    delegate.makeWindow()
}))
