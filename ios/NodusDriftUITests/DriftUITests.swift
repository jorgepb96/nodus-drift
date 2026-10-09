import XCTest

final class DriftUITests: XCTestCase {
    private var app: XCUIApplication!
    override func setUpWithError() throws {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
        app = XCUIApplication()
        app.launchArguments = ["-ui-testing", "-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launch()
    }
    private func capture(_ name: String) {
        // Allow native control and layout transitions to finish before visual QA.
        Thread.sleep(forTimeInterval: 0.8)
        // Capture the physical screen; app-region crops are unreliable after
        // rotating an iPad on the iOS 26 simulator.
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name; attachment.lifetime = .keepAlways; add(attachment)
    }
    private func tapTab(_ name: String) {
        // iPad's regular-width layout uses native top tabs outside a tab bar.
        let compactTab = app.tabBars.buttons[name]
        let button = compactTab.exists ? compactTab : app.buttons.matching(NSPredicate(format: "label == %@", name)).firstMatch
        XCTAssertTrue(button.waitForExistence(timeout: 5))
        // Native iOS 26 may report a visible tab as non-hittable after a modal
        // rotation. Tap its observed center to exercise the real touch target.
        if button.isHittable { button.tap() }
        else {
            XCTAssertTrue(app.frame.intersects(button.frame))
            button.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        }
    }
    private func scrollTo(_ element: XCUIElement) {
        for _ in 0..<20 {
            if element.isHittable { return }
            // Short, deliberate drags avoid skipping a control on a small screen.
            // Reverse direction if the retained scroll position is below it.
            let frame = element.frame
            let above = frame.height > 0 && frame.midY < app.frame.minY + 90
            let start = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: above ? 0.35 : 0.65))
            let end = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: above ? 0.65 : 0.35))
            start.press(forDuration: 0.05, thenDragTo: end)
        }
        XCTAssertTrue(element.isHittable)
    }
    func testCompleteSoundscapeAndScreenshots() {
        XCTAssertTrue(app.buttons["starter-light-rain"].waitForExistence(timeout: 5))
        capture("01-home")
        app.buttons["starter-light-rain"].tap()
        XCTAssertTrue(app.buttons["mix-play"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.buttons["mix-play"].label, "Play soundscape")
        app.buttons["mix-play"].tap()
        XCTAssertTrue(app.buttons["mix-play"].label.contains("Pause"))
        let ready = NSPredicate(format: "exists == false")
        expectation(for: ready, evaluatedWith: app.staticTexts["Preparing your sound…"])
        waitForExpectations(timeout: 8)
        capture("02-mix")
        scrollTo(app.buttons["save-mix"])
        app.buttons["save-mix"].tap()
        let name = app.textFields["preset-name"]
        XCTAssertTrue(name.waitForExistence(timeout: 3))
        // Keep the saved name distinct from the starter card's accessibility label.
        name.tap(); name.typeText("Evening reading")
        app.buttons["preset-save"].tap()
        XCTAssertTrue(app.buttons["Load Evening reading"].waitForExistence(timeout: 4))
        capture("03-saved")
        app.buttons["Load Evening reading"].tap()
        XCTAssertEqual(app.buttons["mix-play"].label, "Play soundscape")
        app.buttons["mix-play"].tap()
        app.buttons["enter-meditation"].tap()
        XCTAssertTrue(app.buttons["leave-meditation"].waitForExistence(timeout: 3))
        capture("04-meditation-controls")
        // Wait for auto-hidden controls; no app idling delay on the native Canvas.
        let hidden = NSPredicate(format: "exists == false OR hittable == false")
        expectation(for: hidden, evaluatedWith: app.buttons["leave-meditation"])
        waitForExpectations(timeout: 8)
        capture("05-meditation-resting")
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.42)).tap()
        XCTAssertTrue(app.buttons["leave-meditation"].waitForExistence(timeout: 3))
        let awake = app.descendants(matching: .any).matching(identifier: "nodi").firstMatch
        XCTAssertEqual(awake.value as? String, "Awake")
        capture("06-meditation-awake")
        app.buttons["leave-meditation"].tap()
        Thread.sleep(forTimeInterval: 0.6)
        tapTab("Settings")
        capture("07-settings")
        scrollTo(app.buttons["Read privacy policy"])
        app.buttons["Read privacy policy"].tap()
        XCTAssertTrue(app.navigationBars["Privacy policy"].waitForExistence(timeout: 3))
        app.buttons["Done"].tap()
        tapTab("Sounds")
        scrollTo(app.buttons["filter-rain"])
        app.buttons["filter-rain"].tap()
        XCTAssertTrue(app.buttons["sound-heavy-rain"].waitForExistence(timeout: 3))
        app.buttons["favorite-heavy-rain"].tap()
        app.buttons["sound-heavy-rain"].tap()
        capture("08-sound-library")
        app.buttons["filter-favorites"].tap()
        XCTAssertTrue(app.buttons["sound-heavy-rain"].exists)
        XCTAssertFalse(app.buttons["sound-light-rain"].exists)
        capture("09-favorites")
    }
    func testSearchSortingAndTimer() {
        app.buttons["starter-light-rain"].tap()
        scrollTo(app.buttons["sleep-timer"])
        app.buttons["sleep-timer"].tap()
        scrollTo(app.buttons["timer-15"])
        app.buttons["timer-15"].tap()
        XCTAssertTrue(app.buttons["sleep-timer"].label.contains(":"))
        tapTab("Sounds")
        let search = app.textFields["sound-search"]
        scrollTo(search); search.tap(); search.typeText("theta")
        XCTAssertTrue(app.buttons["sound-binaural-theta"].waitForExistence(timeout: 3))
        XCTAssertFalse(app.buttons["sound-heavy-rain"].exists)
        search.typeText("\n")
        app.buttons["sound-binaural-theta"].tap()
        tapTab("My mix")
        XCTAssertTrue(app.buttons["remove-binaural-theta"].exists)
        app.buttons["mix-play"].tap()
        XCTAssertEqual(app.buttons["mix-play"].label, "Play soundscape")
    }
    func testAdaptiveLayouts() {
        XCTAssertTrue(app.buttons["starter-light-rain"].waitForExistence(timeout: 5))
        capture("10-device-portrait")
        app.buttons["starter-light-rain"].tap()
        XCTAssertTrue(app.buttons["mix-play"].waitForExistence(timeout: 3))
        capture("11-device-mix")
        XCUIDevice.shared.orientation = .landscapeLeft
        let landscape = NSPredicate { _, _ in self.app.frame.width > self.app.frame.height }
        expectation(for: landscape, evaluatedWith: app)
        waitForExpectations(timeout: 8)
        capture("12-device-landscape")
        app.buttons["enter-meditation"].tap()
        XCTAssertTrue(app.buttons["leave-meditation"].waitForExistence(timeout: 3))
        let character = app.descendants(matching: .any).matching(identifier: "nodi").firstMatch
        XCTAssertEqual(character.frame.midX, app.frame.midX, accuracy: 10, "Meditation stays centered after rotation")
        capture("13-device-meditation-landscape")
        app.buttons["leave-meditation"].tap()
        XCUIDevice.shared.orientation = .portrait
    }
}
