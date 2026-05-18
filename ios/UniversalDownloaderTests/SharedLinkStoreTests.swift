import XCTest
@testable import UniversalDownloader

final class SharedLinkStoreTests: XCTestCase {
    private var defaultsName: String!
    private var defaults: UserDefaults!

    override func setUp() {
        super.setUp()
        defaultsName = "UniversalDownloaderTests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: defaultsName)
        defaults.removePersistentDomain(forName: defaultsName)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: defaultsName)
        defaults = nil
        defaultsName = nil
        super.tearDown()
    }

    func testDrainReturnsQueuedLinksInOrderAndClearsQueue() {
        let store = SharedLinkStore(defaults: defaults)
        let first = URL(string: "https://example.com/one")!
        let second = URL(string: "https://example.com/two")!

        store.enqueue(first)
        store.enqueue(second)

        XCTAssertEqual(store.drain(), [first, second])
        XCTAssertEqual(store.drain(), [])
    }

    func testDrainSkipsMalformedStoredValues() {
        defaults.set(["http://[", "https://example.com/ok"], forKey: AppConfig.pendingLinksKey)
        let store = SharedLinkStore(defaults: defaults)

        XCTAssertEqual(store.drain(), [URL(string: "https://example.com/ok")!])
    }

    func testDrainOnEmptyStoreReturnsEmptyArray() {
        let store = SharedLinkStore(defaults: defaults)

        XCTAssertEqual(store.drain(), [])
    }

    func testEnqueueAppendsToExistingValues() {
        defaults.set(["https://example.com/existing"], forKey: AppConfig.pendingLinksKey)
        let store = SharedLinkStore(defaults: defaults)
        let appended = URL(string: "https://example.com/appended")!

        store.enqueue(appended)

        XCTAssertEqual(
            defaults.stringArray(forKey: AppConfig.pendingLinksKey),
            ["https://example.com/existing", "https://example.com/appended"]
        )
    }

    func testNilDefaultsFallsBackToStandardDefaults() {
        let store = SharedLinkStore(defaults: nil)
        let url = URL(string: "https://example.com/fallback")!

        UserDefaults.standard.removeObject(forKey: AppConfig.pendingLinksKey)
        store.enqueue(url)

        XCTAssertEqual(store.drain(), [url])
        XCTAssertNil(UserDefaults.standard.stringArray(forKey: AppConfig.pendingLinksKey))
    }
}
