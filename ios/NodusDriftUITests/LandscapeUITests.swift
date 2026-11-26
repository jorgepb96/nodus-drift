import XCTest

final class LandscapeUITests: XCTestCase {
    private func tab(_ title: String, in app: XCUIApplication) {
        // Duo exposes a side rail rather than an XCUIElementTypeTabBar.
        let button = app.buttons[title].firstMatch
        XCTAssertTrue(button.waitForExistence(timeout: 6)); button.tap()
    }
    func testPersonalizedSnowWolfAndCarInPortraitAndLandscape() {
        continueAfterFailure = false
        defer { XCUIDevice.shared.orientation = .portrait }
        for (ids, title, searchTerms) in [(["walk-in-snow", "wolf"], "Snow", ["Footsteps in the snow", "Wolf"]),
                                        (["rain-on-car-roof", "windshield-wipers"], "Car", ["Rain on a car", "Windshield wipers"])] {
            XCUIDevice.shared.orientation = .portrait
            let app = XCUIApplication()
            app.launchArguments = ["-ui-testing", "-ui-testing-silent", "-AppleLanguages", "(en)"]
            app.launch()
            let search = app.textFields["sound-search"]
            XCTAssertTrue(search.waitForExistence(timeout: 8))
            for index in ids.indices {
                if app.buttons["Clear search"].exists { app.buttons["Clear search"].tap() }
                search.tap()
                search.typeText(searchTerms[index])
                for _ in 0..<6 { if app.buttons["sound-\(ids[index])"].isHittable { break }; app.swipeUp() }
                let sound = app.buttons["sound-\(ids[index])"]
                XCTAssertTrue(sound.waitForExistence(timeout: 5)); sound.tap()
            }
            tab("My mix", in: app)
            let enter = app.buttons["drift-into-meditation"]
            for _ in 0..<10 { if enter.isHittable { break }; app.swipeUp() }
            XCTAssertTrue(enter.isHittable); enter.tap(); app.tap()
            XCTAssertTrue(app.buttons["leave-meditation"].waitForExistence(timeout: 5))
            XCTAssertEqual(app.staticTexts["meditation-landscape-name"].label, title)
            if app.windows.firstMatch.frame.width > app.windows.firstMatch.frame.height {
                app.buttons["rotate-immersive-view"].tap()
            }
            XCTAssertLessThan(app.windows.firstMatch.frame.width, app.windows.firstMatch.frame.height)
            app.buttons["hide-meditation-controls"].tap()
            let portrait = XCTAttachment(screenshot: XCUIScreen.main.screenshot()); portrait.name = "personalized-\(title)-portrait"; portrait.lifetime = .keepAlways; add(portrait)
            XCUIDevice.shared.orientation = .landscapeLeft
            app.tap()
            // Current Device Hub runtimes may ignore sensor rotation; exercise the native user control too.
            if app.windows.firstMatch.frame.width <= app.windows.firstMatch.frame.height {
                app.buttons["rotate-immersive-view"].tap()
            }
            let rotated = NSPredicate { _, _ in app.windows.firstMatch.frame.width > app.windows.firstMatch.frame.height }
            expectation(for: rotated, evaluatedWith: app); waitForExpectations(timeout: 8)
            XCTAssertTrue(app.buttons["leave-meditation"].isHittable)
            app.buttons["hide-meditation-controls"].tap()
            let wide = XCTAttachment(screenshot: XCUIScreen.main.screenshot()); wide.name = "personalized-\(title)-horizontal"; wide.lifetime = .keepAlways; add(wide)
            app.tap()
            if app.windows.firstMatch.frame.width > app.windows.firstMatch.frame.height { app.buttons["rotate-immersive-view"].tap() }
            app.buttons["leave-meditation"].tap(); app.terminate()
        }
    }
    func testPersonalizedSnowWolfInResizableWindow() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing", "-ui-testing-silent", "-AppleLanguages", "(en)"]
        app.launch()
        let search = app.textFields["sound-search"]
        XCTAssertTrue(search.waitForExistence(timeout: 8))
        for (id, query) in [("walk-in-snow", "Footsteps in the snow"), ("wolf", "Wolf")] {
            if app.buttons["Clear search"].exists { app.buttons["Clear search"].tap() }
            search.tap(); search.typeText(query)
            let sound = app.buttons["sound-\(id)"]
            for _ in 0..<8 { if sound.isHittable { break }; app.swipeUp() }
            XCTAssertTrue(sound.isHittable); sound.tap()
        }
        tab("My mix", in: app)
        let enter = app.buttons["drift-into-meditation"]
        for _ in 0..<8 { if enter.isHittable { break }; app.swipeUp() }
        XCTAssertTrue(enter.isHittable); enter.tap(); app.tap()
        XCTAssertTrue(app.buttons["leave-meditation"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts["meditation-landscape-name"].label, "Snow")
        XCTAssertFalse(app.staticTexts["meditation-scene-elements"].label.contains("Wolf"))
        app.buttons["hide-meditation-controls"].tap()
        let capture = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        capture.name = "personalized-Duo-expanded"; capture.lifetime = .keepAlways; add(capture)
        app.tap(); app.buttons["leave-meditation"].tap()
    }
    func testMiniPlayerOpensLandscapeDirectly() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing", "-ui-testing-silent", "-AppleLanguages", "(en)"]
        app.launch()
        XCTAssertTrue(app.buttons["starter-light-rain"].waitForExistence(timeout: 8))
        app.buttons["starter-light-rain"].tap(); tab("Sounds", in: app)
        let picture = app.buttons["mini-landscape"]
        XCTAssertTrue(picture.waitForExistence(timeout: 5))
        let image = XCTAttachment(screenshot: XCUIScreen.main.screenshot()); image.name = "mini-player-landscape-shortcut"; image.lifetime = .keepAlways; add(image)
        picture.tap(); app.tap()
        XCTAssertTrue(app.buttons["leave-meditation"].waitForExistence(timeout: 5))
        app.buttons["leave-meditation"].tap()
    }
    func testActiveMixHandsOffToStudioAndMiniPlayerOpensTheActiveScene() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing", "-ui-testing-studio-reset", "-AppleLanguages", "(en)"]
        app.launch()
        XCTAssertTrue(app.buttons["starter-light-rain"].waitForExistence(timeout: 8))
        app.buttons["starter-light-rain"].tap(); tab("Sounds", in: app)
        app.buttons["mini-play"].tap()
        XCTAssertEqual(app.buttons["mini-play"].label, "Pause mix")
        tab("Studio", in: app)
        let listen = app.buttons["Listen to A storm beyond the cabin"]
        for _ in 0..<8 { if listen.isHittable { break }; app.swipeUp() }
        XCTAssertTrue(listen.isHittable); listen.tap()
        Thread.sleep(forTimeInterval: 3)
        XCTAssertFalse(app.alerts["Soundscape Studio"].exists)
        tab("Sounds", in: app)
        XCTAssertTrue(app.buttons["Open your scene"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.buttons["mini-play"].label, "Pause mix")
        app.buttons["mini-landscape"].tap(); app.tap()
        XCTAssertTrue(app.buttons["Leave immersive landscape"].waitForExistence(timeout: 5))
        app.buttons["Leave immersive landscape"].tap()
        app.buttons["mini-play"].tap()
    }
    func testStudioMiniPlayerRemainsAvailableWhilePausedWithoutASimpleMix() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing", "-ui-testing-studio-reset", "-AppleLanguages", "(en)"]
        app.launch(); tab("Studio", in: app)
        let listen = app.buttons["Listen to A storm beyond the cabin"]
        for _ in 0..<8 { if listen.isHittable { break }; app.swipeUp() }
        XCTAssertTrue(listen.isHittable); listen.tap()
        Thread.sleep(forTimeInterval: 2)
        XCTAssertFalse(app.alerts["Soundscape Studio"].exists)
        tab("Sounds", in: app)
        let transport = app.buttons["mini-play"], picture = app.buttons["mini-landscape"]
        XCTAssertTrue(transport.waitForExistence(timeout: 5)); transport.tap()
        XCTAssertTrue(picture.waitForExistence(timeout: 5))
        XCTAssertEqual(transport.label, "Play mix")
        picture.tap(); app.tap()
        XCTAssertTrue(app.buttons["Leave immersive landscape"].waitForExistence(timeout: 5))
        app.buttons["Leave immersive landscape"].tap()
        transport.tap(); XCTAssertEqual(transport.label, "Pause mix")
        transport.tap()
    }
    func testBrandAndCompanionAcrossEveryTab() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing", "-ui-testing-silent", "-AppleLanguages", "(en)"]
        app.launch()
        for title in ["Sounds", "My mix", "Studio", "Saved", "Settings"] {
            tab(title, in: app)
            XCTAssertTrue(app.descendants(matching: .any)["nodus-brand"].firstMatch.waitForExistence(timeout: 5), title)
            let image = XCTAttachment(screenshot: XCUIScreen.main.screenshot()); image.name = "brand-\(title)"; image.lifetime = .keepAlways; add(image)
        }
    }
    func testRealMixMeditationCanChooseLandscapeOrNodi() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing", "-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launch()
        let search = app.textFields["sound-search"]
        XCTAssertTrue(search.waitForExistence(timeout: 8))
        for (query, id) in [("Light rain", "light-rain"), ("Campfire", "campfire")] {
            if app.buttons["Clear search"].exists { app.buttons["Clear search"].tap() }
            search.tap()
            search.typeText(query)
            for _ in 0..<6 { if app.buttons["sound-\(id)"].isHittable { break }; app.swipeUp() }
            let sound = app.buttons["sound-\(id)"]
            XCTAssertTrue(sound.waitForExistence(timeout: 5)); sound.tap()
        }
        tab("My mix", in: app)
        let enter = app.buttons["drift-into-meditation"]
        for _ in 0..<8 { if enter.isHittable { break }; app.swipeUp() }
        XCTAssertTrue(enter.isHittable); enter.tap(); app.tap()
        XCTAssertTrue(app.buttons["leave-meditation"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts["meditation-landscape-name"].label, "Cabin")
        XCTAssertEqual(app.buttons["meditation-play"].label, "Pause mix", "Real audio must remain active in landscape meditation")
        let capture = XCTAttachment(screenshot: XCUIScreen.main.screenshot()); capture.name = "mix-meditation-cabin"; capture.lifetime = .keepAlways; add(capture)
        app.tap() // Refresh the five-second controls timer after the screenshot.
        app.buttons["meditation-visual-motion"].tap()
        XCTAssertTrue(app.buttons["meditation-visual-motion"].label.contains("Animate visuals"))
        XCTAssertEqual(app.buttons["meditation-play"].label, "Pause mix", "Pausing visuals must not pause audio")
        app.buttons["meditation-appearance-immersive-nodi"].tap()
        XCTAssertTrue(app.staticTexts["Just be here."].waitForExistence(timeout: 3))
        app.buttons["leave-meditation"].tap()
        app.terminate()
        app.launchArguments.removeAll { $0 == "-ui-testing" }; app.launch()
        app.buttons["enter-meditation"].tap()
        XCTAssertTrue(app.staticTexts["Just be here."].waitForExistence(timeout: 5), "The chosen appearance must persist")
        app.buttons["leave-meditation"].tap()
    }

    func testAppearanceSwitchKeepsSelectorStableAndPlaybackRunning() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing", "-AppleLanguages", "(en)"]
        app.launch()
        let rain = app.buttons["sound-light-rain"]
        XCTAssertTrue(rain.waitForExistence(timeout: 8))
        for _ in 0..<6 { if rain.isHittable { break }; app.swipeUp() }
        rain.tap()
        XCTAssertTrue(app.buttons["mini-landscape"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.buttons["mini-play"].label, "Pause mix")
        app.buttons["mini-landscape"].tap(); app.tap()
        let picker = app.buttons["meditation-appearance-immersive-nodi"]
        XCTAssertTrue(picker.waitForExistence(timeout: 5))
        let before = picker.frame
        for _ in 0..<3 {
            // Accessibility queries can outlast the five-second controls timer.
            // Reveal/refresh before choosing, just as a person would do.
            app.tap()
            app.buttons["meditation-appearance-immersive-nodi"].tap()
            XCTAssertTrue(app.staticTexts["Just be here."].waitForExistence(timeout: 3), app.debugDescription)
            XCTAssertTrue(picker.isHittable)
            XCTAssertEqual(picker.frame, before)
            XCTAssertEqual(app.buttons["meditation-play"].label, "Pause mix")
            app.tap()
            app.buttons["meditation-appearance-immersive-landscape"].tap()
            XCTAssertTrue(app.staticTexts["meditation-landscape-name"].waitForExistence(timeout: 3))
            XCTAssertTrue(picker.isHittable, "Choosing the landscape must not hide the selector")
            XCTAssertEqual(picker.frame, before)
            XCTAssertEqual(app.buttons["meditation-play"].label, "Pause mix")
        }
        let capture = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        capture.name = "simplified-landscape-after-appearance-switches"; capture.lifetime = .keepAlways; add(capture)
        app.buttons["leave-meditation"].tap()
        app.buttons["mini-play"].tap()
    }

    func testDedicatedWideCabinAndCarRenderWithCleanControls() {
        continueAfterFailure = false
        defer { XCUIDevice.shared.orientation = .portrait }
        for (name, arguments) in [
            ("cabin", ["-landscape-preview", "cabin"]),
            ("car", ["-composition-preview", "rain-on-car-roof,windshield-wipers"])
        ] {
            let app = XCUIApplication()
            app.launchArguments = arguments + ["-ui-testing-silent", "-AppleLanguages", "(en)"]
            app.launch(); app.tap()
            let rotate = app.buttons["rotate-immersive-view"]
            XCTAssertTrue(rotate.waitForExistence(timeout: 8))
            if app.windows.firstMatch.frame.width < app.windows.firstMatch.frame.height { rotate.tap() }
            let wide = NSPredicate { _, _ in app.windows.firstMatch.frame.width > app.windows.firstMatch.frame.height }
            expectation(for: wide, evaluatedWith: app); waitForExpectations(timeout: 8)
            app.tap() // Hide the fixture controls before inspecting the native image.
            let hidden = NSPredicate { _, _ in !rotate.exists }
            expectation(for: hidden, evaluatedWith: app); waitForExpectations(timeout: 5)
            let capture = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
            capture.name = "build16-\(name)-dedicated-wide"; capture.lifetime = .keepAlways; add(capture)
            XCTAssertEqual(app.state, .runningForeground)
            app.terminate()
        }
    }

    func testStarterPlaybackCanOpenAndCloseImmersiveWithoutCrashing() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing", "-ui-testing-studio-reset", "-AppleLanguages", "(en)"]
        app.launch(); tab("Studio", in: app)
        for title in ["A storm beyond the cabin", "The forest wakes", "A tide under the stars"] {
            let listen = app.buttons["Listen to \(title)"]
            for _ in 0..<8 { if listen.isHittable { break }; app.swipeUp() }
            XCTAssertTrue(listen.isHittable); listen.tap()
            Thread.sleep(forTimeInterval: 3)
            for _ in 0..<8 { if app.buttons["Enter immersive landscape"].isHittable { break }; app.swipeDown() }
            XCTAssertEqual(app.buttons["studio-play"].label, "Pause scene")
            app.buttons["Enter immersive landscape"].tap(); app.tap()
            XCTAssertTrue(app.buttons["Leave immersive landscape"].waitForExistence(timeout: 5))
            Thread.sleep(forTimeInterval: 1)
            XCTAssertTrue(app.buttons["Pause visuals"].exists)
            app.buttons["Leave immersive landscape"].tap()
        }
        XCTAssertEqual(app.state, .runningForeground)
    }
    func testPhotographicLandscapesAndAnimationPause() {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
        for landscape in ["forest", "coast", "mountains", "cabin", "river", "snow", "night"] {
            let app = XCUIApplication()
            app.launchArguments = ["-landscape-preview", landscape, "-ui-testing-silent", "-AppleLanguages", "(en)"]
            app.launch(); app.tap()
            let motion = app.buttons["landscape-motion"]
            XCTAssertTrue(motion.waitForExistence(timeout: 8))
            Thread.sleep(forTimeInterval: 1.5)
            let screenshot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
            screenshot.name = "realistic-\(landscape)"; screenshot.lifetime = .keepAlways; add(screenshot)
            motion.tap(); XCTAssertEqual(motion.label, "Resume animation")
            if landscape == "cabin" {
                XCUIDevice.shared.orientation = .landscapeLeft
                Thread.sleep(forTimeInterval: 0.5)
                let wide = XCTAttachment(screenshot: XCUIScreen.main.screenshot()); wide.name = "realistic-cabin-landscape"
                wide.lifetime = .keepAlways; add(wide)
                XCUIDevice.shared.orientation = .portrait
            }
            app.terminate()
        }
    }
}
