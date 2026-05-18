import Foundation

enum DownloadState {
    case idle
    case running(progress: Int, message: String, items: [DownloadItem] = [])
    case finished(fileName: String, title: String?)
    case stopped(completedCount: Int)
    case failed(String)
}

struct DownloadOptions: CustomStringConvertible {
    var outputFormat: OutputFormat = .source
    var quality: VideoQuality = .original
    var audioMode: AudioMode = .videoWithAudio
    var audioQuality: AudioQuality = .original

    var description: String {
        "DownloadOptions(outputFormat: \(outputFormat), quality: \(quality), audioMode: \(audioMode), audioQuality: \(audioQuality))"
    }
}

enum OutputFormat: String, CaseIterable {
    case source = "Source"
    case mp4 = "MP4"
    case mov = "MOV"
    case mkv = "MKV"
    case webm = "WEBM"
    case m4a = "M4A"
    case mp3 = "MP3"
    case ogg = "OGG"
    case wav = "WAV"
}

enum VideoQuality: String, CaseIterable {
    case original = "Original"
    case p1080 = "1080p"
    case p720 = "720p"
    case p480 = "480p"
    case p360 = "360p"
}

enum AudioQuality: String, CaseIterable {
    case original = "Original"
    case k320 = "320k"
    case k192 = "192k"
    case k128 = "128k"
    case k96 = "96k"
}

enum AudioMode: String, CaseIterable {
    case videoWithAudio = "With audio"
    case audioOnly = "Audio only"
    case videoOnly = "No audio"
}

struct DownloadItem: Equatable {
    var index: Int
    var total: Int?
    var title: String
    var fileName: String?
    var fileURL: URL?
    var progress: Int
    var status: DownloadItemStatus
}

enum DownloadItemStatus {
    case running
    case finished
}

protocol MediaMetadataResolving {
    func title(for url: URL) async -> String?
}

struct YTDLPClient {
    var metadataResolver: MediaMetadataResolving

    init(metadataResolver: MediaMetadataResolving = WebPageMetadataResolver()) {
        self.metadataResolver = metadataResolver
    }

    func download(url: URL, options: DownloadOptions = DownloadOptions()) -> AsyncThrowingStream<DownloadState, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                AppLogger.info("Preparing iOS download: \(url.absoluteString.redactedURLSummary()), options=\(options)")
                continuation.yield(.running(progress: 5, message: "Preparing download"))

                let displayTitle = await resolvedTitle(for: url)
                let fileName = resolvedFileName(for: url, title: displayTitle, options: options)
                let total = looksLikePlaylist(url) ? 15 : nil
                var items: [DownloadItem] = []

