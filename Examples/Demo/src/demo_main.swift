// Swift consumer of the ChromiumKit package. Exercises:
//   - ChromiumApplication.run(configuration:setup:) with a ChromiumConfiguration
//   - ChromiumWebView creation + delegate + load/eval
//   - async/await JS eval with typed decoding

import AppKit
import ChromiumKit

final class DemoDelegate: NSObject, NSApplicationDelegate, ChromiumNavigationDelegate {
    var window: NSWindow!
    var webView: ChromiumWebView!

    func makeWindow() {
        let rect = NSRect(x: 0, y: 0, width: 1024, height: 768)
        window = NSWindow(
            contentRect: rect,
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "ChromiumWebView Demo"
        window.center()

        webView = ChromiumWebView(frame: rect, url: URL(string: "https://example.com")!)
        webView.navigationDelegate = self
        window.contentView = webView
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    // MARK: ChromiumNavigationDelegate

    func webView(_ webView: ChromiumWebView, didStartProvisionalNavigationTo url: URL?) {
        print("→ start:", url?.absoluteString ?? "<nil>")
    }

    func webView(_ webView: ChromiumWebView, didFinishNavigationTo url: URL?, statusCode code: Int32) {
        print("← finish:", url?.absoluteString ?? "<nil>", "code=\(code)")
        Task { @MainActor in
            do {
                let title = try await webView.evaluateJavaScript("document.title", as: String.self)
                let h1Count = try await webView.evaluateJavaScript(
                    "document.querySelectorAll('h1').length", as: Int.self
                )
                print("   title=\(title)  h1Count=\(h1Count)")
            } catch {
                print("   eval error:", error.localizedDescription)
            }
        }
    }

    func webView(_ webView: ChromiumWebView, didFailNavigationWith error: Error) {
        print("✗ fail:", error.localizedDescription)
    }

    func webView(_ webView: ChromiumWebView, didChangeTitle title: String?) {
        print("• title:", title ?? "<nil>")
        window.title = title ?? "ChromiumWebView Demo"
    }

    func webView(_ webView: ChromiumWebView, didChangeLoadingState isLoading: Bool) {
        print("• loading:", isLoading)
    }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        true
    }
}

let delegate = DemoDelegate()
let config = ChromiumConfiguration()
config.cachePath = FileManager.default
    .urls(for: .cachesDirectory, in: .userDomainMask)[0]
    .appendingPathComponent("work.mirror.cefview.demo")

exit(Int32(ChromiumApplication.run(configuration: config) {
    NSApp.delegate = delegate
    delegate.makeWindow()
}))
