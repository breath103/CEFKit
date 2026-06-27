import ChromiumKit
import XCTest

final class ChromiumWebViewLifecycleTests: XCTestCase {
    /// ChromiumWebView holds its observable via objc_setAssociatedObject(RETAIN); the
    /// observable subscribes to KVO on the webView. If anything in that chain
    /// retains the webView back, dropping the last external ref won't dealloc,
    /// and hibernation orphans the renderer process.
    func testWebViewDeallocatesAfterObservableTouched() {
        weak var weakView: ChromiumWebView?
        autoreleasepool {
            let view = ChromiumWebView(frame: .zero, url: URL(string: "about:blank")!)
            _ = view.observable
            weakView = view
        }
        XCTAssertNil(weakView, "ChromiumWebView leaked — observable / KVO retain cycle")
    }
}
