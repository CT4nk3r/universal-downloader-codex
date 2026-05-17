import XCTest
@testable import UniversalDownloader

final class LinkClassifierTests: XCTestCase {
    func testAudioFirstHostsReturnTrue() {
        XCTAssertTrue(LinkClassifier.isAudioFirst("https://soundcloud.com/artist/track"))
        XCTAssertTrue(LinkClassifier.isAudioFirst("https://www.bandcamp.com/artist/track"))
        XCTAssertTrue(LinkClassifier.isAudioFirst("https://artists.music.apple.com/song"))
    }

    func testVideoFirstAndInvalidInputsReturnFalse() {
        XCTAssertFalse(LinkClassifier.isAudioFirst("https://www.youtube.com/watch?v=dQw4w9WgXcQ"))
        XCTAssertFalse(LinkClassifier.isAudioFirst("not a url"))
    }
}
