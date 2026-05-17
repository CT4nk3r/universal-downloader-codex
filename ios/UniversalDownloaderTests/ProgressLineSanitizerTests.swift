import XCTest
@testable import UniversalDownloader

final class ProgressLineSanitizerTests: XCTestCase {
    func testStripsLeadingYtDlpTags() {
        let output = ProgressLineSanitizer.sanitize("[youtube] abc: Downloading player API JSON")

        XCTAssertEqual(output, "abc: Downloading player API JSON")
    }

    func testStripsMultipleLeadingTagsAndCollapsesWhitespace() {
        let output = ProgressLineSanitizer.sanitize("[jsc:quickjs] [youtube]   Solving\nJS\tchallenge")

        XCTAssertEqual(output, "Solving JS challenge")
    }

    func testReturnsWorkingForBlankLines() {
        XCTAssertEqual(ProgressLineSanitizer.sanitize("   \n\t"), "Working...")
    }

    func testTruncatesLongLines() {
        let output = ProgressLineSanitizer.sanitize("[download] " + String(repeating: "a", count: 200), maxLength: 20)

        XCTAssertEqual(output.count, 20)
        XCTAssertTrue(output.hasSuffix("..."))
    }
}
