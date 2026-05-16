import Foundation

enum DownloadState {
    case running(progress: Int, message: String)
    case finished(fileName: String)
    case failed(String)
}

struct YTDLPClient {
    func download(url: URL) -> AsyncThrowingStream<DownloadState, Error> {
        AsyncThrowingStream { continuation in
            Task {
                continuation.yield(.running(progress: 5, message: "Preparing download"))

                // TODO: Replace this simulator with the selected yt-dlp runtime or API client.
                // The UI and share extension depend only on this async stream contract.
                for progress in [20, 40, 65, 85, 100] {
                    try await Task.sleep(nanoseconds: 350_000_000)
                    continuation.yield(.running(progress: progress, message: "Downloading media"))
                }

                continuation.yield(.finished(fileName: "downloaded-video.mp4"))
                continuation.finish()
            }
        }
    }
}

