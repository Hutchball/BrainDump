import XCTest

/// A deterministic fixture isolates category interaction from training and saved user data.
final class LivingBrainUITests: XCTestCase {
    @MainActor
    func testTrainingRequiresActionsInOrderBeforeFinishing() {
        let app = XCUIApplication()
        app.launchArguments += ["--ui-testing", "--training-fixture"]
        app.launch()
        let finish = app.buttons["finish-training"]
        XCTAssertTrue(finish.waitForExistence(timeout: 10))
        XCTAssertFalse(finish.isEnabled)
        XCTAssertFalse(app.buttons["Add thought"].isEnabled)
        let start = app.coordinate(withNormalizedOffset: CGVector(dx: 0.35, dy: 0.5))
        start.press(forDuration: 0.1, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.65, dy: 0.5)))
        let instruction = app.staticTexts["training-instruction"]
        func waitForInstruction(_ text: String) {
            let expected = XCTNSPredicateExpectation(predicate: NSPredicate(format: "label CONTAINS %@", text), object: instruction)
            XCTAssertEqual(XCTWaiter.wait(for: [expected], timeout: 10), .completed)
            XCTAssertFalse(finish.isEnabled)
        }
        waitForInstruction("Tap any tile")
        let tiles = app.descendants(matching: .any).matching(NSPredicate(format: "identifier BEGINSWITH 'thought-tile-' AND label BEGINSWITH 'Demo thought:' AND (label CONTAINS 'An idea for a weekend adventure' OR label CONTAINS 'Start a small creative project' OR label CONTAINS 'A question to explore' OR label CONTAINS 'A thought for later' OR label CONTAINS 'Try something new' OR label CONTAINS 'Plan a surprise')"))
        guard let tile = tiles.allElementsBoundByIndex.first(where: { $0.isHittable }) else { XCTFail("No training tile: \(app.debugDescription)"); return }
        XCTAssertTrue(tile.label.hasPrefix("Demo thought:"))
        tile.tap()
        waitForInstruction("Scroll to look through")
        XCTAssertGreaterThan(instruction.frame.minY, app.staticTexts["thought-category-heading"].frame.maxY)
        XCTAssertFalse(app.buttons["Complete thought"].isEnabled)
        let scroll = app.scrollViews["thought-category-scroll"]
        XCTAssertTrue(scroll.waitForExistence(timeout: 10))
        scroll.swipeUp()
        if instruction.label.contains("Scroll to look through") { scroll.swipeDown() }
        waitForInstruction("category button")
        app.buttons["Change category"].tap()
        let choice = app.buttons["category-choice-3"]
        for _ in 0..<4 {
            if app.frame.contains(CGPoint(x: choice.frame.midX, y: choice.frame.midY)) { break }
            let y = choice.frame.midY / app.frame.height
            app.coordinate(withNormalizedOffset: CGVector(dx: 0.2, dy: y))
                .press(forDuration: 0.1, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.8, dy: y)))
        }
        XCTAssertTrue(choice.isHittable)
        choice.tap()
        waitForInstruction("checkmark")
        app.buttons["Complete thought"].tap()
        waitForInstruction("Plus button")
        app.buttons["Add thought"].tap()
        let editor = app.descendants(matching: .any)["thought-editor-text"].firstMatch
        XCTAssertTrue(editor.waitForExistence(timeout: 5))
        app.buttons["thought-save"].tap()
        waitForInstruction("practice tile")
        app.buttons["Add thought"].tap()
        let field = app.textFields.firstMatch
        let multiline = app.textViews.firstMatch
        let input = field.exists ? field : multiline
        XCTAssertTrue(input.waitForExistence(timeout: 5))
        input.tap()
        input.typeText("My practice thought")
        app.buttons["thought-save"].tap()
        waitForInstruction("Swipe sideways")
        scroll.swipeLeft()
        waitForInstruction("Long press")
        let categoryTiles = app.descendants(matching: .any).matching(NSPredicate(format: "identifier BEGINSWITH 'thought-tile-'"))
        guard let readable = categoryTiles.allElementsBoundByIndex.first(where: { $0.isHittable }) else { XCTFail("No readable tile"); return }
        readable.press(forDuration: 0.7)
        app.buttons["Done"].tap()
        waitForInstruction("home page")
        app.buttons["Close thought"].tap()
        let enabled = XCTNSPredicateExpectation(predicate: NSPredicate(format: "enabled == true"), object: finish)
        XCTAssertEqual(XCTWaiter.wait(for: [enabled], timeout: 5), .completed)
        finish.tap()
        XCTAssertFalse(finish.exists)
    }

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
        let editor = app.descendants(matching: .any)["thought-editor-text"].firstMatch
        XCTAssertTrue(editor.waitForExistence(timeout: 5))
        editor.tap()
        editor.typeText("A newly captured living brain thought")
        app.buttons["thought-save"].tap()
        XCTAssertTrue(app.scrollViews["thought-category-scroll"].exists)
        let tile = app.descendants(matching: .any).matching(NSPredicate(format: "identifier BEGINSWITH 'thought-tile-' AND label CONTAINS 'A newly captured living brain thought'")).firstMatch
        let scroll = app.scrollViews["thought-category-scroll"]
        for _ in 0..<16 {
            if tile.exists && tile.isHittable { break }
            scroll.swipeUp()
        }
        XCTAssertTrue(tile.exists)
        XCTAssertTrue(tile.isHittable)
        tile.press(forDuration: 0.7)
        XCTAssertTrue(app.descendants(matching: .any)["thought-detail-text"].firstMatch.waitForExistence(timeout: 5))
    }

    @MainActor
    func testQuickCaptureSurvivesLeavingAppWithoutSave() {
        let app = launchFixture()
        app.buttons["Add thought"].tap()
        let editor = app.descendants(matching: .any)["thought-editor-text"].firstMatch
        XCTAssertTrue(editor.waitForExistence(timeout: 5))
        editor.typeText("Remember this after leaving the app")
        XCUIDevice.shared.press(.home)
        app.activate()
        let brain = app.buttons["Organise Brain Dump inbox"]
        XCTAssertTrue(brain.waitForExistence(timeout: 5))
        brain.tap()
        let tile = app.descendants(matching: .any).matching(NSPredicate(format: "identifier BEGINSWITH 'thought-tile-' AND label CONTAINS 'Remember this after leaving the app'")).firstMatch
        let scroll = app.scrollViews["thought-category-scroll"]
        for _ in 0..<16 {
            if tile.exists && tile.isHittable { break }
            scroll.swipeUp()
        }
        XCTAssertTrue(tile.exists)
    }

    @MainActor
    func testRepeatedEmptyCaptureDismissalInSphere() {
        let app = launchFixture()
        app.buttons["Close thought"].tap()
        let add = app.buttons["Add thought"]
        for _ in 0..<8 {
            XCTAssertTrue(add.waitForExistence(timeout: 5))
            add.tap()
            XCTAssertTrue(app.descendants(matching: .any)["thought-editor-text"].firstMatch.waitForExistence(timeout: 5))
            app.buttons["thought-save"].tap()
            XCTAssertTrue(add.waitForExistence(timeout: 5))
            XCTAssertFalse(app.descendants(matching: .any)["thought-tile-12"].firstMatch.exists)
            XCTAssertEqual(app.state, .runningForeground)
        }
    }

    @MainActor
    func testBlankCaptureShrinksAwayWithoutAddingThought() {
        let app = launchFixture()
        let categoryChoice = app.buttons["category-choice-3"]
        let ready = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == true AND enabled == true"), object: categoryChoice)
        XCTAssertEqual(XCTWaiter.wait(for: [ready], timeout: 10), .completed)
        app.buttons["Add thought"].tap()
        let editor = app.descendants(matching: .any)["thought-editor-text"].firstMatch
        XCTAssertTrue(editor.waitForExistence(timeout: 5))
        editor.tap()
        editor.typeText("   ")
        app.buttons["thought-save"].tap()
        XCTAssertTrue(app.buttons["Organise Brain Dump inbox"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.descendants(matching: .any)["thought-tile-12"].firstMatch.exists)
        app.buttons["Organise Brain Dump inbox"].tap()
        XCTAssertFalse(app.descendants(matching: .any)["thought-tile-12"].firstMatch.exists)
    }

    @MainActor
    func testSortingDismissesAfterLastThoughtAndEmptyInboxStaysOnSphere() {
        let app = launchFixture()
        let category = app.buttons["category-choice-3"]
        XCTAssertTrue(category.waitForExistence(timeout: 5))
        for index in 0..<12 {
            let tile = app.descendants(matching: .any)["thought-tile-\(index)"].firstMatch
            XCTAssertTrue(tile.waitForExistence(timeout: 5))
            category.tap()
            if index < 11 {
                let removed = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: tile)
                XCTAssertEqual(XCTWaiter.wait(for: [removed], timeout: 5), .completed)
            }
        }
        let brain = app.buttons["Organise Brain Dump inbox"]
        XCTAssertTrue(brain.waitForExistence(timeout: 5))
        brain.tap()
        XCTAssertTrue(brain.exists)
        XCTAssertFalse(app.scrollViews["thought-category-scroll"].exists)
        XCTAssertFalse(app.descendants(matching: .any)["thought-category-picker"].firstMatch.exists)
    }

    @MainActor
    func testSwipeCategoriesFromUnsortedRestoresSortingPickerOnReturn() {
        let app = launchFixture()
        let choice = app.buttons["category-choice-3"]
        XCTAssertTrue(choice.waitForExistence(timeout: 5))
        let first = app.descendants(matching: .any)["thought-tile-0"].firstMatch
        choice.tap()
        let assigned = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: first)
        XCTAssertEqual(XCTWaiter.wait(for: [assigned], timeout: 5), .completed)
        app.scrollViews["thought-category-scroll"].swipeLeft()
        let heading = app.staticTexts["thought-category-heading"]
        let category = XCTNSPredicateExpectation(predicate: NSPredicate(format: "label == 'Things to do'"), object: heading)
        XCTAssertEqual(XCTWaiter.wait(for: [category], timeout: 5), .completed)
        XCTAssertFalse(app.descendants(matching: .any)["thought-category-picker"].firstMatch.exists)
        app.scrollViews["thought-category-scroll"].swipeRight()
        let unsorted = XCTNSPredicateExpectation(predicate: NSPredicate(format: "label == 'Unsorted'"), object: heading)
        XCTAssertEqual(XCTWaiter.wait(for: [unsorted], timeout: 5), .completed)
        XCTAssertTrue(app.descendants(matching: .any)["thought-category-picker"].firstMatch.exists)
    }

    @MainActor
    func testCompletionRemovesThoughtAfterAnimation() {
        let app = launchFixture()
        let first = app.descendants(matching: .any).matching(NSPredicate(format: "identifier BEGINSWITH 'thought-tile-' AND label BEGINSWITH 'Fixture thought 01'")).firstMatch
        XCTAssertTrue(first.waitForExistence(timeout: 5))
        app.buttons["Complete thought"].tap()
        let removed = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: first)
        XCTAssertEqual(XCTWaiter.wait(for: [removed], timeout: 5), .completed)
        XCTAssertTrue(app.scrollViews["thought-category-scroll"].exists)
        XCTAssertTrue(app.descendants(matching: .any)["thought-tile-0"].firstMatch.exists)
    }

    @MainActor
    func testSettingsUsesSinglePageAndShowsFeedbackAndVersion() {
        let app = launchFixture()
        let picker = app.descendants(matching: .any)["thought-category-picker"].firstMatch
        app.buttons["Close thought"].tap()
        let closed = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: picker)
        XCTAssertEqual(XCTWaiter.wait(for: [closed], timeout: 5), .completed)
        app.buttons["Settings"].tap()
        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.navigationBars.matching(identifier: "Settings").count, 1)
        XCTAssertTrue(app.buttons["Categories"].exists)
        app.buttons["About & Privacy"].tap()
        XCTAssertTrue(app.staticTexts["braindumpfeedback@cakesquared.co.uk"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Version"].exists)
        XCTAssertTrue(app.staticTexts["Build"].exists)
        app.buttons["How BrainDump handles your data"].tap()
        XCTAssertTrue(app.navigationBars["Privacy"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testUnsortedTileOpensSortingQueueFromSphere() {
        let app = launchFixture()
        app.buttons["Close thought"].tap()
        let tiles = app.descendants(matching: .any).matching(NSPredicate(format: "identifier BEGINSWITH 'thought-tile-'"))
        let tile = tiles.allElementsBoundByIndex.first { $0.isHittable }
        XCTAssertNotNil(tile)
        tile?.tap()
        XCTAssertTrue(app.descendants(matching: .any)["thought-category-picker"].firstMatch.waitForExistence(timeout: 5))
        XCTAssertTrue(app.scrollViews["thought-category-scroll"].exists)
        XCTAssertEqual(app.descendants(matching: .any).matching(NSPredicate(format: "identifier BEGINSWITH 'thought-tile-' AND value BEGINSWITH 'Selected'")).firstMatch.label, tile?.label)
    }

    @MainActor
    func testBrainInboxKeepsCategoryPickerVisibleAfterCategorising() {
        let app = launchFixture()
        let picker = app.descendants(matching: .any)["thought-category-picker"].firstMatch
        app.buttons["Close thought"].tap()
        app.buttons["Organise Brain Dump inbox"].tap()
        XCTAssertTrue(picker.waitForExistence(timeout: 5))
        XCTAssertTrue(app.scrollViews["thought-category-scroll"].exists)
        let category = app.buttons["category-choice-3"]
        XCTAssertTrue(category.exists)
        category.tap()
        XCTAssertTrue(picker.exists)
        XCTAssertEqual(app.staticTexts["thought-category-heading"].label, "Unsorted")
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
