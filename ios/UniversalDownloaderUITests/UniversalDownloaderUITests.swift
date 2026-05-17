import XCTest

final class UniversalDownloaderUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testLaunchShowsDownloadSurface() {
        let app = launchApp()

        XCTAssertTrue(app.staticTexts["download.title"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.textFields["download.urlField"].exists)
        XCTAssertTrue(app.buttons["download.primaryButton"].exists)
        XCTAssertTrue(app.buttons["download.optionsToggle"].exists)
        XCTAssertEqual(app.staticTexts["download.statusTitle"].label, "Ready to download")
    }

    func testSoundCloudLinkSwitchesOptionsToAudioFormats() {
        let app = launchApp()

        enterURL("https://soundcloud.com/artist/track", in: app)
        app.buttons["download.optionsToggle"].tap()

        XCTAssertTrue(app.buttons["optionChip.MP3"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.buttons["optionChip.M4A"].exists)
        XCTAssertFalse(app.buttons["optionChip.MP4"].exists)
    }

    func testDownloadCompletesAndShowsSavedFile() {
        let app = launchApp()

        enterURL("https://example.com/demo-track", in: app)
        app.buttons["download.primaryButton"].tap()

        let statusTitle = app.staticTexts["download.statusTitle"]
        let saved = NSPredicate(format: "label == %@", "Saved")
        expectation(for: saved, evaluatedWith: statusTitle)
        waitForExpectations(timeout: 8)

        XCTAssertEqual(app.staticTexts["download.statusSubtitle"].label, "demo_track.mp4")
    }

    private func launchApp() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing"]
        app.launch()
        return app
    }

    private func enterURL(_ value: String, in app: XCUIApplication) {
        let field = app.textFields["download.urlField"]
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.tap()
        field.typeText(value)
        dismissKeyboard(in: app)
    }

    private func dismissKeyboard(in app: XCUIApplication) {
        guard app.keyboards.count > 0 else { return }
        let keyboard = app.keyboards.firstMatch
        for buttonTitle in ["Done", "Return", "Go"] where keyboard.buttons[buttonTitle].exists {
            keyboard.buttons[buttonTitle].tap()
            return
        }
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.08)).tap()
    }
}
