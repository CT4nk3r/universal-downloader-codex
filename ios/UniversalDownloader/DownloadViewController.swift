import MessageUI
import SwiftUI
import UIKit

final class DownloadViewController: UIHostingController<DownloadScreen> {
    private let viewModel: DownloadViewModel

    init() {
        let viewModel = DownloadViewModel()
        self.viewModel = viewModel
        super.init(rootView: DownloadScreen(viewModel: viewModel))
        view.backgroundColor = .clear
    }

    @MainActor required dynamic init?(coder aDecoder: NSCoder) {
        let viewModel = DownloadViewModel()
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
}

struct DownloadScreen: View {
    @ObservedObject var viewModel: DownloadViewModel

    private let columns = [
        GridItem(.adaptive(minimum: 68), spacing: 7)
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                topBar
                subtitle
                urlField
                primaryActions
                if viewModel.optionsOpen {
                    optionsPanel
                }
                if viewModel.progressVisible {
                    ProgressView(value: viewModel.progress, total: 100)
                        .tint(.appGreen)
                        .padding(.vertical, 2)
                        .accessibilityIdentifier("download.progress")
                }
                statusPanel
                playlistPanel
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 22)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(Color.appBackground.ignoresSafeArea())
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
    }

    private var topBar: some View {
        HStack(spacing: 12) {
            Text("Universal Downloader")
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(Color.primaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.78)
                .accessibilityIdentifier("download.title")
            Spacer(minLength: 8)
            Button {
                viewModel.showingAbout = true
            } label: {
                Image(systemName: "info.circle")
                    .font(.system(size: 19, weight: .semibold))
                    .frame(width: 36, height: 36)
            }
            .buttonStyle(PlainIconButtonStyle())
            .accessibilityLabel("About")
        }
        .padding(.top, 4)
        .padding(.bottom, 2)
    }

    private var subtitle: some View {
        Text("Paste a link or share one into the app.")
            .font(.system(size: 13))
            .foregroundStyle(Color.secondaryText)
    }

    private var urlField: some View {
        TextField("Video link", text: $viewModel.urlText)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .keyboardType(.URL)
            .submitLabel(.done)
            .accessibilityIdentifier("download.urlField")
            .font(.system(size: 16))
            .padding(.horizontal, 12)
            .frame(minHeight: 44)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Color.softBorder, lineWidth: 1)
            )
            .onChange(of: viewModel.urlText) { newValue in
                viewModel.urlChanged(newValue)
            }
    }

    private var downloadButton: some View {
        Button {
            viewModel.downloadTapped()
        } label: {
            Text("Download")
                .font(.system(size: 15, weight: .semibold))
                .frame(maxWidth: .infinity, minHeight: 44)
        }
        .buttonStyle(FilledButtonStyle())
        .accessibilityIdentifier("download.primaryButton")
    }

    private var primaryActions: some View {
        HStack(spacing: 10) {
            downloadButton
            optionsToggle
        }
    }

    private var optionsToggle: some View {
        Button {
            withAnimation(.snappy) {
                viewModel.optionsOpen.toggle()
            }
        } label: {
            Label(viewModel.optionsOpen ? "Hide" : "Options", systemImage: viewModel.optionsOpen ? "chevron.up" : "slider.horizontal.3")
                .font(.system(size: 15, weight: .medium))
                .labelStyle(.titleAndIcon)
                .frame(width: 112, height: 44)
        }
        .buttonStyle(OutlineButtonStyle())
        .accessibilityIdentifier("download.optionsToggle")
    }

    private var optionsPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Download options")
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(Color.primaryText)

            optionSection("Format") {
                LazyVGrid(columns: columns, spacing: 8) {
                    ForEach(viewModel.availableFormats, id: \.self) { format in
                        OptionChip(
                            title: format.rawValue,
                            isSelected: viewModel.selectedOutputFormat == format
                        ) {
                            viewModel.select(format: format)
                        }
                    }
                }
            }

            optionSection(viewModel.selectedAudioMode == .audioOnly ? "Audio quality" : "Video quality") {
                LazyVGrid(columns: columns, spacing: 8) {
                    if viewModel.selectedAudioMode == .audioOnly {
                        ForEach(AudioQuality.allCases, id: \.self) { quality in
                            OptionChip(
                                title: quality.rawValue,
                                isSelected: viewModel.selectedAudioQuality == quality
                            ) {
                                viewModel.selectedAudioQuality = quality
                            }
                        }
                    } else {
                        ForEach(VideoQuality.allCases, id: \.self) { quality in
                            OptionChip(
                                title: quality.rawValue,
                                isSelected: viewModel.selectedQuality == quality
                            ) {
                                viewModel.selectedQuality = quality
                            }
                        }
                    }
                }
            }

            optionSection("Audio") {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 96), spacing: 7)], spacing: 7) {
                    ForEach(AudioMode.allCases, id: \.self) { mode in
                        OptionChip(
                            title: mode.rawValue,
                            isSelected: viewModel.selectedAudioMode == mode
                        ) {
                            viewModel.select(audioMode: mode)
                        }
                    }
                }
            }
        }
        .cardStyle(cornerRadius: 14, padding: 12)
    }

    private func optionSection<Content: View>(
        _ title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(Color.secondaryText)
            content()
        }
    }

    @ViewBuilder private var statusPanel: some View {
        if viewModel.statusVisible {
            VStack(alignment: .leading, spacing: 5) {
                Text(viewModel.statusTitle)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(Color.primaryText)
                    .accessibilityIdentifier("download.statusTitle")
                Text(viewModel.statusSubtitle)
                    .font(.system(size: 14))
                    .foregroundStyle(Color.secondaryText)
                    .lineLimit(3)
                    .accessibilityIdentifier("download.statusSubtitle")
                if viewModel.stopVisible {
                    Button {
                        viewModel.stopDownload()
                    } label: {
                        Text("Stop")
                            .font(.system(size: 15, weight: .medium))
                            .frame(maxWidth: .infinity, minHeight: 42)
                    }
                    .buttonStyle(StopButtonStyle())
                    .padding(.top, 8)
                    .accessibilityIdentifier("download.stopButton")
                }
            }
            .cardStyle(cornerRadius: 14, padding: 12)
        }
    }

    @ViewBuilder private var playlistPanel: some View {
        if !viewModel.items.isEmpty {
            VStack(alignment: .leading, spacing: 9) {
                Text("Playlist progress")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(Color.secondaryText)

                ForEach(viewModel.activeItems, id: \.index) { item in
                    DownloadItemRow(item: item)
                }

                if !viewModel.finishedItems.isEmpty {
                    Text("Downloaded")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(Color.secondaryText)
                        .padding(.top, 4)
                }

                ForEach(viewModel.finishedItems, id: \.index) { item in
                    DownloadItemRow(item: item)
                }
            }
            .cardStyle(cornerRadius: 14, padding: 12)
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

    private let downloader = YTDLPClient()
    private let store = SharedLinkStore()
    private var downloadTask: Task<Void, Never>?

    private let videoFormats: [OutputFormat] = [.source, .mp4, .mov, .mkv, .webm]
    private let audioFormats: [OutputFormat] = [.source, .mp3, .wav, .ogg, .m4a]

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
        case .finished(let fileName):
            progressVisible = false
            stopVisible = false
            setStatus(title: "Saved", subtitle: fileName, visible: true)
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

struct OptionChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 13, weight: .medium))
                .lineLimit(1)
                .minimumScaleFactor(0.85)
                .frame(maxWidth: .infinity)
                .frame(height: 34)
        }
        .buttonStyle(ChipButtonStyle(isSelected: isSelected))
        .accessibilityIdentifier("optionChip.\(title)")
    }
}

