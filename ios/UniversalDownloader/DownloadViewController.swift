import MessageUI
import SwiftUI
import UIKit

final class DownloadViewController: UIHostingController<DownloadScreen> {
    private let viewModel: DownloadViewModel

    init() {
        let viewModel = Self.makeViewModel()
        self.viewModel = viewModel
        super.init(rootView: DownloadScreen(viewModel: viewModel))
        view.backgroundColor = .clear
    }

    @MainActor required dynamic init?(coder aDecoder: NSCoder) {
        let viewModel = Self.makeViewModel()
        self.viewModel = viewModel
        super.init(coder: aDecoder, rootView: DownloadScreen(viewModel: viewModel))
        view.backgroundColor = .clear
    }

    func processSharedLinks() {
        viewModel.processSharedLinks()
    }

    func process(sharedURL url: URL) {
        viewModel.process(sharedURL: url)
    }

    private static func makeViewModel() -> DownloadViewModel {
        guard ProcessInfo.processInfo.arguments.contains("--ui-testing") else {
            return DownloadViewModel()
        }

        return DownloadViewModel(
            downloader: YTDLPClient(metadataResolver: UITestingMetadataResolver())
        )
    }
}

private struct UITestingMetadataResolver: MediaMetadataResolving {
    func title(for url: URL) async -> String? {
        nil
    }
}

struct DownloadScreen: View {
    @ObservedObject var viewModel: DownloadViewModel

