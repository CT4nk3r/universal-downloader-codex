import XCTest
@testable import UniversalDownloader

final class YTDLPClientTests: XCTestCase {
    func testDownloadEmitsProgressAndFinishedFileName() async throws {
        let client = YTDLPClient()
        let url = URL(string: "https://example.com/demo-track")!
        var runningProgress: [Int] = []
        var finishedFileName: String?

        let options = DownloadOptions(
            outputFormat: .mp3,
            quality: .original,
            audioMode: .audioOnly,
            audioQuality: .original
        )
        for try await state in client.download(url: url, options: options) {
            switch state {
            case .running(let progress, _, _):
                runningProgress.append(progress)
            case .finished(let fileName):
                finishedFileName = fileName
            case .idle, .stopped, .failed:
                break
            }
        }

        XCTAssertEqual(runningProgress.first, 5)
        XCTAssertEqual(runningProgress.last, 100)
        XCTAssertEqual(finishedFileName, "demo_track.mp3")
    }
}
