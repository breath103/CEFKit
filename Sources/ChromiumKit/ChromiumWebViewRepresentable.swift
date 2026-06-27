import SwiftUI

/// SwiftUI wrapper around an externally-owned `ChromiumWebView`.
///
/// Tab-shaped UIs create the `ChromiumWebView` once per tab and hand the same
/// instance to this representable for the tab's lifetime. Toggling tabs with
/// `if selected { ... }` would tear down the `NSView` and kill the renderer
/// process. Mount every tab continuously (e.g. `ZStack` + `opacity`) and
/// only the selected one becomes visible.
public struct ChromiumWebViewRepresentable: NSViewRepresentable {
    public let webView: ChromiumWebView

    public init(_ webView: ChromiumWebView) {
        self.webView = webView
    }

    public func makeNSView(context: Context) -> ChromiumWebView {
        webView
    }

    public func updateNSView(_ nsView: ChromiumWebView, context: Context) {}
}
