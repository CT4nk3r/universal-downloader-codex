import XCTest
@testable import UniversalDownloader

final class YTDLPClientTests: XCTestCase {
    func testDownloadEmitsProgressAndFinishedFileName() async throws {
        let client = YTDLPClient(metadataResolver: StubMetadataResolver(title: nil))
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
            case .finished(let fileName, _):
                finishedFileName = fileName
            case .idle, .stopped, .failed:
                break
            }
        }

        XCTAssertEqual(runningProgress.first, 5)
        XCTAssertEqual(runningProgress.last, 100)
        XCTAssertEqual(finishedFileName, "demo_track.mp3")
    }

    func testDownloadUsesResolvedMetadataTitleForDisplayAndFileName() async throws {
        let client = YTDLPClient(metadataResolver: StubMetadataResolver(title: "Actual Video Title"))
        let url = URL(string: "https://youtube.com/watch?v=abc123")!
        var finishedTitle: String?
        var finishedFileName: String?
        var finishedItem: DownloadItem?

        for try await state in client.download(url: url, options: DownloadOptions(outputFormat: .mp4)) {
            switch state {
            case .running(_, _, let items):
                finishedItem = items.last { $0.status == .finished }
            case .finished(let fileName, let title):
                finishedFileName = fileName
                finishedTitle = title
            case .idle, .stopped, .failed:
                break
            }
        }

        XCTAssertEqual(finishedTitle, "Actual Video Title")
        XCTAssertEqual(finishedFileName, "Actual_Video_Title.mp4")
        XCTAssertEqual(finishedItem?.title, "Actual Video Title")
        XCTAssertEqual(finishedItem?.fileName, "Actual_Video_Title.mp4")
    }

    func testMetadataResolverExtractsOpenGraphTitle() {
        let html = """
        <html>
          <head>
            <meta property="og:title" content="A Real &amp; Useful Title - YouTube">
            <title>Fallback</title>
          </head>
        </html>
        """

        XCTAssertEqual(WebPageMetadataResolver.extractTitle(from: html), "A Real & Useful Title")
    }

    func testMetadataResolverExtractsOpenGraphTitleWhenContentComesFirst() {
        let html = #"<meta content="Content First Title" property="og:title">"#

        XCTAssertEqual(WebPageMetadataResolver.extractTitle(from: html), "Content First Title")
    }

    func testMetadataResolverExtractsFallbackTitleTag() {
        let html = "<html><head><title>Fallback &quot;Title&quot;</title></head></html>"

        XCTAssertEqual(WebPageMetadataResolver.extractTitle(from: html), #"Fallback "Title""#)
    }

    func testMetadataResolverReturnsNilForMissingTitle() {
        XCTAssertNil(WebPageMetadataResolver.extractTitle(from: "<html><body>No title</body></html>"))
    }

    func testMetadataResolverDecodesHtmlEntities() {
        let html = #"<title>A &amp; B &lt; C &gt; D &#39;quote&#39;</title>"#

        XCTAssertEqual(WebPageMetadataResolver.extractTitle(from: html), "A & B < C > D 'quote'")
    }

    func testYouTubeOEmbedURLUsesCanonicalVideoID() throws {
        let url = try XCTUnwrap(URL(string: "https://www.youtube.com/watch?v=dQw4w9WgXcQx"))
        let oEmbedURL = try XCTUnwrap(WebPageMetadataResolver.youtubeOEmbedURL(for: url))

        XCTAssertTrue(oEmbedURL.absoluteString.contains("dQw4w9WgXcQ"))
        XCTAssertFalse(oEmbedURL.absoluteString.contains("dQw4w9WgXcQx"))
    }

    func testYouTubeOEmbedURLSupportsShortLinks() throws {
        let url = try XCTUnwrap(URL(string: "https://youtu.be/dQw4w9WgXcQ"))
        let oEmbedURL = try XCTUnwrap(WebPageMetadataResolver.youtubeOEmbedURL(for: url))

        XCTAssertTrue(oEmbedURL.absoluteString.contains("dQw4w9WgXcQ"))
    }

    func testYouTubeOEmbedURLRejectsNonYouTubeLinks() throws {
        let url = try XCTUnwrap(URL(string: "https://example.com/watch?v=dQw4w9WgXcQ"))

        XCTAssertNil(WebPageMetadataResolver.youtubeOEmbedURL(for: url))
    }

    func testMetadataResolverExtractsYouTubeOEmbedTitle() throws {
        let data = try XCTUnwrap("""
        {"title":"Rick Astley - Never Gonna Give You Up (Official Video) (4K Remaster)"}
        """.data(using: .utf8))

        XCTAssertEqual(
            WebPageMetadataResolver.title(fromOEmbed: data),
            "Rick Astley - Never Gonna Give You Up (Official Video) (4K Remaster)"
        )
    }

    func testMetadataResolverReturnsNilForInvalidOEmbedData() throws {
        let data = try XCTUnwrap("{}".data(using: .utf8))

        XCTAssertNil(WebPageMetadataResolver.title(fromOEmbed: data))
    }
}

private struct StubMetadataResolver: MediaMetadataResolving {
    let title: String?

    func title(for url: URL) async -> String? {
        title
    }
}
