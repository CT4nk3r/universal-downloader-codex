import MessageUI
import QuickLook
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
            Text("Version 0.x\n\nDiagnostics can help debug playlist, format, and download issues. Logs redact pasted links to host and length only.")
        }
        .sheet(item: $viewModel.presentedShare) { share in
            switch share {
            case .activity(let url):
                ActivityView(items: [url])
            case .mail(let url):
                MailView(logURL: url)
            }
        }
        .sheet(item: $viewModel.presentedPreview) { preview in
            QuickLookPreview(url: preview.url)
        }
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
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                viewModel.downloadTapped()
            } label: {
                Label("Download", systemImage: "arrow.down.circle.fill")
                .font(.body.weight(.semibold))
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(DownloadPrimaryButtonStyle())
            .contentShape(Rectangle())
            .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
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
                .pickerStyle(.segmented)
            } else {
                Picker("Video Quality", selection: $viewModel.selectedQuality) {
                    ForEach(VideoQuality.allCases, id: \.self) { quality in
                        Text(quality.rawValue).tag(quality)
                    }
                }
                .pickerStyle(.segmented)
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
                ForEach(viewModel.activeItems, id: \.identity, content: ActiveDownloadItemRow.init)
            }
        }
    }

    @ViewBuilder private var finishedPlaylistSection: some View {
        if !viewModel.finishedItems.isEmpty {
            Section("Downloaded") {
                ForEach(viewModel.finishedItems, id: \.identity) { item in
                    Button {
                        viewModel.preview(item)
                    } label: {
                        DownloadedItemRow(item: item)
                    }
                    .buttonStyle(.plain)
                    .contentShape(Rectangle())
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        Button(role: .destructive) {
                            viewModel.delete(item)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }

                        Button {
                            viewModel.share(item)
                        } label: {
                            Label("Share", systemImage: "square.and.arrow.up")
                        }
                        .tint(.blue)
                    }
                }
            }
        }
    }
}

@MainActor
final class DownloadViewModel: ObservableObject {
    @Published var urlText = ""
    @Published var optionsOpen = true
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
    @Published var presentedPreview: PresentedPreview?

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

    func preview(_ item: DownloadItem) {
        guard let url = existingFileURL(for: item) else {
            AppLogger.warning("Preview requested for missing file: \(item.fileName ?? "unknown")")
            setStatus(title: "File unavailable", subtitle: "The downloaded file is no longer in the app's Downloads folder.", visible: true)
            return
        }

        presentedPreview = PresentedPreview(url: url)
    }

    func share(_ item: DownloadItem) {
        guard let url = existingFileURL(for: item) else {
            AppLogger.warning("Share requested for missing file: \(item.fileName ?? "unknown")")
            setStatus(title: "File unavailable", subtitle: "The downloaded file is no longer in the app's Downloads folder.", visible: true)
            return
        }

        presentedShare = .activity(url)
    }

    func delete(_ item: DownloadItem) {
        guard let url = fileURL(for: item) else { return }

        do {
            try DownloadFileStore.delete(url)
            items.removeAll { $0.identity == item.identity }
            AppLogger.info("Deleted downloaded file: \(url.lastPathComponent)")
            setStatus(title: "Deleted", subtitle: url.lastPathComponent, visible: true)
        } catch {
            AppLogger.error("Failed to delete downloaded file", error: error)
            setStatus(title: "Couldn’t delete", subtitle: error.localizedDescription, visible: true)
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
            markFileSaved(fileName: fileName, title: title)
            progressVisible = false
            stopVisible = false
            let fileURL = DownloadFileStore.fileURL(named: fileName)
            let subtitle = title.map { "\($0)\n\(DownloadFileStore.displayPath(for: fileURL))" } ?? DownloadFileStore.displayPath(for: fileURL)
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

    private func markFileSaved(fileName: String, title: String?) {
        let fileURL = DownloadFileStore.fileURL(named: fileName)
        if let index = items.lastIndex(where: { item in
            item.fileName == fileName || title.map { item.title == $0 } == true
        }) {
            items[index].fileName = fileName
            items[index].fileURL = fileURL
            items[index].progress = 100
            items[index].status = .finished
        } else {
            let nextIndex = (items.map(\.index).max() ?? 0) + 1
            items.append(
                DownloadItem(
                    index: nextIndex,
                    total: nil,
                    title: title ?? fileName,
                    fileName: fileName,
                    fileURL: fileURL,
                    progress: 100,
                    status: .finished
                )
            )
        }
    }

    private func existingFileURL(for item: DownloadItem) -> URL? {
        guard let url = fileURL(for: item),
              FileManager.default.fileExists(atPath: url.path)
        else {
            return nil
        }
        return url
    }

    private func fileURL(for item: DownloadItem) -> URL? {
        if let fileURL = item.fileURL {
            return fileURL
        }

        return item.fileName.map(DownloadFileStore.fileURL(named:))
    }

}

struct ActiveDownloadItemRow: View {
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

struct DownloadedItemRow: View {
    let item: DownloadItem

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "doc.fill")
                .font(.title3)
                .foregroundStyle(Color.accentColor)
                .frame(width: 24)
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: 4) {
                Text(item.title)
                    .font(.body.weight(.medium))
                    .foregroundStyle(.primary)
                    .lineLimit(2)

                if let fileName = item.fileName, !fileName.isEmpty {
                    Text(fileName)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                if let fileURL = item.fileURL {
                    Text(DownloadFileStore.displayPath(for: fileURL))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }

            Spacer(minLength: 8)

            Image(systemName: "chevron.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.tertiary)
                .padding(.top, 5)
        }
        .padding(.vertical, 5)
    }
}

struct DownloadPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .frame(maxWidth: .infinity, minHeight: 42)
            .background {
                Capsule()
                    .fill(Color.accentColor.opacity(configuration.isPressed ? 0.18 : 0.10))
            }
            .overlay {
                Capsule()
                    .stroke(Color.accentColor.opacity(configuration.isPressed ? 0.36 : 0.24), lineWidth: 1)
            }
            .foregroundStyle(.tint)
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .animation(.spring(response: 0.18, dampingFraction: 0.72), value: configuration.isPressed)
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

struct PresentedPreview: Identifiable {
    let url: URL

    var id: String {
        url.path
    }
}

struct QuickLookPreview: UIViewControllerRepresentable {
    let url: URL

    func makeCoordinator() -> Coordinator {
        Coordinator(url: url)
    }

    func makeUIViewController(context: Context) -> QLPreviewController {
        let controller = QLPreviewController()
        controller.dataSource = context.coordinator
        return controller
    }

    func updateUIViewController(_ uiViewController: QLPreviewController, context: Context) {
        context.coordinator.url = url
        uiViewController.reloadData()
    }

    final class Coordinator: NSObject, QLPreviewControllerDataSource {
        var url: URL

        init(url: URL) {
            self.url = url
        }

        func numberOfPreviewItems(in controller: QLPreviewController) -> Int {
            1
        }

        func previewController(_ controller: QLPreviewController, previewItemAt index: Int) -> QLPreviewItem {
            url as NSURL
        }
    }
}

private extension DownloadItem {
    var identity: String {
        "\(index)-\(fileName ?? title)-\(total ?? 0)"
    }

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
        case "Deleted":
            "trash.circle.fill"
        case "File unavailable", "Couldn’t delete":
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
        case "Deleted":
            .secondary
        case "File unavailable", "Couldn’t delete":
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
