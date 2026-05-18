import XCTest
@testable import UniversalDownloader

final class AppConfigTests: XCTestCase {
    func testOpenAppURLCarriesSharedURLAsQueryItem() {
        let sharedURL = URL(string: "https://example.com/watch?v=abc&list=playlist")!

        let openURL = AppConfig.openAppURL(for: sharedURL)
        let components = URLComponents(url: openURL, resolvingAgainstBaseURL: false)
        let sharedQueryValue = components?.queryItems?.first { $0.name == "url" }?.value

        XCTAssertEqual(components?.scheme, "universaldownloader")
        XCTAssertEqual(components?.host, "shared")
        XCTAssertEqual(sharedQueryValue, sharedURL.absoluteString)
    }

    func testOpenAppURLUsesStableCustomScheme() {
        XCTAssertEqual(AppConfig.openAppURL.scheme, "universaldownloader")
        XCTAssertEqual(AppConfig.openAppURL.host, "shared")
    }

    func testSupportEmailUsesGithubNoReplyAddress() {
        XCTAssertTrue(AppConfig.supportEmail.contains("@users.noreply.github.com"))
    }

    func testOpenAppURLPercentEncodesNestedSharedURL() {
        let sharedURL = URL(string: "https://example.com/watch?title=A%20B&list=x")!

        let openURL = AppConfig.openAppURL(for: sharedURL)
        let value = URLComponents(url: openURL, resolvingAgainstBaseURL: false)?
            .queryItems?
            .first { $0.name == "url" }?
            .value

        XCTAssertEqual(value, sharedURL.absoluteString)
    }
}
