import XCTest

/// Only UI activations and layout: the Debug app never starts its audio engine.
final class DriftSilentUITests: XCTestCase {
    private var app: XCUIApplication!
    override func setUpWithError() throws {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
        app = XCUIApplication()
        app.launchArguments = ["-ui-testing", "-ui-testing-silent", "-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launch()
    }
    private func capture(_ name: String) {
        let image = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        image.name = name; image.lifetime = .keepAlways; add(image)
    }
    private func reveal(_ element: XCUIElement) {
        for _ in 0..<12 {
            if element.isHittable { return }
            app.swipeUp()
        }
        XCTAssertTrue(element.isHittable)
    }
    private func tab(_ name: String) {
        let compact = app.tabBars.buttons[name]
        let button = compact.exists ? compact : app.buttons.matching(NSPredicate(format: "label == %@", name)).firstMatch
        XCTAssertTrue(button.waitForExistence(timeout: 5)); button.tap()
    }
    private func revealCard(_ element: XCUIElement) {
        for _ in 0..<15 {
            let frame = element.frame
            let top = app.frame.minY + 310
            let bottom = app.frame.maxY - 245
            if element.isHittable && frame.minY >= top && frame.maxY <= bottom { return }
            let above = frame.minY < top
            let start = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: above ? 0.4 : 0.65))
            let end = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: above ? 0.6 : 0.45))
            start.press(forDuration: 0.05, thenDragTo: end)
        }
        XCTAssertTrue(element.isHittable)
        XCTAssertLessThanOrEqual(element.frame.maxY, app.frame.maxY - 180)
    }
    func testSilentCardHitAreasAndStableFilters() {
        let sound = app.buttons["sound-light-rain"]
        XCTAssertTrue(sound.waitForExistence(timeout: 5)); revealCard(sound)
        for point in [CGVector(dx: 0.5, dy: 0.06), CGVector(dx: 0.95, dy: 0.7)] {
            revealCard(sound)
            sound.coordinate(withNormalizedOffset: point).tap()
            XCTAssertEqual(sound.label, "Remove Light rain", "Empty upper and side areas activate the sound")
            revealCard(sound)
            sound.coordinate(withNormalizedOffset: point).tap()
            XCTAssertEqual(sound.label, "Add Light rain", "The same areas deactivate the sound")
        }
        revealCard(sound); sound.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.1)).tap()
        app.buttons["favorite-light-rain"].tap()
        XCTAssertEqual(sound.label, "Remove Light rain", "Favorite is independent of selection")
        let volume = app.sliders["volume-light-rain"]
        XCTAssertTrue(volume.exists); volume.adjust(toNormalizedSliderPosition: 0.4)
        XCTAssertEqual(sound.label, "Remove Light rain", "The volume slider does not toggle the card")
        XCTAssertEqual(app.buttons["mini-play"].label, "Play mix", "Silent interaction mode never starts playback")
        capture("24-card-activation")
        let all = app.buttons["filter-all"]
        reveal(all)
        let controls = app.textFields["sound-search"]
        let position = controls.frame.minY
        for name in ["rain", "nature", "favorites", "all"] {
            app.buttons["filter-" + name].tap()
            XCTAssertEqual(controls.frame.minY, position, accuracy: 3, "Filtering keeps the controls in the same place")
        }
        capture("25-stable-filters")
        app.swipeUp(); app.swipeUp()
        let pinnedPosition = controls.frame.minY
        app.buttons["filter-favorites"].tap()
        XCTAssertEqual(controls.frame.minY, pinnedPosition, accuracy: 3)
        XCTAssertTrue(sound.isHittable, "Short filtered lists must remain visible below the pinned controls")
        XCTAssertGreaterThanOrEqual(sound.frame.minY, app.buttons["filter-favorites"].frame.maxY)
        capture("32-deep-filter-results")
    }
    func testSilentSettingsWidthsAndLicense() {
        tab("Settings")
        let privacy = app.otherElements["settings-privacy-card"]
        let credits = app.otherElements["settings-nodus-card"]
        XCTAssertTrue(privacy.waitForExistence(timeout: 5)); reveal(credits)
        XCTAssertEqual(privacy.frame.width, credits.frame.width, accuracy: 1)
        XCTAssertTrue(app.buttons["nodus-website"].exists)
        XCTAssertTrue(app.buttons["nodus-support"].exists)
        XCTAssertTrue(app.buttons["moodist-repository"].exists)
        XCTAssertFalse(app.buttons["View source code"].exists)
        capture("26-settings-aligned")
        let license = app.buttons["moodist-license"]
        reveal(license); license.tap()
        XCTAssertTrue(app.navigationBars["Moodist license"].waitForExistence(timeout: 5))
        let body = app.textViews["legal-document-body"]
        XCTAssertTrue(body.exists)
        let text = body.value as? String ?? ""
        XCTAssertTrue(text.contains("MIT License")); XCTAssertTrue(text.contains("Copyright (c) 2023 MAZE"))
        XCTAssertTrue(text.contains("does NOT cover the audio files"))
        capture("27-moodist-license")
        app.buttons["Done"].tap()
    }
    func testSilentSavedLayoutParity() {
        tab("My mix")
        let mixHeading = app.staticTexts["Your soundscape"].frame
        let mixNodi = app.otherElements["nodi"].frame
        let mixAction = app.buttons["Explore sounds"].frame
        capture("36-empty-my-mix")
        tab("Saved")
        let savedHeading = app.staticTexts["Quiet, on repeat."].frame
        let savedNodi = app.otherElements["nodi"].frame
        let savedAction = app.buttons["Create your first mix"].frame
        capture("37-empty-saved")
        XCTAssertEqual(savedHeading.minX, mixHeading.minX, accuracy: 1)
        XCTAssertEqual(savedHeading.height, mixHeading.height, accuracy: 1)
        XCTAssertEqual(savedNodi.width, mixNodi.width, accuracy: 1)
        XCTAssertEqual(savedNodi.height, mixNodi.height, accuracy: 1)
        XCTAssertEqual(savedAction.width, mixAction.width, accuracy: 1)
        XCTAssertEqual(savedAction.height, mixAction.height, accuracy: 1)

        tab("Sounds")
        app.buttons["starter-light-rain"].tap()
        let mixCard = app.otherElements["mix-card-light-rain"]
        XCTAssertTrue(mixCard.waitForExistence(timeout: 5))
        let cardFrame = mixCard.frame
        capture("38-saved-parity-my-mix")
        let save = app.buttons["save-mix"]
        reveal(save); save.tap()
        let name = app.textFields["preset-name"]
        XCTAssertTrue(name.waitForExistence(timeout: 5)); name.tap(); name.typeText("Evening reading")
        app.buttons["preset-save"].tap()
        let savedCard = app.otherElements["saved-card-Evening reading"]
        XCTAssertTrue(savedCard.waitForExistence(timeout: 5))
        XCTAssertEqual(savedCard.frame.width, cardFrame.width, accuracy: 1)
        XCTAssertEqual(savedCard.frame.minX, cardFrame.minX, accuracy: 1)
        XCTAssertGreaterThanOrEqual(savedCard.frame.height, cardFrame.height - 1)
        XCTAssertEqual(app.buttons["mini-play"].label, "Play mix")
        capture("39-saved-parity-saved")
        app.buttons["Load Evening reading"].tap()
        XCTAssertTrue(app.buttons["mix-play"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.buttons["mix-play"].label, "Play soundscape", "Loading keeps the mix paused")
        XCTAssertTrue(app.buttons["remove-light-rain"].exists)
        XCTAssertTrue(app.buttons["remove-brown-noise"].exists)
    }
    func testSilentAudioSourceCredits() {
        tab("Settings")
        let license = app.buttons["moodist-license"]
        reveal(license); license.tap()
        let sources = app.buttons["Audio sources & permissions"]
        XCTAssertTrue(sources.waitForExistence(timeout: 5))
        reveal(sources); sources.tap()
        let body = app.textViews.matching(NSPredicate(format: "value BEGINSWITH %@", "Nodus Drift · Audio sources and permissions")).firstMatch
        XCTAssertTrue(body.waitForExistence(timeout: 5))
        let text = body.value as? String ?? ""
        XCTAssertTrue(text.contains("Eighty options use 77 individually documented CC0"))
        XCTAssertTrue(text.contains("FSD50K acknowledgement"))
        XCTAssertTrue(text.contains("Clotho acknowledgement"))
        XCTAssertTrue(text.contains("vocal imitation"))
        XCTAssertTrue(text.contains("tuning-radio"))
        XCTAssertFalse(text.contains("could not be loaded"))
        capture("42-audio-source-credits")
        app.buttons["Done"].tap()
    }
}
