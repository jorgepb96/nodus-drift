import XCTest

final class StudioUITests: XCTestCase {
    private var app: XCUIApplication!
    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-ui-testing", "-ui-testing-studio-reset", "-ui-testing-silent", "-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launch()
    }
    private func capture(_ name: String) {
        let screenshot = XCTAttachment(screenshot: XCUIScreen.main.screenshot()); screenshot.name = name
        screenshot.lifetime = .keepAlways; add(screenshot)
    }
    private func reveal(_ element: XCUIElement) {
        for _ in 0..<10 { if element.isHittable { return }; app.swipeUp() }
        XCTAssertTrue(element.isHittable)
    }
    private func openStudio() {
        let tab = app.tabBars.buttons["Studio"]
        XCTAssertTrue(tab.waitForExistence(timeout: 5)); tab.tap()
    }
    func testManualSceneCreationAndAllEditors() {
        openStudio(); capture("studio-home")
        app.buttons["studio-create-manual"].tap()
        let field = app.textFields["studio-scene-name"]
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.tap(); field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: (field.value as? String ?? "").count) + "My quiet forest\n")
        let add = app.buttons["studio-add-sound"]; reveal(add); add.tap()
        let rain = app.buttons["Light rain"]
        XCTAssertTrue(rain.waitForExistence(timeout: 5)); rain.tap()
        XCTAssertTrue(app.buttons["Edit Light rain"].waitForExistence(timeout: 5))
        capture("studio-layers")
        app.buttons["Edit Light rain"].tap()
        let build = app.buttons["Make a gradual build"]; reveal(build); build.tap()
        app.buttons["Done"].tap()
        let timeline = app.buttons["Timeline"]; reveal(timeline); timeline.tap(); app.swipeUp()
        XCTAssertTrue(app.buttons["Edit automation for Light rain"].waitForExistence(timeout: 5))
        capture("studio-timeline")
        let space = app.buttons["Space"]; reveal(space); space.tap(); app.swipeUp(); capture("studio-space")
        app.swipeDown()
        let visuals = app.buttons["Visuals"]; reveal(visuals); visuals.tap(); app.swipeUp()
        XCTAssertTrue(app.switches["Visual landscape"].waitForExistence(timeout: 5)); capture("studio-visuals")
        app.swipeDown(); app.swipeDown()
        let save = app.buttons["studio-save"]; reveal(save); save.tap()
        XCTAssertTrue(app.staticTexts["Scene saved on this device."].waitForExistence(timeout: 5)); app.alerts.buttons["Done"].tap()
        app.terminate(); app.launchArguments.removeAll { $0 == "-ui-testing-studio-reset" }; app.launch(); openStudio()
        XCTAssertTrue(app.staticTexts["My quiet forest"].firstMatch.waitForExistence(timeout: 5))
    }
    func testGenerationAttributionAndModelLicensesAreAccessible() {
        openStudio()
        app.buttons["studio-continue"].tap()
        let generate = app.buttons["Generate"]; reveal(generate); generate.tap()
        XCTAssertTrue(app.staticTexts["Powered by Stable Audio 3 · Stability AI"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["studio-generate-audio"].isEnabled)
        let models = app.buttons["Models & licenses"]; reveal(models); models.tap()
        XCTAssertTrue(app.staticTexts["Powered by Stability AI"].waitForExistence(timeout: 5))
        let license = app.buttons["Stability AI Community License"]; reveal(license); license.tap()
        XCTAssertTrue(app.textViews["legal-document-body"].waitForExistence(timeout: 5))
        capture("studio-model-license")
    }
    func testAppleIntelligenceFallbackKeepsManualCreationAvailable() {
        openStudio(); app.buttons["studio-create-ai"].tap()
        XCTAssertTrue(app.staticTexts["Manual editing is always available. No external AI service is used."].waitForExistence(timeout: 5))
        capture("studio-ai-availability")
        app.buttons["Done"].tap()
        XCTAssertTrue(app.buttons["studio-create-manual"].isEnabled)
    }
}
