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
        let bannerBottom = max(finish.frame.maxY, instruction.frame.maxY) + 40
        guard let tile = tiles.allElementsBoundByIndex.first(where: {
            $0.isHittable && $0.frame.midY > bannerBottom && app.frame.contains(CGPoint(x: $0.frame.midX, y: $0.frame.midY))
        }) else { XCTFail("No training tile: \(app.debugDescription)"); return }
        XCTAssertTrue(tile.label.hasPrefix("Demo thought:"))
        tile.tap()
        waitForInstruction("Scroll to look through")
        XCTAssertGreaterThan(instruction.frame.minY, app.buttons["thought-category-heading"].frame.maxY)
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
        let fullClose = app.buttons["thought-detail-close"]
        XCTAssertTrue(fullClose.waitForExistence(timeout: 5))
        fullClose.tap()
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
            if index == 11 {
                XCTAssertTrue(app.buttons["thought-archive-undo"].waitForExistence(timeout: 2))
                XCTAssertTrue(app.scrollViews["thought-category-scroll"].exists)
                XCTAssertFalse(app.buttons["Organise Brain Dump inbox"].exists)
            }
            if index < 11 {
                let removed = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: tile)
                XCTAssertEqual(XCTWaiter.wait(for: [removed], timeout: 5), .completed)
            }
        }
        let brain = app.buttons["Organise Brain Dump inbox"]
        XCTAssertTrue(brain.waitForExistence(timeout: 10))
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
        let heading = app.buttons["thought-category-heading"]
        let category = XCTNSPredicateExpectation(predicate: NSPredicate(format: "value == 'Things to do'"), object: heading)
        XCTAssertEqual(XCTWaiter.wait(for: [category], timeout: 5), .completed)
        XCTAssertFalse(app.descendants(matching: .any)["thought-category-picker"].firstMatch.exists)
        app.scrollViews["thought-category-scroll"].swipeRight()
        let unsorted = XCTNSPredicateExpectation(predicate: NSPredicate(format: "value == 'Unsorted'"), object: heading)
        XCTAssertEqual(XCTWaiter.wait(for: [unsorted], timeout: 5), .completed)
        XCTAssertTrue(app.descendants(matching: .any)["thought-category-picker"].firstMatch.exists)
    }

    @MainActor
    func testCategoryHeadingOffersDirectNavigation() {
        let app = launchFixture()
        let choice = app.buttons["category-choice-3"]
        XCTAssertTrue(choice.waitForExistence(timeout: 5))
        choice.tap()
        let heading = app.buttons["thought-category-heading"]
        XCTAssertTrue(heading.waitForExistence(timeout: 5))
        heading.tap()
        let destination = app.buttons["category-menu-choice-3"]
        XCTAssertTrue(destination.waitForExistence(timeout: 5))
        destination.tap()
        let selected = XCTNSPredicateExpectation(predicate: NSPredicate(format: "value == 'Things to do'"), object: heading)
        XCTAssertEqual(XCTWaiter.wait(for: [selected], timeout: 5), .completed)
        XCTAssertTrue(app.scrollViews["thought-category-scroll"].exists)
        XCTAssertFalse(app.descendants(matching: .any)["thought-category-picker"].firstMatch.exists)
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
    func testCategoriesEditShowsDeleteBesideReordering() {
        let app = launchFixture()
        let close = app.buttons["Close thought"]
        XCTAssertTrue(close.waitForExistence(timeout: 10))
        close.tap()
        let settings = app.buttons["Settings"]
        XCTAssertTrue(settings.waitForExistence(timeout: 10))
        settings.tap()
        app.buttons["Categories"].tap()
        let create = app.buttons["New category"]
        XCTAssertTrue(create.waitForExistence(timeout: 10))
        if !create.isHittable { app.swipeUp() }
        create.tap()
        let name = app.textFields["Enter category name"]
        XCTAssertTrue(name.waitForExistence(timeout: 5))
        name.tap()
        name.typeText("Edit mode test")
        app.buttons["Create"].tap()
        let edit = app.buttons["categories-edit-toggle"]
        XCTAssertTrue(edit.waitForExistence(timeout: 5))
        let movieRow = app.descendants(matching: .any)["category-row-1"].firstMatch
        movieRow.tap()
        XCTAssertFalse(app.alerts["Rename category"].exists)
        edit.tap()
        movieRow.tap()
        XCTAssertTrue(app.alerts["Rename category"].waitForExistence(timeout: 5))
        app.alerts["Rename category"].textFields.firstMatch.tap()
        app.alerts["Rename category"].textFields.firstMatch.typeText(" renamed")
        app.alerts.buttons["Save"].tap()
        XCTAssertTrue(movieRow.label.contains("renamed"))
        let trash = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'category-delete-'" )).firstMatch
        XCTAssertTrue(trash.waitForExistence(timeout: 5))
        if !trash.isHittable { app.swipeUp() }
        XCTAssertTrue(trash.isEnabled)
        XCTAssertTrue(app.frame.contains(trash.frame))
        let movieCell = app.cells.containing(.any, identifier: "category-row-1").firstMatch
        let taskCell = app.cells.containing(.any, identifier: "category-row-3").firstMatch
        XCTAssertTrue(movieCell.exists)
        XCTAssertTrue(taskCell.exists)
        // The system owns the reorder accessory and its accessibility identifier.
        // Drag its standard trailing position and verify the saved row order.
        let movieHandle = movieCell.coordinate(withNormalizedOffset: CGVector(dx: 0.95, dy: 0.5))
        let taskHandle = taskCell.coordinate(withNormalizedOffset: CGVector(dx: 0.95, dy: 0.3))
        movieHandle.press(forDuration: 1, thenDragTo: taskHandle)
        let reordered = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            movieCell.frame.minY < taskCell.frame.minY
        }, object: nil)
        XCTAssertEqual(XCTWaiter.wait(for: [reordered], timeout: 5), .completed)
        let editLayout = XCTAttachment(screenshot: app.screenshot())
        editLayout.name = "Category Edit-mode row controls"
        editLayout.lifetime = .keepAlways
        add(editLayout)
        trash.tap()
        XCTAssertTrue(app.alerts["Delete category?"].waitForExistence(timeout: 5))
        app.alerts.buttons["Cancel"].tap()
        edit.tap()
        XCTAssertFalse(trash.exists)
        movieRow.tap()
        XCTAssertFalse(app.alerts["Rename category"].exists)
    }

    @MainActor
    func testSettingsUsesSinglePageAndShowsFeedbackAndVersion() {
        let app = launchFixture()
        let close = app.buttons["Close thought"]
        XCTAssertTrue(close.waitForExistence(timeout: 10))
        close.tap()
        let settings = app.buttons["Settings"]
        if !settings.waitForExistence(timeout: 3), close.exists { close.tap() }
        XCTAssertTrue(settings.waitForExistence(timeout: 10))
        settings.tap()
        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.navigationBars.matching(identifier: "Settings").count, 1)
        XCTAssertTrue(app.buttons["Categories"].exists)
        app.buttons["About & Privacy"].tap()
        XCTAssertTrue(app.staticTexts["Capture now. Sort later."].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Send Feedback"].exists)
        XCTAssertFalse(app.staticTexts["braindumpfeedback@cakesquared.co.uk"].exists)
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
        let close = app.buttons["Close thought"]
        XCTAssertTrue(close.waitForExistence(timeout: 10))
        close.tap()
        let inbox = app.buttons["Organise Brain Dump inbox"]
        XCTAssertTrue(inbox.waitForExistence(timeout: 10))
        inbox.tap()
        XCTAssertTrue(picker.waitForExistence(timeout: 5))
        XCTAssertTrue(app.scrollViews["thought-category-scroll"].exists)
        let category = app.buttons["category-choice-3"]
        XCTAssertTrue(category.exists)
        let selected = app.descendants(matching: .any).matching(NSPredicate(format: "label BEGINSWITH 'Fixture thought' AND value BEGINSWITH 'Selected'")).firstMatch
        XCTAssertTrue(selected.waitForExistence(timeout: 5))
        let originalLabel = selected.label
        category.tap()
        let undo = app.buttons["thought-archive-undo"]
        XCTAssertTrue(undo.waitForExistence(timeout: 2))
        let displacedLabel = selected.label
        let displaced = app.buttons.matching(NSPredicate(format: "label == %@", displacedLabel)).firstMatch
        let previousPosition = displaced.frame.midY
        undo.tap()
        let restored = app.buttons.matching(NSPredicate(format: "label == %@", originalLabel)).firstMatch
        let returned = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == true AND hittable == true AND value BEGINSWITH 'Selected'"), object: restored)
        XCTAssertEqual(XCTWaiter.wait(for: [returned], timeout: 5), .completed)
        XCTAssertFalse(undo.exists)
        XCTAssertTrue(displaced.exists)
        XCTAssertGreaterThan(abs(displaced.frame.midY - previousPosition), 10)
        XCTAssertFalse((displaced.value as? String ?? "").hasPrefix("Selected"))
        XCTAssertTrue(picker.exists)
        XCTAssertEqual(app.buttons["thought-category-heading"].value as? String, "Unsorted")
    }

    @MainActor
    func testLongPressShowsCompleteThoughtAndDismissesBackToCategory() {
        let app = launchFixture()
        let tile = app.descendants(matching: .any)["thought-tile-0"].firstMatch
        XCTAssertTrue(tile.waitForExistence(timeout: 10))
        let originalWidth = tile.frame.width
        let originalLabel = tile.label
        tile.press(forDuration: 0.7)
        let fullText = app.descendants(matching: .any)["thought-detail-text"].firstMatch
        XCTAssertTrue(fullText.waitForExistence(timeout: 5))
        XCTAssertTrue(fullText.label.contains("The complete thought remains readable after opening the expanded tile."))
        let close = app.buttons["thought-detail-close"]
        let ready = XCTNSPredicateExpectation(predicate: NSPredicate(format: "hittable == true"), object: close)
        XCTAssertEqual(XCTWaiter.wait(for: [ready], timeout: 5), .completed)
        XCTAssertGreaterThan(fullText.frame.width, originalWidth)
        close.tap()
        let closed = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: close)
        XCTAssertEqual(XCTWaiter.wait(for: [closed], timeout: 5), .completed)
        XCTAssertTrue(app.scrollViews["thought-category-scroll"].waitForExistence(timeout: 5))
        XCTAssertTrue(tile.isHittable)
        XCTAssertEqual(tile.label, originalLabel)
        let expanded = XCTAttachment(screenshot: app.screenshot())
        expanded.name = "Returned to original category tile"
        expanded.lifetime = .keepAlways
        add(expanded)
        tile.press(forDuration: 0.7)
        XCTAssertTrue(close.waitForExistence(timeout: 5))
        let flipped = XCTAttachment(screenshot: app.screenshot())
        flipped.name = "Expanded centred thought tile"
        flipped.lifetime = .keepAlways
        add(flipped)
        // A second long press on the readable text reverses the same presentation.
        fullText.press(forDuration: 0.7)
        let returned = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: close)
        XCTAssertEqual(XCTWaiter.wait(for: [returned], timeout: 5), .completed)
        XCTAssertTrue(tile.isHittable)
        tile.press(forDuration: 0.7)
        let outsideReady = XCTNSPredicateExpectation(predicate: NSPredicate(format: "hittable == true"), object: close)
        XCTAssertEqual(XCTWaiter.wait(for: [outsideReady], timeout: 5), .completed)
        fullText.tap()
        XCTAssertTrue(close.exists)
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.2)).tap()
        let outsideClosed = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: close)
        XCTAssertEqual(XCTWaiter.wait(for: [outsideClosed], timeout: 5), .completed)
        XCTAssertTrue(tile.isHittable)
    }
}
