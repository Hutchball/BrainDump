import XCTest

/// Seeded exploratory stress test using temporary thoughts, never the saved library.
final class MonkeyUITests: XCTestCase {
    @MainActor
    func testSeededMonkey() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing", "--living-brain-fixture"]
        app.launch()
        XCTAssertTrue(app.scrollViews["thought-category-scroll"].waitForExistence(timeout: 15))
        var seed: UInt64 = 20261007
        var trace: [String] = []
        defer {
            XCUIDevice.shared.orientation = .portrait
            let attachment = XCTAttachment(string: trace.joined(separator: "\n"))
            attachment.name = "Monkey action trace — seed 20261007"
            attachment.lifetime = .keepAlways
            add(attachment)
        }
        func random(_ upper: Int) -> Int {
            seed = seed &* 6364136223846793005 &+ 1442695040888963407
            return Int((seed >> 32) % UInt64(upper))
        }
        func tap(_ name: String) -> Bool {
            let button = app.buttons[name].firstMatch
            guard button.exists, !button.frame.isEmpty, app.frame.contains(CGPoint(x: button.frame.midX, y: button.frame.midY)), button.isHittable, button.isEnabled else { return false }
            button.tap()
            return true
        }
        for step in 0..<180 {
            XCTAssertEqual(app.state, .runningForeground, "App exited at step \(step); trace: \(trace.suffix(12))")
            let action = random(14)
            trace.append("\(step): action \(action)")
            print("MONKEY \(step): action \(action)")
            let editor = app.descendants(matching: .any)["thought-editor-text"].firstMatch
            if editor.exists {
                if action % 3 == 0 {
                    XCUIDevice.shared.press(.home)
                    app.activate()
                } else {
                    let input = app.textViews.firstMatch.exists ? app.textViews.firstMatch : app.textFields.firstMatch
                    if input.exists, input.isHittable {
                        input.tap()
                        input.typeText(step % 4 == 0 ? "   " : "Monkey \(step) 🧠\nIdea https://example.com")
                    }
                    _ = tap("thought-save")
                }
                continue
            }
            if app.buttons["thought-detail-close"].exists {
                _ = tap(action % 3 == 0 ? "Complete thought" : "thought-detail-close")
                _ = tap("thought-detail-close")
                continue
            }
            let scroll = app.scrollViews["thought-category-scroll"]
            switch action {
            case 0: _ = tap("Add thought")
            case 1: _ = tap("Close thought")
            case 2: _ = tap("Organise Brain Dump inbox")
            case 3: _ = tap("Complete thought")
            case 4, 5:
                if scroll.exists { action == 4 ? scroll.swipeUp(velocity: .fast) : scroll.swipeDown(velocity: .fast) }
                else { action == 4 ? app.swipeUp(velocity: .fast) : app.swipeDown(velocity: .fast) }
            case 6, 7:
                if scroll.exists { action == 6 ? scroll.swipeLeft(velocity: .fast) : scroll.swipeRight(velocity: .fast) }
                else { action == 6 ? app.swipeLeft(velocity: .fast) : app.swipeRight(velocity: .fast) }
            case 8:
                app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.48)).press(forDuration: 0.6)
            case 9:
                _ = tap("category-choice-\(1 + random(4))")
            case 10:
                XCUIDevice.shared.press(.home)
                app.activate()
            case 11:
                XCUIDevice.shared.orientation = step % 2 == 0 ? .landscapeLeft : .portrait
            case 12:
                if tap("Settings") { _ = tap("Done") }
            default:
                let from = app.coordinate(withNormalizedOffset: CGVector(dx: 0.25, dy: 0.45))
                from.press(forDuration: 0.05, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.75, dy: 0.55)))
            }
        }
        XCTAssertEqual(app.state, .runningForeground)
    }
}
