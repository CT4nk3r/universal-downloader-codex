import Foundation

struct SharedLinkStore {
    private let defaults: UserDefaults

    init(defaults: UserDefaults? = UserDefaults(suiteName: AppConfig.appGroupIdentifier)) {
        self.defaults = defaults ?? .standard
    }

    func enqueue(_ url: URL) {
        var links = defaults.stringArray(forKey: AppConfig.pendingLinksKey) ?? []
        links.append(url.absoluteString)
        defaults.set(links, forKey: AppConfig.pendingLinksKey)
    }

    func drain() -> [URL] {
        let values = defaults.stringArray(forKey: AppConfig.pendingLinksKey) ?? []
        defaults.removeObject(forKey: AppConfig.pendingLinksKey)
        return values.compactMap(URL.init(string:))
    }
}

