import XCTest

// TouchChat's behavior, and the reason it feels alive: after "I am", the
// verb keys show their -ing form. The cell must not move — only its label
// changes — so this asserts both halves: the word becomes "going", and the
// key is still in the same place on the board.
final class GrammarTests: XCTestCase {
    func testVerbKeysFollowTheSentence() {
        let app = XCUIApplication()
        app.launch()

        let field = app.textViews.firstMatch.exists ? app.textViews.firstMatch : app.textFields.firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 10), "practice field not found")
        field.tap()

        let continueButton = app.buttons["Continue"]
        if continueButton.waitForExistence(timeout: 3) {
            continueButton.tap()
            field.tap()
        }

        XCTAssertTrue(app.staticTexts["Home"].waitForExistence(timeout: 10),
                      "Typikey home board not visible — is Typikey the active keyboard?")
        guard let baseFrame = gridKey(app, "go")?.frame else {
            return XCTFail("the 'go' key is not on the home board")
        }

        // "I" then "am": "I" is a grid word, "am" is typed on the letters
        // level — the same path a user takes.
        gridKey(app, "I")?.tap()
        app.staticTexts["abc"].tap()
        app.staticTexts["a"].firstMatch.tap()
        app.staticTexts["m"].firstMatch.tap()
        app.staticTexts["Home"].tap()

        let going = app.staticTexts["going"]
        XCTAssertTrue(going.waitForExistence(timeout: 5),
                      "after 'I am' the go key should read 'going'")
        guard let relabelled = gridKey(app, "going") else {
            return XCTFail("'going' is not on the board")
        }
        XCTAssertEqual(relabelled.frame.minX, baseFrame.minX, accuracy: 2,
                       "the relabelled key moved — grid positions must never change")
        XCTAssertEqual(relabelled.frame.minY, baseFrame.minY, accuracy: 2,
                       "the relabelled key moved — grid positions must never change")
    }

    /// A label can appear both as a suggestion chip and as a grid key. The
    /// grid sits below the suggestion bar, so the lowest match is the key.
    private func gridKey(_ app: XCUIApplication, _ label: String) -> XCUIElement? {
        let matches = app.staticTexts.matching(NSPredicate(format: "label == %@", label))
        guard matches.count > 0 else { return nil }
        return (0..<matches.count)
            .map { matches.element(boundBy: $0) }
            .filter(\.exists)
            .max { $0.frame.minY < $1.frame.minY }
    }
}
