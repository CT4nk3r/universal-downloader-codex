import XCTest
@testable import UniversalDownloader

final class DownloadViewModelTests: XCTestCase {
    @MainActor
    func testAudioFirstURLSwitchesToAudioOptions() {
        let viewModel = DownloadViewModel()

        viewModel.urlChanged("https://soundcloud.com/artist/track")

        XCTAssertEqual(viewModel.selectedAudioMode, .audioOnly)
        XCTAssertEqual(viewModel.availableFormats, [.source, .mp3, .wav, .ogg, .m4a])
    }

    @MainActor
    func testFormatSelectionIsRememberedPerAudioMode() {
        let viewModel = DownloadViewModel()

        viewModel.select(format: .webm)
        viewModel.select(audioMode: .audioOnly)
        viewModel.select(format: .mp3)
        viewModel.select(audioMode: .videoWithAudio)

        XCTAssertEqual(viewModel.selectedOutputFormat, .webm)

        viewModel.select(audioMode: .audioOnly)

        XCTAssertEqual(viewModel.selectedOutputFormat, .mp3)
    }

    @MainActor
    func testInvalidDownloadShowsFailureState() {
        let viewModel = DownloadViewModel()

        viewModel.urlText = "not a url"
        viewModel.downloadTapped()

        XCTAssertEqual(viewModel.statusTitle, "Couldn’t download")
        XCTAssertEqual(viewModel.statusSubtitle, "No downloadable URL found.")
        XCTAssertFalse(viewModel.progressVisible)
        XCTAssertFalse(viewModel.stopVisible)
    }

    @MainActor
    func testPlaylistItemListsKeepMostRecentRows() {
        let viewModel = DownloadViewModel()
        viewModel.items = (1...10).map {
            DownloadItem(index: $0, total: 10, title: "Item \($0)", fileName: nil, progress: 100, status: .finished)
        } + (11...16).map {
            DownloadItem(index: $0, total: 16, title: "Item \($0)", fileName: nil, progress: 40, status: .running)
        }

        XCTAssertEqual(viewModel.finishedItems.map(\.index), [3, 4, 5, 6, 7, 8, 9, 10])
        XCTAssertEqual(viewModel.activeItems.map(\.index), [13, 14, 15, 16])
    }

    @MainActor
    func testVideoURLSwitchesBackToVideoOptions() {
        let viewModel = DownloadViewModel()

        viewModel.urlChanged("https://soundcloud.com/artist/track")
        viewModel.urlChanged("https://youtube.com/watch?v=dQw4w9WgXcQ")

        XCTAssertEqual(viewModel.selectedAudioMode, .videoWithAudio)
        XCTAssertEqual(viewModel.availableFormats, [.source, .mp4, .mov, .mkv, .webm])
    }

    @MainActor
    func testAudioOnlyRemembersAudioFormat() {
        let viewModel = DownloadViewModel()

        viewModel.select(audioMode: .audioOnly)
        viewModel.select(format: .wav)
        viewModel.select(audioMode: .videoWithAudio)
        viewModel.select(audioMode: .audioOnly)

        XCTAssertEqual(viewModel.selectedOutputFormat, .wav)
    }

    @MainActor
    func testVideoOnlyUsesVideoFormats() {
        let viewModel = DownloadViewModel()

        viewModel.select(audioMode: .videoOnly)

        XCTAssertEqual(viewModel.availableFormats, [.source, .mp4, .mov, .mkv, .webm])
    }

    @MainActor
    func testShareLogsFallsBackToActivityShare() {
        let viewModel = DownloadViewModel()

        viewModel.shareLogs(emailOnly: false)

        guard case .activity = viewModel.presentedShare else {
            return XCTFail("Expected activity share")
        }
    }
}
