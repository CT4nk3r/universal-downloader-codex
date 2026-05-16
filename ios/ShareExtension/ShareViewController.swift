import UIKit
import UniformTypeIdentifiers

final class ShareViewController: UIViewController {
    private let store = SharedLinkStore()

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        view.backgroundColor = .systemBackground
        extractSharedURL { [weak self] url in
            if let url {
                self?.store.enqueue(url)
                self?.openContainingApp()
            }
            self?.extensionContext?.completeRequest(returningItems: [], completionHandler: nil)
        }
    }

    private func extractSharedURL(completion: @escaping (URL?) -> Void) {
        guard let item = extensionContext?.inputItems.first as? NSExtensionItem else {
            completion(nil)
            return
        }

        let providers = item.attachments ?? []
        if let urlProvider = providers.first(where: { $0.hasItemConformingToTypeIdentifier(UTType.url.identifier) }) {
            urlProvider.loadItem(forTypeIdentifier: UTType.url.identifier, options: nil) { item, _ in
                completion(item as? URL)
            }
            return
        }

        if let textProvider = providers.first(where: { $0.hasItemConformingToTypeIdentifier(UTType.plainText.identifier) }) {
            textProvider.loadItem(forTypeIdentifier: UTType.plainText.identifier, options: nil) { item, _ in
                let text = item as? String
                completion(text.flatMap(URLExtractor.firstURL(in:)))
            }
            return
        }

        completion(nil)
    }

    private func openContainingApp() {
        extensionContext?.open(AppConfig.openAppURL, completionHandler: nil)
    }
}
