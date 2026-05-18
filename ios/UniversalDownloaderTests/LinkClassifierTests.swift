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

    func testSubdomainsOfAudioFirstHostsReturnTrue() {
        XCTAssertTrue(LinkClassifier.isAudioFirst("https://artist.bandcamp.com/album/demo"))
        XCTAssertTrue(LinkClassifier.isAudioFirst("https://tracks.soundcloud.com/private/demo"))
    }

    func testSpotifyTrackReturnsTrue() {
        XCTAssertTrue(LinkClassifier.isAudioFirst("https://open.spotify.com/track/demo"))
    }

    func testWhitespaceIsIgnoredBeforeClassification() {
        XCTAssertTrue(LinkClassifier.isAudioFirst("  https://music.apple.com/us/album/demo  "))
    }

    func testBlankURLReturnsFalse() {
        XCTAssertFalse(LinkClassifier.isAudioFirst("   "))
    }

    func testLookalikeHostReturnsFalse() {
        XCTAssertFalse(LinkClassifier.isAudioFirst("https://soundcloud.com.evil.example/artist/track"))
    }
}
