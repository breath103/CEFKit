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

struct TabRow: View {
    let tab: BrowserTab
    var body: some View {
        HStack(spacing: 6) {
            FaviconView(image: tab.webView.observable.favicon?.image)
            if tab.webView.observable.isLoading {
                ProgressView().controlSize(.small)
            }
            Text(tabLabel)
                .lineLimit(1)
                .truncationMode(.tail)
        }
    }

    private var tabLabel: String {
        let title = tab.webView.observable.title
        if let title, !title.isEmpty { return title }
        return tab.webView.observable.url?.host ?? "new tab"
    }
}

struct FaviconView: View {
    let image: NSImage?
    var body: some View {
        Group {
            if let image {
                Image(nsImage: image).resizable().interpolation(.high)
            } else {
                Image(systemName: "globe").foregroundStyle(.secondary)
            }
        }
        .frame(width: 16, height: 16)
    }
}

struct AddressBar: View {
    let tab: BrowserTab?
    var body: some View {
        HStack(spacing: 8) {
            Button { tab?.webView.goBack() } label: { Image(systemName: "chevron.left") }
                .disabled(tab?.webView.observable.canGoBack != true)
                .help("Back")
            Button { tab?.webView.goForward() } label: { Image(systemName: "chevron.right") }
                .disabled(tab?.webView.observable.canGoForward != true)
                .help("Forward")
            if tab?.webView.observable.isLoading == true {
                Button { tab?.webView.stopLoading() } label: { Image(systemName: "xmark") }
                    .help("Stop")
            } else {
                Button { tab?.webView.reload() } label: { Image(systemName: "arrow.clockwise") }
                    .disabled(tab == nil)
                    .help("Reload")
            }
            FaviconView(image: tab?.webView.observable.favicon?.image)
            Text(tab?.webView.observable.url?.absoluteString ?? "")
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
    @ObservedObject var store: TabStore

    var body: some View {
        NavigationSplitView {
            List(selection: Binding(
                get: { store.selectedID },
                set: { store.selectedID = $0 }
            )) {
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

    func makeMenu() {
        // Minimal application menu — without this Cmd+Q is dead.
        // CEFApplication's NSApplication subclass overrides `terminate:`
        // to call CefQuitMessageLoop(), so the standard Quit item unwinds
        // CEF cleanly.
        let appName = ProcessInfo.processInfo.processName
        let mainMenu = NSMenu()
        let appItem = NSMenuItem()
        let appMenu = NSMenu()
        appMenu.addItem(
            withTitle: "Quit \(appName)",
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        )
        appItem.submenu = appMenu
        mainMenu.addItem(appItem)
        NSApp.mainMenu = mainMenu
    }

    func makeWindow() {
        store.newTab(URL(string: "https://news.ycombinator.com")!)
        store.newTab(URL(string: "https://example.com")!)

        window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1200, height: 800),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered, defer: false
        )
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
        .appendingPathComponent(Bundle.main.bundleIdentifier ?? "org.example.HelloCEF")
)

exit(Int32(CEFApplication.run(configuration: config) {
    NSApp.delegate = delegate
    delegate.makeMenu()
    delegate.makeWindow()
}))