    var body: some View {
        NavigationStack {
            Form {
                linkSection

                if viewModel.optionsOpen {
                    optionsSection
                }

                statusSection
                activePlaylistSection
                finishedPlaylistSection
            }
            .formStyle(.grouped)
            .navigationTitle("Universal Downloader")
            .toolbar {
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            viewModel.optionsOpen.toggle()
                        }
                    } label: {
                        Image(systemName: "slider.horizontal.3")
                    }
                    .accessibilityLabel(viewModel.optionsOpen ? "Hide Options" : "Show Options")
                    .accessibilityIdentifier("download.optionsToggle")

                    Button {
                        viewModel.showingAbout = true
                    } label: {
                        Image(systemName: "info.circle")
                    }
                    .accessibilityLabel("About")
                }
            }
        }
        .scrollDismissesKeyboard(.interactively)
        .tint(.accentColor)
        .alert("Universal Downloader", isPresented: $viewModel.showingAbout) {
            Button("Email logs") { viewModel.shareLogs(emailOnly: true) }
            Button("Share logs") { viewModel.shareLogs(emailOnly: false) }
            Button("Close", role: .cancel) {}
        } message: {
            Text("Version \(appVersion)\n\nDiagnostics can help debug playlist, format, and download issues. Logs redact pasted links to host and length only.")
        }
        .sheet(item: $viewModel.presentedShare) { share in
            switch share {
            case .activity(let url):
                ActivityView(items: [url])
            case .mail(let url):
                MailView(logURL: url)
            }
        }
    }

    private var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "Unknown"
    }

    private var linkSection: some View {
        Section {
            TextField("Video link", text: $viewModel.urlText)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .keyboardType(.URL)
                .submitLabel(.done)
                .accessibilityIdentifier("download.urlField")
                .onChange(of: viewModel.urlText) { newValue in
                    viewModel.urlChanged(newValue)
                }

            Button {
                viewModel.downloadTapped()
            } label: {
                HStack(spacing: 7) {
                    Image(systemName: "arrow.down.circle")
                    Text("Download")
                }
                .font(.body.weight(.semibold))
                .frame(maxWidth: .infinity, minHeight: 44)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.tint)
            .contentShape(Rectangle())
            .accessibilityIdentifier("download.primaryButton")
        } footer: {
            Text("Paste a link or share one into the app.")
        }
    }

    private var optionsSection: some View {
        Section {
            Picker("Audio", selection: audioModeBinding) {
                ForEach(AudioMode.allCases, id: \.self) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(.segmented)

            Picker("Format", selection: formatBinding) {
                ForEach(viewModel.availableFormats, id: \.self) { format in
                    Text(format.rawValue).tag(format)
                }
            }
            .pickerStyle(.segmented)
            .accessibilityIdentifier("optionPicker.format")

            if viewModel.selectedAudioMode == .audioOnly {
                Picker("Audio Quality", selection: $viewModel.selectedAudioQuality) {
                    ForEach(AudioQuality.allCases, id: \.self) { quality in
                        Text(quality.rawValue).tag(quality)
                    }
                }
            } else {
                Picker("Video Quality", selection: $viewModel.selectedQuality) {
                    ForEach(VideoQuality.allCases, id: \.self) { quality in
                        Text(quality.rawValue).tag(quality)
                    }
                }
            }
        } header: {
            Text("Download Options")
                .accessibilityIdentifier("download.optionsHeader")
        }
    }

    private var audioModeBinding: Binding<AudioMode> {
        Binding(
            get: { viewModel.selectedAudioMode },
            set: { viewModel.select(audioMode: $0) }
        )
    }

    private var formatBinding: Binding<OutputFormat> {
        Binding(
            get: { viewModel.selectedOutputFormat },
            set: { viewModel.select(format: $0) }
        )
    }

    @ViewBuilder private var statusSection: some View {
        if viewModel.statusVisible {
            Section("Status") {
                if viewModel.progressVisible {
                    ProgressView(value: viewModel.progress, total: 100)
                        .accessibilityIdentifier("download.progress")
                }

                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: viewModel.statusSymbol)
                        .font(.title3)
                        .foregroundStyle(viewModel.statusTint)
                        .frame(width: 26)
                        .padding(.top, 1)

                    VStack(alignment: .leading, spacing: 3) {
                        Text(viewModel.statusTitle)
                            .font(.headline)
                            .accessibilityIdentifier("download.statusTitle")
                        Text(viewModel.statusSubtitle)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .lineLimit(3)
                            .accessibilityIdentifier("download.statusSubtitle")
                    }
                }

                if viewModel.stopVisible {
                    Button(role: .destructive) {
                        viewModel.stopDownload()
                    } label: {
                        Label("Stop Download", systemImage: "xmark.circle")
                    }
                    .accessibilityIdentifier("download.stopButton")
                }
            }
        }
    }

    @ViewBuilder private var activePlaylistSection: some View {
        if !viewModel.activeItems.isEmpty {
            Section("Playlist Progress") {
                ForEach(viewModel.activeItems, id: \.index, content: DownloadItemRow.init)
            }
        }
    }

    @ViewBuilder private var finishedPlaylistSection: some View {
        if !viewModel.finishedItems.isEmpty {
            Section("Downloaded") {
                ForEach(viewModel.finishedItems, id: \.index, content: DownloadItemRow.init)
            }
        }
    }
}

@MainActor
final class DownloadViewModel: ObservableObject {
    @Published var urlText = ""
    @Published var optionsOpen = false
    @Published var progress: Double = 0
    @Published var progressVisible = false
    @Published var stopVisible = false
    @Published var statusVisible = true
    @Published var statusTitle = "Ready to download"
    @Published var statusSubtitle = "Paste a link above, or share one into this app."
    @Published var items: [DownloadItem] = []
    @Published var selectedOutputFormat: OutputFormat = .source
    @Published var selectedVideoFormat: OutputFormat = .source
    @Published var selectedAudioFormat: OutputFormat = .source
    @Published var selectedQuality: VideoQuality = .original
    @Published var selectedAudioMode: AudioMode = .videoWithAudio
    @Published var selectedAudioQuality: AudioQuality = .original
    @Published var showingAbout = false
    @Published var presentedShare: PresentedShare?

    private let downloader: YTDLPClient
    private let store = SharedLinkStore()
    private var downloadTask: Task<Void, Never>?

    private let videoFormats: [OutputFormat] = [.source, .mp4, .mov, .mkv, .webm]
    private let audioFormats: [OutputFormat] = [.source, .mp3, .wav, .ogg, .m4a]

