@testable import ChromiumKit
import XCTest

final class ChromiumKitTests: XCTestCase {
    func testTypesAreExposed() {
        // Just exercise the import — runtime CEF init requires bundle embedding.
        _ = ChromiumApplication.self
        _ = ChromiumWebView.self
        _ = ChromiumConfiguration.self
    }
}
