import UIKit

final class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?

    func scene(
        _ scene: UIScene,
        willConnectTo session: UISceneSession,
        options connectionOptions: UIScene.ConnectionOptions
    ) {
        guard let windowScene = scene as? UIWindowScene else { return }

        AppLogger.initialize()
        let controller = DownloadViewController()
        let window = UIWindow(windowScene: windowScene)
        window.rootViewController = controller
        window.makeKeyAndVisible()
        self.window = window

        if let url = connectionOptions.urlContexts.first?.url {
            process(url: url)
        } else {
            controller.processSharedLinks()
        }
    }

    func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
        guard let url = URLContexts.first?.url else { return }
        process(url: url)
    }

    func sceneDidBecomeActive(_ scene: UIScene) {
        controller?.processSharedLinks()
    }

    private var controller: DownloadViewController? {
        window?.rootViewController as? DownloadViewController
    }

    private func process(url: URL) {
        guard
            let sharedURL = URLComponents(url: url, resolvingAgainstBaseURL: false)?
                .queryItems?
                .first(where: { $0.name == "url" })?
                .value
                .flatMap(URL.init(string:))
        else {
            controller?.processSharedLinks()
            return
        }

        controller?.process(sharedURL: sharedURL)
    }
}
