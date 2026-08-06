import XCTest

// A broadcast can only be started by a human through the system picker
// (there is no programmatic start, by design), so the automatable surface
// is the card itself: it must exist on the home screen and carry the
// system picker whose tap target opens the broadcast sheet.
final class ScreenLearningTests: XCTestCase {
    func testScreenLearningCardIsOnHomeScreen() {
        let app = XCUIApplication()
        app.launch()

        let title = app.staticTexts["Learn from my screen"]
        XCTAssertTrue(title.waitForExistence(timeout: 5),
                      "screen-learning card should be on the home screen")
        app.swipeUp()
        XCTAssertTrue(title.exists)
    }
}
