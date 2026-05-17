import Foundation

enum AppConfig {
    static let appGroupIdentifier = "group.com.universaldownloader.shared"
    static let pendingLinksKey = "pendingSharedLinks"
    static let openAppURL = URL(string: "universaldownloader://shared")!
    static let supportEmail = "59850112+CT4nk3r@users.noreply.github.com"

    static func openAppURL(for sharedURL: URL) -> URL {
        var components = URLComponents(url: openAppURL, resolvingAgainstBaseURL: false)!
        components.queryItems = [URLQueryItem(name: "url", value: sharedURL.absoluteString)]
        return components.url ?? openAppURL
    }
}
