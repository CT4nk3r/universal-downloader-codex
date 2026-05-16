import UIKit

final class DownloadViewController: UIViewController {
    private let downloader = YTDLPClient()
    private let store = SharedLinkStore()
    private let urlField = UITextField()
    private let progressView = UIProgressView(progressViewStyle: .default)
    private let statusLabel = UILabel()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor.systemBackground
        buildView()
        processSharedLinks()
    }

    func processSharedLinks() {
        guard let url = store.drain().last else { return }
        urlField.text = url.absoluteString
        startDownload(url)
    }

    private func buildView() {
        let title = UILabel()
        title.text = "Universal Downloader"
        title.font = .preferredFont(forTextStyle: .largeTitle)
        title.adjustsFontForContentSizeCategory = true

        urlField.placeholder = "Paste or share a video link"
        urlField.borderStyle = .roundedRect
        urlField.keyboardType = .URL
        urlField.autocapitalizationType = .none
        urlField.autocorrectionType = .no

        let button = UIButton(type: .system)
        button.setTitle("Download", for: .normal)
        button.configuration = .filled()
        button.addTarget(self, action: #selector(downloadTapped), for: .touchUpInside)

        progressView.isHidden = true
        statusLabel.text = "Ready"
        statusLabel.numberOfLines = 0

        let stack = UIStackView(arrangedSubviews: [title, urlField, button, progressView, statusLabel])
        stack.axis = .vertical
        stack.spacing = 16
        stack.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: view.layoutMarginsGuide.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: view.layoutMarginsGuide.trailingAnchor),
            stack.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
    }

    @objc private func downloadTapped() {
        guard
            let text = urlField.text,
            let url = URLExtractor.firstURL(in: text)
        else {
            statusLabel.text = "No downloadable URL found."
            return
        }

        startDownload(url)
    }

    private func startDownload(_ url: URL) {
        progressView.isHidden = false
        progressView.progress = 0
        statusLabel.text = "Preparing download"

        Task { @MainActor in
            do {
                for try await state in downloader.download(url: url) {
                    render(state)
                }
            } catch {
                render(.failed(error.localizedDescription))
            }
        }
    }

    private func render(_ state: DownloadState) {
        switch state {
        case .running(let progress, let message):
            progressView.isHidden = false
            progressView.progress = Float(progress) / 100
            statusLabel.text = message
        case .finished(let fileName):
            progressView.isHidden = true
            statusLabel.text = "Saved \(fileName)"
        case .failed(let reason):
            progressView.isHidden = true
            statusLabel.text = reason
        }
    }
}

