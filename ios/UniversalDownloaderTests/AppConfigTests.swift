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
}
