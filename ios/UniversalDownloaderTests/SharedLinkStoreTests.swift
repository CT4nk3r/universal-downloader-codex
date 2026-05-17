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
}
