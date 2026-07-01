import XCTest

final class JSDialogUITests: XCTestCase {
    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()
        // Wait for at least one tab's webView to finish initial load so the
        // address bar surfaces (page-text-via-title polling needs it).
        XCTAssertTrue(app.buttons["addressBar.display"].waitForExistence(timeout: 10))
    }

    override func tearDownWithError() throws {
        app.terminate()
    }

    /// alert() pops a sheet with ONLY an OK button. Clicking OK lets the
    /// page resume — `document.title` becomes "alert-done".
    func testAlertShowsSheetAndResumes() {
        navigate(toJS: "alert('hi');document.title='alert-done'")

        let sheet = app.sheets.firstMatch
        XCTAssertTrue(sheet.waitForExistence(timeout: 5), "alert sheet did not appear")
        let ok = sheet.buttons["jsDialog.ok"]
        XCTAssertTrue(ok.waitForExistence(timeout: 2), "OK button missing")
        XCTAssertFalse(sheet.buttons["jsDialog.cancel"].exists, "alert sheet must NOT have Cancel")
        ok.click()

        XCTAssertTrue(waitForTitle("alert-done"), "page never resumed after alert OK")
    }

    /// confirm() OK returns true.
    func testConfirmOK() {
        navigate(toJS: "document.title='confirm='+confirm('ok?')")

        let sheet = app.sheets.firstMatch
        XCTAssertTrue(sheet.waitForExistence(timeout: 5), "confirm sheet did not appear")
        XCTAssertTrue(sheet.buttons["jsDialog.cancel"].exists, "confirm sheet missing Cancel")
        sheet.buttons["jsDialog.ok"].click()

        XCTAssertTrue(waitForTitle("confirm=true"))
    }

    /// confirm() Cancel returns false.
    func testConfirmCancel() {
        navigate(toJS: "document.title='confirm='+confirm('ok?')")

        let sheet = app.sheets.firstMatch
        XCTAssertTrue(sheet.waitForExistence(timeout: 5), "confirm sheet did not appear")
        sheet.buttons["jsDialog.cancel"].click()

        XCTAssertTrue(waitForTitle("confirm=false"))
    }

    /// prompt() returns the typed text.
    func testPromptReturnsText() {
        navigate(toJS: "document.title='prompt='+prompt('name?','seed')")

        let sheet = app.sheets.firstMatch
        XCTAssertTrue(sheet.waitForExistence(timeout: 5), "prompt sheet did not appear")

        let field = sheet.textFields.firstMatch
        XCTAssertTrue(field.exists, "prompt sheet missing TextField")
        field.click()
        // Clear the seeded "seed" — cmd+a doesn't reliably select-all in
        // SwiftUI TextField under XCUITest, so backspace one char at a time.
        let seeded = (field.value as? String) ?? ""
        for _ in seeded {
            field.typeKey(.delete, modifierFlags: [])
        }
        field.typeText("kurt")

        sheet.buttons["jsDialog.ok"].click()
        XCTAssertTrue(waitForTitle("prompt=kurt"))
    }

    // MARK: - Helpers

    /// Drive the address bar to a `data:` URL that runs JS on load —
    /// triggers the dialog without needing to click into the opaque CEF view.
    private func navigate(toJS jsBody: String) {
        let html = "<script>\(jsBody)</script>"
        let url = "data:text/html;charset=utf-8,\(html)"
        let display = app.buttons["addressBar.display"]
        XCTAssertTrue(display.waitForExistence(timeout: 5))
        display.click()

        let field = app.textFields["addressBar.field"]
        XCTAssertTrue(field.waitForExistence(timeout: 2))
        field.typeKey("a", modifierFlags: .command)
        field.typeText(url)
        field.typeKey(.return, modifierFlags: [])
    }

    /// The window's titlebar surfaces document.title. Poll for it.
    private func waitForTitle(_ expected: String) -> Bool {
        let predicate = NSPredicate(format: "value CONTAINS %@ OR label CONTAINS %@", expected, expected)
        let match = app.windows.firstMatch.staticTexts.matching(predicate).firstMatch
        return match.waitForExistence(timeout: 5)
    }
}
