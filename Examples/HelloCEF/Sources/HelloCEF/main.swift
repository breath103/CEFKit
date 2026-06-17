// HelloCEF — SwiftUI tabbed-browser shell with reactive title / loading bindings.
//
// Each BrowserTab owns its CEFWebView for the tab's whole lifetime. Every
// tab's view stays mounted in a ZStack; only the selected one is visible
// and hit-testable. Tab labels + loading indicator bind to
// `webView.observable.*` — KVO bridge so SwiftUI redraws when CEF state
// changes.

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

struct TabRow: View {
    let tab: BrowserTab
    var body: some View {
        let o = tab.webView.observable
        let title = (o.title?.isEmpty == false ? o.title : nil) ?? o.url?.host ?? "new tab"
        HStack(spacing: 6) {
            if o.isLoading {
                ProgressView().controlSize(.small)
            }
            Text(title)
                .lineLimit(1)
                .truncationMode(.tail)
        }
    }
}

struct AddressBar: View {
    let tab: BrowserTab?
    var body: some View {
        let o = tab?.webView.observable
        HStack(spacing: 8) {
            Button { tab?.webView.goBack() } label: { Image(systemName: "chevron.left") }
                .disabled(o?.canGoBack != true)
                .help("Back")
            Button { tab?.webView.goForward() } label: { Image(systemName: "chevron.right") }
                .disabled(o?.canGoForward != true)
                .help("Forward")
            Text(o?.url?.absoluteString ?? "")
                .font(.system(.body, design: .monospaced))
                .lineLimit(1)
                .truncationMode(.middle)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(.bar)
        .overlay(Divider(), alignment: .bottom)
    }
}

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
    userAgent: "HelloCEF/0.3 (CEFKit; macOS)",
    cachePath: FileManager.default
        .urls(for: .cachesDirectory, in: .userDomainMask)[0]
        .appendingPathComponent(Bundle.main.bundleIdentifier ?? "org.example.HelloCEF"))

exit(Int32(CEFApplication.run(configuration: config) {
    NSApp.delegate = delegate
    delegate.makeWindow()
}))
