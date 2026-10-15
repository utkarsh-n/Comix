import XCTest

final class ComixUITests: XCTestCase {
    func testSampleExportAndPDFPreview() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing"]
        app.launch()
        app.buttons["sampleComic"].tap()
        XCTAssertTrue(app.buttons["exportComic"].waitForExistence(timeout: 15))
        app.buttons["Preview"].tap()
        XCTAssertTrue(app.staticTexts["1 / 3 · Pinch to zoom"].waitForExistence(timeout: 5))
        app.buttons["Done"].tap()
        app.buttons["exportComic"].tap()
        XCTAssertTrue(app.buttons["createExport"].waitForExistence(timeout: 5))
        app.buttons["createExport"].tap()
        XCTAssertTrue(app.buttons["shareExport"].waitForExistence(timeout: 20))
        XCTAssertTrue(app.staticTexts["Your EPUB is ready"].exists)
        app.segmentedControls.buttons["PDF"].tap()
        app.buttons["createExport"].tap()
        XCTAssertTrue(app.staticTexts["Your PDF is ready"].waitForExistence(timeout: 20))
        app.swipeUp()
        XCTAssertTrue(app.buttons["previewPDF"].waitForExistence(timeout: 5))
        app.buttons["previewPDF"].tap()
        XCTAssertTrue(app.navigationBars["PDF preview"].waitForExistence(timeout: 5))
    }
}
