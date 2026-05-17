import Foundation
import OSLog

enum AppLogger {
    private static let logger = Logger(subsystem: "com.universaldownloader.app", category: "UniversalDownloader")
    private static let logFileName = "universal-downloader.log"
    private static let maxLogBytes = 256 * 1024
    private static let queue = DispatchQueue(label: "com.universaldownloader.logger")

    static var currentLogFile: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(logFileName)
    }

    static func initialize() {
        info("App logger initialized")
    }

    static func debug(_ message: String) {
        logger.debug("\(message, privacy: .public)")
        append(level: "D", message: message)
    }

    static func info(_ message: String) {
        logger.info("\(message, privacy: .public)")
        append(level: "I", message: message)
    }

    static func warning(_ message: String) {
        logger.warning("\(message, privacy: .public)")
        append(level: "W", message: message)
    }

    static func error(_ message: String, error: Error? = nil) {
        let fullMessage = error.map { "\(message): \($0.localizedDescription)" } ?? message
        logger.error("\(fullMessage, privacy: .public)")
        append(level: "E", message: fullMessage)
    }

    private static func append(level: String, message: String) {
        queue.async {
            let fileURL = currentLogFile
            rotateIfNeeded(fileURL)
            let timestamp = ISO8601DateFormatter().string(from: Date())
            let line = "\(timestamp) \(level) \(message)\n"
            if FileManager.default.fileExists(atPath: fileURL.path),
               let handle = try? FileHandle(forWritingTo: fileURL) {
                defer { try? handle.close() }
                _ = try? handle.seekToEnd()
                try? handle.write(contentsOf: Data(line.utf8))
            } else {
                try? line.write(to: fileURL, atomically: true, encoding: .utf8)
            }
        }
    }

    private static func rotateIfNeeded(_ fileURL: URL) {
        guard
            let attributes = try? FileManager.default.attributesOfItem(atPath: fileURL.path),
            let size = attributes[.size] as? NSNumber,
            size.intValue > maxLogBytes,
            let data = try? Data(contentsOf: fileURL)
        else { return }

        let tail = data.suffix(maxLogBytes / 2)
        try? Data(tail).write(to: fileURL, options: .atomic)
    }
}
