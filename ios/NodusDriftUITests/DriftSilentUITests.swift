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
    private func launchScrollFixture() {
        app.terminate()
        app.launchArguments.append("-ui-testing-scroll-fixture")
        app.launch()
    }
    func testSilentTabsReturnToTop() {
        launchScrollFixture()
        let destinations = [("Sounds", "A little space\nto be."), ("My mix", "Your soundscape"),
                            ("Saved", "Quiet, on repeat."), ("Settings", "Make yourself\nat home.")]
        var topPositions: [String: CGFloat] = [:]
        for (name, heading) in destinations {
            tab(name)
            let title = app.staticTexts[heading]
            XCTAssertTrue(title.waitForExistence(timeout: 5)); XCTAssertTrue(title.isHittable)
            topPositions[name] = title.frame.minY
        }
        for (name, heading) in destinations {
            tab(name)
            for _ in 0..<6 { app.swipeUp() }
            if name == "Sounds" || name == "My mix" || name == "Saved" {
                XCTAssertFalse(app.staticTexts[heading].isHittable, "The test must leave the destination deeply scrolled")
            }
            tab(name == "Settings" ? "Sounds" : "Settings")
            tab(name)
            let title = app.staticTexts[heading]
            XCTAssertTrue(title.isHittable, "Switching tabs brings the destination's heading back")
            XCTAssertEqual(title.frame.minY, topPositions[name]!, accuracy: 2)
            capture("43-tab-top-" + name)
        }
        tab("Sounds")
        let search = app.textFields["sound-search"]
        reveal(search); search.tap(); search.typeText("rain\n")
        app.buttons["filter-rain"].tap()
        tab("Saved"); tab("Sounds")
        XCTAssertTrue(app.staticTexts["A little space\nto be."].isHittable)
        reveal(search)
        XCTAssertEqual(search.value as? String, "rain", "Resetting scroll preserves the search")
        XCTAssertTrue(app.buttons["filter-rain"].isSelected, "Resetting scroll preserves the category")
        XCTAssertEqual(app.buttons["mini-play"].label, "Play mix")
    }
    func testSilentClearIsImmediateAndPreservesSavedMixes() {
        launchScrollFixture()
        tab("My mix")
        let timer = app.buttons["sleep-timer"]
        revealCard(timer); timer.tap()
        let fifteenMinutes = app.buttons["timer-15"]
        XCTAssertTrue(fifteenMinutes.waitForExistence(timeout: 5)); fifteenMinutes.tap()
        tab("Settings"); tab("My mix")
        let clear = app.buttons["clear-mix"]
        XCTAssertTrue(clear.isHittable); clear.tap()
        XCTAssertTrue(app.staticTexts["Start with a sound"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["mix-play"].exists)
        XCTAssertFalse(app.buttons["Clear mix"].exists, "Clear does not present a confirmation")
        capture("44-clear-immediate")
        tab("Saved")
        XCTAssertTrue(app.buttons["Load Quiet moment 1"].exists, "Clear keeps saved mixes")
        app.buttons["Load Quiet moment 1"].tap()
        XCTAssertEqual(app.buttons["mix-play"].label, "Play soundscape")
        reveal(timer)
        XCTAssertEqual(timer.label, "Sleep timer", "Clear cancels the previous sleep timer")
        tab("Sounds")
        let favorites = app.buttons["filter-favorites"]
        reveal(favorites); favorites.tap()
        XCTAssertTrue(app.buttons["favorite-light-rain"].exists, "Clear keeps favorites")
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
    func testSilentFavoritesAfterDeepLibraryScroll() {
        launchScrollFixture()
        // Keep the mini-player present, as in the reported physical-device case.
        let favorites = app.buttons["filter-favorites"]
        let search = app.textFields["sound-search"]
        reveal(favorites)
        let normalCardHeight = app.buttons["sound-light-rain"].frame.height
        for _ in 0..<12 { app.swipeUp() }
        XCTAssertTrue(favorites.isHittable, "Filters must remain available deep in the full catalogue")
        let pinnedTop = search.frame.minY
        XCTAssertFalse(app.staticTexts["A little space\nto be."].isHittable, "The test must actually leave the introduction behind")
        XCTAssertLessThan(pinnedTop, app.frame.minY + app.frame.height * 0.3, "The test must reach the pinned library controls")
        capture("46-before-deep-favorites")
        favorites.tap()
        let firstFavorite = app.buttons["sound-light-rain"]
        XCTAssertTrue(firstFavorite.waitForExistence(timeout: 5))
        capture("47-deep-favorites-populated")
        XCTAssertTrue(search.isHittable, "Filtering must not leave the header above a stale scroll offset")
        XCTAssertEqual(search.frame.minY, pinnedTop, accuracy: 3)
        XCTAssertTrue(firstFavorite.isHittable)
        XCTAssertEqual(firstFavorite.frame.height, normalCardHeight, accuracy: 1, "A single result keeps the catalogue's card proportions")
        XCTAssertGreaterThanOrEqual(firstFavorite.frame.minY, favorites.frame.maxY)
        XCTAssertLessThan(firstFavorite.frame.maxY, app.buttons["mini-play"].frame.minY)
        // Removing the last favorite must keep the empty-state explanation visible.
        app.buttons["favorite-light-rain"].tap()
        XCTAssertTrue(app.staticTexts["Keep your favorites close"].isHittable)
        app.buttons["filter-all"].tap()
        for _ in 0..<12 { app.swipeUp() }
        favorites.tap()
        capture("48-deep-favorites-empty")
        XCTAssertTrue(search.isHittable)
        XCTAssertEqual(search.frame.minY, pinnedTop, accuracy: 3)
        XCTAssertTrue(app.staticTexts["Keep your favorites close"].isHittable)
        XCTAssertGreaterThanOrEqual(app.staticTexts["Keep your favorites close"].frame.minY, favorites.frame.maxY)
        app.buttons["filter-all"].tap()
        XCTAssertTrue(firstFavorite.isHittable, "Returning to All starts at its first results")
        XCTAssertEqual(app.buttons["mini-play"].label, "Play mix", "The entire regression stays silent")
    }
    func testSilentEmptyFavoritesAfterDeepAlphabeticalScroll() {
        let favorites = app.buttons["filter-favorites"]
        let search = app.textFields["sound-search"]
        reveal(favorites)
        app.buttons["sort-sounds"].tap()
        app.buttons["Alphabetical"].tap()
        for _ in 0..<12 { app.swipeUp() }
        let pinnedTop = search.frame.minY
        XCTAssertFalse(app.staticTexts["A little space\nto be."].isHittable)
        XCTAssertLessThan(pinnedTop, app.frame.minY + app.frame.height * 0.3)
        favorites.tap()
        capture("49-deep-empty-favorites-no-mix")
        XCTAssertTrue(search.isHittable)
        XCTAssertEqual(search.frame.minY, pinnedTop, accuracy: 3)
        XCTAssertTrue(app.staticTexts["Keep your favorites close"].isHittable)
        XCTAssertFalse(app.buttons["mini-play"].exists)
        app.buttons["filter-all"].tap()
        XCTAssertTrue(app.buttons["sound-airplane"].isHittable)
        for _ in 0..<6 { app.swipeUp() }
        app.buttons["filter-rain"].tap()
        XCTAssertTrue(search.isHittable)
        XCTAssertEqual(search.frame.minY, pinnedTop, accuracy: 3)
        XCTAssertTrue(app.buttons["sound-heavy-rain"].isHittable)
        capture("50-deep-category-results")
    }
    func testSilentFullFavoritesAndSearchState() {
        app.terminate()
        app.launchArguments.append("-ui-testing-all-favorites")
        app.launch()
        let favorites = app.buttons["filter-favorites"]
        let search = app.textFields["sound-search"]
        reveal(favorites)
        for _ in 0..<12 { app.swipeUp() }
        XCTAssertFalse(app.staticTexts["A little space\nto be."].isHittable)
        XCTAssertLessThan(search.frame.minY, app.frame.minY + app.frame.height * 0.3)
        favorites.tap()
        XCTAssertTrue(app.buttons["sound-light-rain"].isHittable, "Favorites starts at the first result even when all 89 sounds are favorites")
        XCTAssertGreaterThanOrEqual(app.buttons["sound-light-rain"].frame.minY, favorites.frame.maxY)
        search.tap(); search.typeText("rain\n")
        XCTAssertEqual(search.value as? String, "rain", "Filtering preserves keyboard focus through every character")
        tab("Saved"); tab("Sounds")
        XCTAssertTrue(app.staticTexts["A little space\nto be."].isHittable)
        reveal(search)
        XCTAssertEqual(search.value as? String, "rain")
        XCTAssertTrue(favorites.isSelected)
        XCTAssertFalse(app.buttons["mini-play"].exists)
        capture("51-full-favorites-search")
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
        let driftLicense = app.buttons["Nodus Drift · MIT"]
        reveal(driftLicense); driftLicense.tap()
        let driftBody = app.textViews.matching(NSPredicate(format: "value BEGINSWITH %@", "MIT License\n\nCopyright (c) 2026 Jorge Pérez Burgueño")).firstMatch
        XCTAssertTrue(driftBody.waitForExistence(timeout: 5))
        XCTAssertTrue((driftBody.value as? String ?? "").contains("Permission is hereby granted"))
        XCTAssertFalse(app.buttons["GNU AGPL v3"].exists)
        capture("45-drift-mit-license")
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
