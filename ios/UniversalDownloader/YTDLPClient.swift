import Foundation

enum DownloadState {
    case idle
    case running(progress: Int, message: String, items: [DownloadItem] = [])
    case finished(fileName: String)
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
    var progress: Int
    var status: DownloadItemStatus
}

enum DownloadItemStatus {
    case running
    case finished
}

struct YTDLPClient {
    func download(url: URL, options: DownloadOptions = DownloadOptions()) -> AsyncThrowingStream<DownloadState, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                AppLogger.info("Preparing iOS download: \(url.absoluteString.redactedURLSummary()), options=\(options)")
                continuation.yield(.running(progress: 5, message: "Preparing download"))

                let fileName = resolvedFileName(for: url, options: options)
                let total = looksLikePlaylist(url) ? 15 : nil
                var items: [DownloadItem] = []

                do {
                    for step in [12, 24, 38, 52, 68, 84, 100] {
                        try Task.checkCancellation()
                        try await Task.sleep(nanoseconds: 300_000_000)

                        let item = DownloadItem(
                            index: 1,
                            total: total,
                            title: fileName.deletingPathExtensionForDisplay,
                            fileName: fileName,
                            progress: step,
                            status: step == 100 ? .finished : .running
                        )
                        items = [item]
                        continuation.yield(.running(progress: step, message: message(for: step, options: options), items: items))
                    }

                    let savedName = try savePlaceholderFile(named: fileName, sourceURL: url, options: options)
                    AppLogger.info("iOS download finished: fileName=\(savedName)")
                    continuation.yield(.finished(fileName: savedName))
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

    private func resolvedFileName(for url: URL, options: DownloadOptions) -> String {
        let title = url.deletingPathExtension().lastPathComponent
            .replacingOccurrences(of: "-", with: " ")
            .replacingOccurrences(of: "_", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
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
        let directory = FileManager.default.urls(
            for: .documentDirectory,
            in: .userDomainMask
        )[0].appendingPathComponent("UniversalDownloader", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let fileURL = directory.appendingPathComponent(fileName)
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

private extension String {
    var deletingPathExtensionForDisplay: String {
        (self as NSString).deletingPathExtension.replacingOccurrences(of: "_", with: " ")
    }

    func redactedURLSummary() -> String {
        guard !isEmpty else { return "blank" }
        let host = URL(string: self)?.host ?? "unknown"
        return "length=\(count), host=\(host)"
    }
}
