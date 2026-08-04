import XCTest

// The redesign's new invariant: control keys occupy identical frames on
// every level. Keys are plain UILabels, so they surface as staticTexts.
// PRECONDITION (same as KeyboardHeightTests): BigKeys enabled on the
// simulator and Connect Hardware Keyboard OFF.
final class PinnedFrameTests: XCTestCase {

    func testPinnedKeysIdenticalAcrossLevels() {
        let app = launchToBigKeys()

        let pinned = ["Home", "Clear all", "⌫ word", "←", "⌫", "→", "⌄"]
        let baseline = frames(of: pinned, in: app)
        for (label, frame) in baseline {
            XCTAssertFalse(frame.isEmpty, "\(label) missing on home level")
        }

        app.staticTexts["Categories"].tap()
        assertFrames(baseline, in: app, level: "categories")

        app.staticTexts["Core"].tap()
        assertFrames(baseline, in: app, level: "words")

        app.staticTexts["Home"].tap()
        app.staticTexts["abc"].tap()
        assertFrames(baseline, in: app, level: "letters")

        app.staticTexts["123"].tap()
        assertFrames(baseline, in: app, level: "numbers")
    }

    func testHomeWordTapInsertsWord() {
        let app = launchToBigKeys()
        app.staticTexts["want"].tap()
        let field = practiceField(in: app)
        let value = field.value as? String ?? ""
        XCTAssertTrue(value.contains("Want"),
                      "tapping the 'want' cell should insert 'Want ' (sentence-start capitalization), got: \(value)")
    }

    // MARK: helpers

    private func launchToBigKeys() -> XCUIApplication {
        let app = XCUIApplication()
        app.launch()
        XCUIDevice.shared.orientation = .portrait
        let field = practiceField(in: app)
        XCTAssertTrue(field.waitForExistence(timeout: 10), "practice field not found")
        field.tap()
        let continueButton = app.buttons["Continue"]
        if continueButton.waitForExistence(timeout: 3) {
            continueButton.tap()
            practiceField(in: app).tap()
        }
        XCTAssertTrue(app.staticTexts["Home"].waitForExistence(timeout: 5),
                      "BigKeys home level not visible — is BigKeys the active keyboard?")
        return app
    }

    private func practiceField(in app: XCUIApplication) -> XCUIElement {
        app.textFields.firstMatch.exists ? app.textFields.firstMatch : app.textViews.firstMatch
    }

    private func frames(of labels: [String], in app: XCUIApplication) -> [String: CGRect] {
        var out: [String: CGRect] = [:]
        for label in labels { out[label] = app.staticTexts[label].frame }
        return out
    }

    private func assertFrames(_ baseline: [String: CGRect], in app: XCUIApplication, level: String) {
        for (label, frame) in baseline {
            let now = app.staticTexts[label].frame
            XCTAssertEqual(now.origin.x, frame.origin.x, accuracy: 1.0, "\(label) moved (x) on \(level)")
            XCTAssertEqual(now.origin.y, frame.origin.y, accuracy: 1.0, "\(label) moved (y) on \(level)")
        }
    }
}