    init(downloader: YTDLPClient = YTDLPClient()) {
        self.downloader = downloader
    }

    var availableFormats: [OutputFormat] {
        selectedAudioMode == .audioOnly ? audioFormats : videoFormats
    }

    var activeItems: [DownloadItem] {
        Array(items.filter { $0.status == .running }.suffix(4))
    }

    var finishedItems: [DownloadItem] {
        Array(items.filter { $0.status == .finished }.suffix(8))
    }

    func processSharedLinks() {
        guard let url = store.drain().last else { return }
        process(sharedURL: url)
    }

    func process(sharedURL url: URL) {
        AppLogger.info("Processing shared link: \(url.absoluteString.redactedURLSummary())")
        urlText = url.absoluteString
        applyAutoUI(for: url.absoluteString)
        startDownload(url)
    }

    func urlChanged(_ value: String) {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        AppLogger.debug("URL input changed: \(trimmed.redactedURLSummary())")
        applyAutoUI(for: trimmed)
    }

    func downloadTapped() {
        guard let url = URLExtractor.firstURL(in: urlText) else {
            render(.failed("No downloadable URL found."))
            return
        }
        startDownload(url)
    }

    func select(format: OutputFormat) {
        selectedOutputFormat = format
        if selectedAudioMode == .audioOnly {
            selectedAudioFormat = format
        } else {
            selectedVideoFormat = format
        }
        AppLogger.debug("Format selected: mode=\(selectedAudioMode), format=\(format)")
    }

    func select(audioMode: AudioMode) {
        selectedAudioMode = audioMode
        applyUI(for: audioMode)
    }

    func stopDownload() {
        AppLogger.info("Stop requested by user")
        downloadTask?.cancel()
        downloadTask = nil
        progressVisible = false
        stopVisible = false
        setStatus(
            title: "Stopped",
            subtitle: "Completed downloads are kept. Partial files are being removed.",
            visible: true
        )
    }

    func shareLogs(emailOnly: Bool) {
        let url = AppLogger.currentLogFile
        AppLogger.info("Share logs requested: emailOnly=\(emailOnly)")
        if emailOnly, MFMailComposeViewController.canSendMail() {
            presentedShare = .mail(url)
        } else {
            presentedShare = .activity(url)
        }
    }

    private func startDownload(_ url: URL) {
        downloadTask?.cancel()
        let options = DownloadOptions(
            outputFormat: selectedOutputFormat,
            quality: selectedQuality,
            audioMode: selectedAudioMode,
            audioQuality: selectedAudioQuality
        )
        AppLogger.info("Download requested: \(url.absoluteString.redactedURLSummary()), options=\(options)")
        render(.running(progress: 5, message: "Preparing download"))

        downloadTask = Task { [downloader] in
            do {
                for try await state in downloader.download(url: url, options: options) {
                    await MainActor.run {
                        self.render(state)
                    }
                }
            } catch {
                await MainActor.run {
                    self.render(.failed(error.localizedDescription))
                }
            }
        }
    }

    private func render(_ state: DownloadState) {
        switch state {
        case .idle:
            progressVisible = false
            stopVisible = false
        case .running(let progress, let message, let items):
            progressVisible = true
            stopVisible = true
            self.progress = Double(progress)
            self.items = items
            setStatus(title: "Downloading", subtitle: ProgressLineSanitizer.sanitize(message), visible: true)
        case .finished(let fileName, let title):
            progressVisible = false
            stopVisible = false
            let subtitle = title.map { "\($0)\n\(fileName)" } ?? fileName
            setStatus(title: "Saved", subtitle: subtitle, visible: true)
        case .stopped(let completedCount):
            progressVisible = false
            stopVisible = false
            setStatus(
                title: "Stopped",
                subtitle: "Completed downloads are kept. Removed partial files. Finished: \(completedCount)",
                visible: true
            )
        case .failed(let reason):
            progressVisible = false
            stopVisible = false
            setStatus(title: "Couldn’t download", subtitle: reason, visible: true)
        }
    }

