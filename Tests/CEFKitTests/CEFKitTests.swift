import XCTest
@testable import CEFKit

final class CEFKitTests: XCTestCase {
    func testTypesAreExposed() {
        // Just exercise the import — runtime CEF init requires bundle embedding.
        _ = CEFApplication.self
        _ = CEFWebView.self
        _ = CEFConfiguration.self
    }
}
