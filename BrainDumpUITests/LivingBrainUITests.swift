import XCTest

/// A deterministic fixture isolates category interaction from training and saved user data.
final class LivingBrainUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    private func launchFixture() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += ["--ui-testing", "--living-brain-fixture"]
        app.launch()
        return app
    }

    @MainActor
    func testCategoryTilesRemainHittableAfterRepeatedScrolling() {
        let app = launchFixture()
        let scroll = app.scrollViews["thought-category-scroll"]
        XCTAssertTrue(scroll.waitForExistence(timeout: 10))
        let first = app.descendants(matching: .any)["thought-tile-0"].firstMatch
        XCTAssertTrue(first.waitForExistence(timeout: 5))
        for _ in 0..<3 {
            scroll.swipeUp()
            scroll.swipeDown()
        }
        // Bring the initial tile back into view without assuming a precise scroll offset.
        for _ in 0..<8 {
            if first.isHittable { break }
            scroll.swipeDown()
        }
        XCTAssertTrue(first.isHittable, "The category tile should remain reachable after scrolling.")
        first.press(forDuration: 0.7)
        XCTAssertTrue(app.descendants(matching: .any)["thought-detail-text"].firstMatch.waitForExistence(timeout: 5))
    }

    @MainActor
    func testNewThoughtCanBeCapturedAndReadInCategory() {
        let app = launchFixture()
        let add = app.buttons["Add thought"]
        XCTAssertTrue(add.waitForExistence(timeout: 10))
        add.tap()
        let editor = app.textViews["thought-editor-text"]
        XCTAssertTrue(editor.waitForExistence(timeout: 5))
        editor.tap()
        editor.typeText("A newly captured living brain thought")
        app.buttons["thought-save"].tap()
        let tile = app.descendants(matching: .any).matching(NSPredicate(format: "identifier BEGINSWITH 'thought-tile-' AND label CONTAINS 'A newly captured living brain thought'")).firstMatch
        XCTAssertTrue(tile.waitForExistence(timeout: 5))
        XCTAssertTrue(tile.isHittable)
        tile.press(forDuration: 0.7)
        XCTAssertTrue(app.descendants(matching: .any)["thought-detail-text"].firstMatch.waitForExistence(timeout: 5))
    }

    @MainActor
    func testLongPressShowsCompleteThoughtAndDismissesBackToCategory() {
        let app = launchFixture()
        let tile = app.descendants(matching: .any)["thought-tile-0"].firstMatch
        XCTAssertTrue(tile.waitForExistence(timeout: 10))
        tile.press(forDuration: 0.7)
        let fullText = app.descendants(matching: .any)["thought-detail-text"].firstMatch
        XCTAssertTrue(fullText.waitForExistence(timeout: 5))
        XCTAssertTrue(fullText.label.contains("The complete thought remains readable after opening the expanded tile."))
        let close = app.buttons["thought-detail-close"]
        XCTAssertTrue(close.isHittable)
        close.tap()
        XCTAssertTrue(app.scrollViews["thought-category-scroll"].waitForExistence(timeout: 5))
        XCTAssertTrue(tile.isHittable)
    }
}
