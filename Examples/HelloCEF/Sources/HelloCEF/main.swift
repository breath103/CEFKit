// HelloCEF — minimal CEFKit consumer.
//
// Drop a CEFWebView into an NSWindow. Wire the navigation delegate. Run JS
// after the page finishes loading. ~70 lines.

import AppKit
import CEFKit

final class App: NSObject, NSApplicationDelegate, CEFNavigationDelegate {
    var window: NSWindow!
    var webView: CEFWebView!

    func makeWindow() {
        let rect = NSRect(x: 0, y: 0, width: 1100, height: 750)
        window = NSWindow(
            contentRect: rect,
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered, defer: false)
        window.title = "HelloCEF"
        window.center()

        webView = CEFWebView(frame: rect, url: URL(string: "https://news.ycombinator.com")!)
        webView.navigationDelegate = self
        window.contentView = webView
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    // MARK: CEFNavigationDelegate

    func webView(_ webView: CEFWebView, didStartProvisionalNavigationTo url: URL?) {
        NSLog("[HelloCEF] navigating → %@", url?.absoluteString ?? "?")
    }

    func webView(_ webView: CEFWebView, didFinishNavigationTo url: URL?, statusCode code: Int32) {
        NSLog("[HelloCEF] loaded %@ (HTTP %d)", url?.absoluteString ?? "?", code)
        Task { @MainActor in
            do {
                let title = try await webView.evaluateJavaScript("document.title", as: String.self)
                let storyCount = try await webView.evaluateJavaScript(
                    "document.querySelectorAll('.athing').length", as: Int.self)
                NSLog("[HelloCEF] page title: %@", title)
                NSLog("[HelloCEF] stories on page: %d", storyCount)
            } catch {
                NSLog("[HelloCEF] eval error: %@", error.localizedDescription)
            }
        }
    }

    func webView(_ webView: CEFWebView, didChangeTitle title: String?) {
        window.title = title ?? "HelloCEF"
    }

    func webView(_ webView: CEFWebView, didChangeLoadingState isLoading: Bool) {
        NSLog("[HelloCEF] %@", isLoading ? "loading…" : "idle")
    }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool { true }
}

let delegate = App()

let config = CEFConfiguration(
    userAgent: "HelloCEF/0.1 (CEFKit; macOS)",
    cachePath: FileManager.default
        .urls(for: .cachesDirectory, in: .userDomainMask)[0]
        .appendingPathComponent(Bundle.main.bundleIdentifier ?? "org.example.HelloCEF"))

exit(Int32(CEFApplication.run(configuration: config) {
    NSApp.delegate = delegate
    delegate.makeWindow()
}))