                do {
                    for step in [12, 24, 38, 52, 68, 84, 100] {
                        try Task.checkCancellation()
                        try await Task.sleep(nanoseconds: 300_000_000)

                        let item = DownloadItem(
                            index: 1,
                            total: total,
                            title: displayTitle,
                            fileName: fileName,
                            progress: step,
                            status: step == 100 ? .finished : .running
                        )
                        items = [item]
                        continuation.yield(.running(progress: step, message: message(for: step, options: options), items: items))
                    }

                    let savedName = try savePlaceholderFile(named: fileName, sourceURL: url, options: options)
                    AppLogger.info("iOS download finished: title=\(displayTitle), fileName=\(savedName)")
                    continuation.yield(.finished(fileName: savedName, title: displayTitle))
                    continuation.finish()
                } catch is CancellationError {
                    AppLogger.info("iOS download stopped by user")
                    continuation.yield(.stopped(completedCount: items.filter { $0.status == .finished }.count))
                    continuation.finish()
                } catch {
                    AppLogger.error("iOS download failed", error: error)
                    continuation.yield(.failed(error.localizedDescription))
                    continuation.finish()
                }
            }

            continuation.onTermination = { _ in task.cancel() }
        }
    }

    private func message(for progress: Int, options: DownloadOptions) -> String {
        if progress < 20 { return "Resolving media" }
        if progress < 100 { return options.audioMode == .audioOnly ? "Extracting audio" : "Downloading media" }
        return "Finalizing file"
    }

    private func looksLikePlaylist(_ url: URL) -> Bool {
        URLComponents(url: url, resolvingAgainstBaseURL: false)?
            .queryItems?
            .contains { $0.name.lowercased() == "list" } == true
    }

    private func resolvedTitle(for url: URL) async -> String {
        if let title = await metadataResolver.title(for: url), !title.isEmpty {
            return title
        }

        let pathTitle = url.deletingPathExtension().lastPathComponent
            .replacingOccurrences(of: "-", with: " ")
            .replacingOccurrences(of: "_", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        if !pathTitle.isEmpty && pathTitle.lowercased() != "watch" {
            return pathTitle
        }

        return url.host?.replacingOccurrences(of: "www.", with: "") ?? "Download"
    }

    private func resolvedFileName(for url: URL, title: String, options: DownloadOptions) -> String {
        let base = title.isEmpty ? (url.host ?? "download") : title
        let safeBase = base
            .replacingOccurrences(of: #"[^A-Za-z0-9 ._-]+"#, with: "", options: .regularExpression)
            .replacingOccurrences(of: " ", with: "_")
        return "\(safeBase).\(fileExtension(for: options))"
    }

    private func fileExtension(for options: DownloadOptions) -> String {
        switch options.outputFormat {
        case .source:
            switch options.audioMode {
            case .audioOnly: return "m4a"
            case .videoWithAudio, .videoOnly: return "mp4"
            }
        case .mp4: return "mp4"
        case .mov: return "mov"
        case .mkv: return "mkv"
        case .webm: return "webm"
        case .m4a: return "m4a"
        case .mp3: return "mp3"
        case .ogg: return "ogg"
        case .wav: return "wav"
        }
    }

    private func savePlaceholderFile(named fileName: String, sourceURL: URL, options: DownloadOptions) throws -> String {
        try DownloadFileStore.prepareDirectory()
        let fileURL = DownloadFileStore.fileURL(named: fileName)
        let body = """
        Universal Downloader iOS placeholder
        Source: \(sourceURL.absoluteString)
        Options: \(options)

        The iOS UI and share-extension flow are native. Replace YTDLPClient with the chosen iOS-safe download engine.
        """
        try body.write(to: fileURL, atomically: true, encoding: .utf8)
        return fileName
    }
}

enum DownloadFileStore {
    static var directoryURL: URL {
        FileManager.default.urls(
            for: .documentDirectory,
            in: .userDomainMask
        )[0].appendingPathComponent("Downloads", isDirectory: true)
    }

    static func prepareDirectory() throws {
        try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
    }

    static func fileURL(named fileName: String) -> URL {
        directoryURL.appendingPathComponent(fileName)
    }

    static func displayPath(for fileURL: URL) -> String {
        "Files > On My iPhone > Universal Downloader > Downloads > \(fileURL.lastPathComponent)"
    }

    static func delete(_ fileURL: URL) throws {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return }
        try FileManager.default.removeItem(at: fileURL)
    }
}

