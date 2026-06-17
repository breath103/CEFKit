import SwiftUI

/// SwiftUI wrapper around an externally-owned `CEFWebView`.
///
/// Tab-shaped UIs create the `CEFWebView` once per tab and hand the same
/// instance to this representable for the tab's lifetime. Toggling tabs with
/// `if selected { ... }` would tear down the `NSView` and kill the renderer
/// process. Mount every tab continuously (e.g. `ZStack` + `opacity`) and
/// only the selected one becomes visible.
public struct CEFWebViewRepresentable: NSViewRepresentable {
    public let webView: CEFWebView

    public init(_ webView: CEFWebView) {
        self.webView = webView
    }

    public func makeNSView(context: Context) -> CEFWebView {
        webView
    }

    public func updateNSView(_ nsView: CEFWebView, context: Context) {}
}
