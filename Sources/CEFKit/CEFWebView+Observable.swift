@_exported import CEFViewObjC
import ObjectiveC

private var observableKey: UInt8 = 0

public extension CEFWebView {
    /// Per-webView lazy singleton `@Observable` bridge for SwiftUI binding.
    /// Same instance every call — safe to read from view bodies.
    var observable: CEFWebViewObservable {
        if let existing = objc_getAssociatedObject(self, &observableKey) as? CEFWebViewObservable {
            return existing
        }
        let made = CEFWebViewObservable(self)
        objc_setAssociatedObject(self, &observableKey, made, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        return made
    }
}
