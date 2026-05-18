import XCTest

final class UniversalDownloaderUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testLaunchShowsDownloadSurface() {
        let app = launchApp()

        XCTAssertTrue(app.navigationBars["Universal Downloader"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.textFields["download.urlField"].exists)
        XCTAssertTrue(app.buttons["download.primaryButton"].exists)
        XCTAssertTrue(app.buttons["download.optionsToggle"].exists)
        XCTAssertEqual(app.staticTexts["download.statusTitle"].label, "Ready to download")
    }

    func testSoundCloudLinkSwitchesOptionsToAudioFormats() {
        let app = launchApp()

        enterURL("https://soundcloud.com/artist/track", in: app)
        app.buttons["download.optionsToggle"].tap()

        XCTAssertTrue(app.buttons["MP3"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.buttons["M4A"].exists)
        XCTAssertFalse(app.buttons["MP4"].exists)
    }

    func testDownloadCompletesAndShowsSavedFile() {
        let app = launchApp()

        enterURL("https://example.com/demo-track", in: app)
        app.buttons["download.primaryButton"].tap()

        let statusTitle = app.staticTexts["download.statusTitle"]
        let saved = NSPredicate(format: "label == %@", "Saved")
        expectation(for: saved, evaluatedWith: statusTitle)
        waitForExpectations(timeout: 8)

        XCTAssertEqual(app.staticTexts["download.statusSubtitle"].label, "demo track\ndemo_track.mp4")
    }

    func testOptionsCanOpen() {
        let app = launchApp()

        showOptions(in: app)

        XCTAssertTrue(app.buttons["MP4"].exists)
    }

    func testOptionsCanClose() {
        let app = launchApp()

        showOptions(in: app)
        app.buttons["download.optionsToggle"].tap()

        XCTAssertFalse(app.buttons["MP4"].exists)
    }

    func testOptionsShowMp4Format() {
        assertOptionButton("MP4")
    }

    func testOptionsShowMovFormat() {
        assertOptionButton("MOV")
    }

    func testOptionsShowMkvFormat() {
        assertOptionButton("MKV")
    }

    func testOptionsShowWebmFormat() {
        assertOptionButton("WEBM")
    }

    func testOptionsShowWithAudioMode() {
        assertOptionButton("With audio")
    }

    func testOptionsShowAudioOnlyMode() {
        assertOptionButton("Audio only")
    }

    func testOptionsShowNoAudioMode() {
        assertOptionButton("No audio")
    }

    func testOptionsShowSourceFormat() {
        assertOptionButton("Source")
    }

    func testVideoOptionsHideMp3Format() {
        assertOptionButtonAbsent("MP3")
    }

    func testVideoOptionsHideWavFormat() {
        assertOptionButtonAbsent("WAV")
    }

    func testOptionsShowDownloadOptionsHeader() {
        assertOptionText("download.optionsHeader")
    }

    func testSoundCloudLinkShowsMp3Format() {
        enterURLAndAssertOption("https://soundcloud.com/artist/track", "MP3")
    }

    func testSoundCloudLinkShowsWavFormat() {
        enterURLAndAssertOption("https://soundcloud.com/artist/track", "WAV")
    }

    func testSoundCloudLinkShowsOggFormat() {
        enterURLAndAssertOption("https://soundcloud.com/artist/track", "OGG")
    }

    func testSoundCloudLinkShowsM4aFormat() {
        enterURLAndAssertOption("https://soundcloud.com/artist/track", "M4A")
    }

    func testSpotifyLinkShowsAudioFormatPicker() {
        enterURLAndAssertOption("https://open.spotify.com/track/demo", "MP3")
    }

    func testYoutubeLinkKeepsMp4Format() {
        enterURLAndAssertOption("https://www.youtube.com/watch?v=dQw4w9WgXcQ", "MP4")
    }

    func testInvalidDownloadShowsFailureMessage() {
        let app = launchApp()

        enterURL("not a url", in: app)
        app.buttons["download.primaryButton"].tap()

        XCTAssertTrue(app.staticTexts["No downloadable URL found."].waitForExistence(timeout: 2))
    }

    func testAboutButtonOpensDialog() {
        let app = launchApp()

        app.buttons["About"].tap()

        XCTAssertTrue(app.alerts["Universal Downloader"].waitForExistence(timeout: 2))
    }

    func testAboutDialogShowsEmailLogsAction() {
        let app = launchApp()

        app.buttons["About"].tap()

        XCTAssertTrue(app.alerts["Universal Downloader"].buttons["Email logs"].waitForExistence(timeout: 2))
    }

    func testAboutDialogShowsShareLogsAction() {
        let app = launchApp()

        app.buttons["About"].tap()

        XCTAssertTrue(app.alerts["Universal Downloader"].buttons["Share logs"].waitForExistence(timeout: 2))
    }

    func testAboutDialogCanClose() {
        let app = launchApp()

        app.buttons["About"].tap()
        app.alerts["Universal Downloader"].buttons["Close"].tap()

        XCTAssertFalse(app.alerts["Universal Downloader"].exists)
    }

    func testUrlFieldAcceptsTypedLink() {
        let app = launchApp()

        enterURL("https://example.com/demo", in: app)

        XCTAssertEqual(app.textFields["download.urlField"].value as? String, "https://example.com/demo")
    }

    func testOptionsToggleIsReachableFromLaunch() {
        let app = launchApp()

        XCTAssertTrue(app.buttons["download.optionsToggle"].waitForExistence(timeout: 5))
    }

    func testReadyStatusSubtitleIsVisibleOnLaunch() {
        let app = launchApp()

        XCTAssertTrue(app.staticTexts["Paste a link above, or share one into this app."].exists)
    }

    private func launchApp() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing"]
        app.launch()
        return app
    }

    private func assertOptionButton(_ title: String) {
        let app = launchApp()

        showOptions(in: app)

        XCTAssertTrue(app.buttons[title].waitForExistence(timeout: 2))
    }

    private func assertOptionButtonAbsent(_ title: String) {
        let app = launchApp()

        showOptions(in: app)

        XCTAssertFalse(app.buttons[title].exists)
    }

    private func assertOptionText(_ title: String) {
        let app = launchApp()

        showOptions(in: app)

        XCTAssertTrue(app.descendants(matching: .any)[title].waitForExistence(timeout: 2))
    }

    private func enterURLAndAssertOption(_ value: String, _ expectedButton: String) {
        let app = launchApp()

        enterURL(value, in: app)
        showOptions(in: app)

        XCTAssertTrue(app.buttons[expectedButton].waitForExistence(timeout: 2))
    }

    private func showOptions(in app: XCUIApplication) {
        if !app.buttons["MP4"].exists && !app.buttons["MP3"].exists {
            app.buttons["download.optionsToggle"].tap()
        }
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