    private func setStatus(title: String, subtitle: String, visible: Bool) {
        statusTitle = title
        statusSubtitle = subtitle
        statusVisible = visible
    }

    private func applyAutoUI(for url: String) {
        let audioFirst = LinkClassifier.isAudioFirst(url)
        AppLogger.debug("Applying URL defaults: \(url.redactedURLSummary()), audioFirst=\(audioFirst)")
        selectedAudioMode = audioFirst ? .audioOnly : .videoWithAudio
        applyUI(for: selectedAudioMode)
    }

    private func applyUI(for mode: AudioMode) {
        AppLogger.debug("Audio mode selected: mode=\(mode), rememberedVideoFormat=\(selectedVideoFormat), rememberedAudioFormat=\(selectedAudioFormat)")
        if mode == .audioOnly {
            selectedOutputFormat = audioFormats.contains(selectedAudioFormat) ? selectedAudioFormat : .source
        } else {
            selectedOutputFormat = videoFormats.contains(selectedVideoFormat) ? selectedVideoFormat : .source
        }
    }

}

struct DownloadItemRow: View {
    let item: DownloadItem

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(item.titleLine)
                .font(.body)
                .lineLimit(2)
            if let fileName = item.fileName, !fileName.isEmpty {
                Text(fileName)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
    }
}

struct ActivityView: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

struct MailView: UIViewControllerRepresentable {
    let logURL: URL

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIViewController(context: Context) -> MFMailComposeViewController {
        let controller = MFMailComposeViewController()
        controller.mailComposeDelegate = context.coordinator
        controller.setToRecipients([AppConfig.supportEmail])
        controller.setSubject("Universal Downloader logs")
        controller.setMessageBody("Attached are Universal Downloader diagnostic logs.", isHTML: false)
        if let data = try? Data(contentsOf: logURL) {
            controller.addAttachmentData(data, mimeType: "text/plain", fileName: logURL.lastPathComponent)
        }
        return controller
    }

    func updateUIViewController(_ uiViewController: MFMailComposeViewController, context: Context) {}

    final class Coordinator: NSObject, MFMailComposeViewControllerDelegate {
        func mailComposeController(
            _ controller: MFMailComposeViewController,
            didFinishWith result: MFMailComposeResult,
            error: Error?
        ) {
            if let error {
                AppLogger.error("Mail compose failed", error: error)
            } else {
                AppLogger.info("Mail compose finished: result=\(result.rawValue)")
            }
            controller.dismiss(animated: true)
        }
    }
}

enum PresentedShare: Identifiable {
    case activity(URL)
    case mail(URL)

    var id: String {
        switch self {
        case .activity(let url): "activity-\(url.path)"
        case .mail(let url): "mail-\(url.path)"
        }
    }
}

private extension DownloadItem {
    var titleLine: String {
        let totalLabel = total.map { "/\($0)" } ?? ""
        let statusLabel: String
        switch status {
        case .running: statusLabel = "\(progress)%"
        case .finished: statusLabel = "Done"
        }
        return "\(index)\(totalLabel)  \(statusLabel)  \(title)"
    }
}

private extension DownloadViewModel {
    var statusSymbol: String {
        switch statusTitle {
        case "Downloading":
            "arrow.down.circle.fill"
        case "Saved":
            "checkmark.circle.fill"
        case "Stopped":
            "pause.circle.fill"
        case "Couldn’t download":
            "exclamationmark.triangle.fill"
        default:
            "tray.and.arrow.down.fill"
        }
    }

    var statusTint: Color {
        switch statusTitle {
        case "Downloading":
            .accentColor
        case "Saved":
            .green
        case "Stopped":
            .orange
        case "Couldn’t download":
            .red
        default:
            .secondary
        }
    }
}

private extension String {
    func redactedURLSummary() -> String {
        if isEmpty { return "blank" }
        let host = URL(string: self)?.host ?? "unknown"
        return "length=\(count), host=\(host)"
    }
}
