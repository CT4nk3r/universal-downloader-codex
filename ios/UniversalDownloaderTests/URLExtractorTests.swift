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
}