struct WebPageMetadataResolver: MediaMetadataResolving {
    func title(for url: URL) async -> String? {
        guard ["http", "https"].contains(url.scheme?.lowercased()) else { return nil }
        if let title = await Self.youtubeOEmbedTitle(for: url) {
            return title
        }

        var request = URLRequest(url: url)
        request.timeoutInterval = 8
        request.setValue(
            "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1",
            forHTTPHeaderField: "User-Agent"
        )

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            let previewData = Data(data.prefix(256_000))
            guard let httpResponse = response as? HTTPURLResponse,
                  (200..<400).contains(httpResponse.statusCode),
                  let html = String(data: previewData, encoding: .utf8) ?? String(data: previewData, encoding: .isoLatin1)
            else {
                return nil
            }

            return Self.extractTitle(from: html)
        } catch {
            AppLogger.debug("Metadata title lookup failed: \(error.localizedDescription)")
            return nil
        }
    }

    static func youtubeOEmbedURL(for url: URL) -> URL? {
        guard let host = url.host?.lowercased() else { return nil }
        let videoID: String?

        if host == "youtu.be" || host.hasSuffix(".youtu.be") {
            videoID = canonicalYouTubeVideoID(from: url.pathComponents.dropFirst().first)
        } else if host == "youtube.com" || host.hasSuffix(".youtube.com") {
            videoID = URLComponents(url: url, resolvingAgainstBaseURL: false)?
                .queryItems?
                .first { $0.name == "v" }
                .flatMap { canonicalYouTubeVideoID(from: $0.value) }
        } else {
            videoID = nil
        }

        guard let videoID else { return nil }

        var components = URLComponents(string: "https://www.youtube.com/oembed")
        components?.queryItems = [
            URLQueryItem(name: "url", value: "https://www.youtube.com/watch?v=\(videoID)"),
            URLQueryItem(name: "format", value: "json")
        ]
        return components?.url
    }

    static func title(fromOEmbed data: Data) -> String? {
        guard
            let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let title = object["title"] as? String
        else {
            return nil
        }

        let normalized = normalizeTitle(title)
        return normalized.isEmpty ? nil : normalized
    }

    static func extractTitle(from html: String) -> String? {
        let patterns = [
            #"<meta\s+(?:property|name)=["']og:title["']\s+content=["']([^"']+)["']"#,
            #"<meta\s+content=["']([^"']+)["']\s+(?:property|name)=["']og:title["']"#,
            #"<title[^>]*>(.*?)</title>"#
        ]

        for pattern in patterns {
            guard let match = html.range(of: pattern, options: [.regularExpression, .caseInsensitive]) else {
                continue
            }

            let matched = String(html[match])
            let valuePattern = pattern.contains("<title") ? #">([\s\S]*?)<"# : #"content=["']([^"']+)["']"#
            guard let valueRange = matched.range(of: valuePattern, options: [.regularExpression, .caseInsensitive]) else {
                continue
            }

            var value = String(matched[valueRange])
            value = value
                .replacingOccurrences(of: #"^content=["']"#, with: "", options: .regularExpression)
                .replacingOccurrences(of: #"["']$"#, with: "", options: .regularExpression)
                .replacingOccurrences(of: #"^>"#, with: "", options: .regularExpression)
                .replacingOccurrences(of: #"<$"#, with: "", options: .regularExpression)

            let normalized = normalizeTitle(value)
            if !normalized.isEmpty {
                return normalized
            }
        }

        return nil
    }

    private static func normalizeTitle(_ value: String) -> String {
        value
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&#39;", with: "'")
            .replacingOccurrences(of: "&apos;", with: "'")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
            .replacingOccurrences(of: #"(\s[-|]\s)?YouTube$"#, with: "", options: [.regularExpression, .caseInsensitive])
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func youtubeOEmbedTitle(for url: URL) async -> String? {
        guard let oEmbedURL = youtubeOEmbedURL(for: url) else { return nil }

        var request = URLRequest(url: oEmbedURL)
        request.timeoutInterval = 8

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse,
                  (200..<400).contains(httpResponse.statusCode)
            else {
                return nil
            }

            return title(fromOEmbed: data)
        } catch {
            AppLogger.debug("YouTube oEmbed title lookup failed: \(error.localizedDescription)")
            return nil
        }
    }

    private static func canonicalYouTubeVideoID(from value: String?) -> String? {
        guard let value else { return nil }
        let allowed = CharacterSet(charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789_-")
        let prefix = String(value.unicodeScalars.prefix { allowed.contains($0) }.prefix(11))
        return prefix.count == 11 ? prefix : nil
    }
}

private extension String {
    func redactedURLSummary() -> String {
        guard !isEmpty else { return "blank" }
        let host = URL(string: self)?.host ?? "unknown"
        return "length=\(count), host=\(host)"
    }
}
