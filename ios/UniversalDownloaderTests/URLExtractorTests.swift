import XCTest
@testable import UniversalDownloader

final class URLExtractorTests: XCTestCase {
    func testFirstURLReturnsFirstLinkInPlainText() {
        let text = "Save this https://example.com/watch?v=123 and ignore https://example.com/second"

        let url = URLExtractor.firstURL(in: text)

        XCTAssertEqual(url?.absoluteString, "https://example.com/watch?v=123")
    }

    func testFirstURLReturnsNilWhenTextHasNoLink() {
        XCTAssertNil(URLExtractor.firstURL(in: "there is no downloadable link here"))
    }

    func testFirstURLFindsHttpLink() {
        let url = URLExtractor.firstURL(in: "Open http://example.com/watch")

        XCTAssertEqual(url?.absoluteString, "http://example.com/watch")
    }

    func testFirstURLIgnoresLeadingWords() {
        let url = URLExtractor.firstURL(in: "please save this: https://example.com/video")

        XCTAssertEqual(url?.host, "example.com")
    }

    func testFirstURLHandlesNewlineSeparatedLinks() {
        let url = URLExtractor.firstURL(in: "first line\nhttps://example.com/video\nhttps://example.com/second")

        XCTAssertEqual(url?.path, "/video")
    }

    func testFirstURLHandlesParenthesizedLink() {
        let url = URLExtractor.firstURL(in: "(https://example.com/video)")

        XCTAssertEqual(url?.absoluteString, "https://example.com/video")
    }
}
