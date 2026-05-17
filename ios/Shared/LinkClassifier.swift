import Foundation

enum LinkClassifier {
    private static let audioFirstHosts = [
        "soundcloud.com",
        "bandcamp.com",
        "music.apple.com",
        "open.spotify.com"
    ]

    static func isAudioFirst(_ rawURL: String) -> Bool {
        guard
            let host = URL(string: rawURL.trimmingCharacters(in: .whitespacesAndNewlines))?
                .host?
                .lowercased()
                .replacingOccurrences(of: "www.", with: "")
        else { return false }

        return audioFirstHosts.contains { host == $0 || host.hasSuffix(".\($0)") }
    }
}
