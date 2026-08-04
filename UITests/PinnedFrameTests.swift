import XCTest

// The redesign's new invariant: control keys occupy identical frames on
// every level. Keys are plain UILabels, so they surface as staticTexts.
// PRECONDITION (same as KeyboardHeightTests): Typikey enabled on the
// simulator and Connect Hardware Keyboard OFF.
final class PinnedFrameTests: XCTestCase {

    func testPinnedKeysIdenticalAcrossLevels() {
        let app = launchToTypikey()

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
        let app = launchToTypikey()
        app.staticTexts["want"].tap()
        let field = practiceField(in: app)
        let value = field.value as? String ?? ""
        XCTAssertTrue(value.contains("Want"),
                      "tapping the 'want' cell should insert 'Want ' (sentence-start capitalization), got: \(value)")
    }

    func testClearAllRequiresArmingTap() {
        let app = launchToTypikey()
        app.staticTexts["want"].tap()
        var value = practiceField(in: app).value as? String ?? ""
        XCTAssertTrue(value.contains("Want"), "setup: word not inserted")

        app.staticTexts["Clear all"].tap()
        value = practiceField(in: app).value as? String ?? ""
        XCTAssertTrue(value.contains("Want"), "first tap must only arm, not clear")
        XCTAssertTrue(app.staticTexts["tap again"].waitForExistence(timeout: 2),
                      "armed clear-all should relabel to 'tap again'")

        app.staticTexts["tap again"].tap()
        value = practiceField(in: app).value as? String ?? ""
        XCTAssertFalse(value.contains("Want"), "second tap should clear the text")
    }

    func testManualLevelSurvivesReshow() {
        let app = launchToTypikey()
        app.staticTexts["abc"].tap()
        XCTAssertTrue(app.staticTexts["q"].waitForExistence(timeout: 3), "letters level did not open")
        app.staticTexts["⌄"].tap() // dismiss keyboard
        practiceField(in: app).tap() // same field, same signature
        XCTAssertTrue(app.staticTexts["q"].waitForExistence(timeout: 5),
                      "manual level was reset on re-show — intent mapping must not refire for an unchanged field signature")
    }

    // MARK: helpers

    private func launchToTypikey() -> XCUIApplication {
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
                      "Typikey home level not visible — is Typikey the active keyboard?")
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