struct DownloadItemRow: View {
    let item: DownloadItem

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(item.titleLine)
                .font(.system(size: 15))
                .foregroundStyle(Color.primaryText)
                .lineLimit(2)
            if let fileName = item.fileName, !fileName.isEmpty {
                Text(fileName)
                    .font(.system(size: 13))
                    .foregroundStyle(Color.secondaryText)
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

private extension View {
    func cardStyle(cornerRadius: CGFloat, padding: CGFloat) -> some View {
        self
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(Color.softBorder, lineWidth: 1)
            )
    }
}

private struct FilledButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(Color.white)
            .background(Color.appGreen.opacity(configuration.isPressed ? 0.78 : 1))
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

private struct OutlineButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(Color.appGreen)
            .background(Color.white.opacity(configuration.isPressed ? 0.65 : 1))
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(Color.outlineStrong, lineWidth: 2)
            )
    }
}

private struct StopButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(Color.stopRed)
            .background(Color.white.opacity(configuration.isPressed ? 0.65 : 1))
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(Color.outlineStrong, lineWidth: 2)
            )
    }
}

private struct PlainIconButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(Color.appGreen)
            .background(Color.white.opacity(configuration.isPressed ? 0.65 : 1))
            .clipShape(Circle())
            .overlay(Circle().stroke(Color.softBorder, lineWidth: 1))
    }
}

private struct ChipButtonStyle: ButtonStyle {
    let isSelected: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(isSelected ? Color.appGreen : Color.primaryText)
            .background(isSelected ? Color.selectedFill : Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(Color.outlineStrong, lineWidth: isSelected ? 2 : 1)
            )
            .opacity(configuration.isPressed ? 0.75 : 1)
    }
}

private extension Color {
    static let appBackground = Color(red: 0.973, green: 0.980, blue: 0.969)
    static let appGreen = Color(red: 0.129, green: 0.424, blue: 0.369)
    static let primaryText = Color(red: 0.090, green: 0.125, blue: 0.114)
    static let secondaryText = Color(red: 0.345, green: 0.388, blue: 0.373)
    static let outlineStrong = Color(red: 0.612, green: 0.659, blue: 0.635)
    static let softBorder = Color(red: 0.882, green: 0.906, blue: 0.890)
    static let selectedFill = Color(red: 0.902, green: 0.949, blue: 0.937)
    static let stopRed = Color(red: 0.608, green: 0.173, blue: 0.173)
}

private extension String {
    func redactedURLSummary() -> String {
        if isEmpty { return "blank" }
        let host = URL(string: self)?.host ?? "unknown"
        return "length=\(count), host=\(host)"
    }
}
