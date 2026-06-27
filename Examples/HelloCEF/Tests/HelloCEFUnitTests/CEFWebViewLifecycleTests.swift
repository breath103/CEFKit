import CEFKit
import XCTest

final class CEFWebViewLifecycleTests: XCTestCase {
    /// CEFWebView holds its observable via objc_setAssociatedObject(RETAIN); the
    /// observable subscribes to KVO on the webView. If anything in that chain
    /// retains the webView back, dropping the last external ref won't dealloc,
    /// and hibernation orphans the renderer process.
    func testWebViewDeallocatesAfterObservableTouched() {
        weak var weakView: CEFWebView?
        autoreleasepool {
            let view = CEFWebView(frame: .zero, url: URL(string: "about:blank")!)
            _ = view.observable
            weakView = view
        }
        XCTAssertNil(weakView, "CEFWebView leaked — observable / KVO retain cycle")
    }
}
