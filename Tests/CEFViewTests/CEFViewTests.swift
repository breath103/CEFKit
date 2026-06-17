import XCTest
@testable import CEFView

final class CEFViewTests: XCTestCase {
    func testTypesAreExposed() {
        // Just exercise the import — runtime CEF init requires bundle embedding.
        _ = CEFApplication.self
        _ = CEFView.self
    }
}
