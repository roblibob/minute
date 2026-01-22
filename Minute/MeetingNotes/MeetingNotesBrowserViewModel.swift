import AppKit
import AVFoundation
import Combine
import Foundation
import MinuteCore

@MainActor
final class MeetingNotesBrowserViewModel: ObservableObject {
    struct NotePreview: Equatable {
        var summaryLine: String
        var durationSeconds: TimeInterval?
    }

    @Published private(set) var notes: [MeetingNoteItem] = []
    @Published private(set) var isRefreshing: Bool = false
    @Published private(set) var sidebarErrorMessage: String?
    @Published private(set) var notePreviews: [String: NotePreview] = [:]

    @Published private(set) var isLoadingContent: Bool = false
    @Published private(set) var noteContent: String?
    @Published private(set) var overlayErrorMessage: String?
    @Published private(set) var renderPlainText: Bool = false
    @Published private(set) var selectedItem: MeetingNoteItem?
    @Published var isOverlayPresented: Bool = false

    private let browserProvider: @Sendable () -> any MeetingNotesBrowsing
    private var listTask: Task<Void, Never>?
    private var loadTask: Task<Void, Never>?
    private var deleteTask: Task<Void, Never>?
    private var previewTask: Task<Void, Never>?
    private var defaultsObserver: AnyCancellable?

    init(browserProvider: @escaping @Sendable () -> any MeetingNotesBrowsing = MeetingNotesBrowserViewModel.defaultBrowserProvider) {
        self.browserProvider = browserProvider

        defaultsObserver = NotificationCenter.default.publisher(for: UserDefaults.didChangeNotification)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.refresh()
            }
    }

    deinit {
        listTask?.cancel()
        loadTask?.cancel()
        deleteTask?.cancel()
        previewTask?.cancel()
    }

    func refresh() {
        listTask?.cancel()
        sidebarErrorMessage = nil
        isRefreshing = true

        let provider = browserProvider
        listTask = Task { [weak self] in
            do {
                let notes = try await provider().listNotes()
                await MainActor.run {
                    self?.notes = notes
                    self?.isRefreshing = false
                    self?.refreshPreviews(for: notes)
                }
            } catch is CancellationError {
                await MainActor.run {
                    self?.isRefreshing = false
                }
            } catch {
                let message = ErrorHandler.userMessage(for: error, fallback: "Failed to load notes.")
                await MainActor.run {
                    self?.notes = []
                    self?.sidebarErrorMessage = message
                    self?.isRefreshing = false
                    self?.notePreviews = [:]
                }
            }
        }
    }

    func select(_ item: MeetingNoteItem) {
        loadTask?.cancel()
        selectedItem = item
        noteContent = nil
        overlayErrorMessage = nil
        renderPlainText = false
        isLoadingContent = true
        isOverlayPresented = true

        let provider = browserProvider
        loadTask = Task { [weak self] in
            do {
                let content = try await provider().loadNoteContent(for: item)
                let shouldRenderPlainText = Self.shouldRenderPlainText(content)

                await MainActor.run {
                    self?.noteContent = content
                    self?.renderPlainText = shouldRenderPlainText
                    self?.isLoadingContent = false
                }
            } catch is CancellationError {
                await MainActor.run {
                    self?.isLoadingContent = false
                }
            } catch {
                let message = ErrorHandler.userMessage(for: error, fallback: "Failed to load note.")
                await MainActor.run {
                    self?.overlayErrorMessage = message
                    self?.isLoadingContent = false
                }
            }
        }
    }

    func retryLoadContent() {
        guard let item = selectedItem else { return }
        select(item)
    }

    func dismissOverlay() {
        loadTask?.cancel()
        isOverlayPresented = false
        selectedItem = nil
        noteContent = nil
        overlayErrorMessage = nil
        renderPlainText = false
        isLoadingContent = false
    }

    func preview(for item: MeetingNoteItem) -> NotePreview? {
        notePreviews[item.id]
    }

    func delete(_ item: MeetingNoteItem) {
        deleteTask?.cancel()
        sidebarErrorMessage = nil

        let provider = browserProvider
        deleteTask = Task { [weak self] in
            do {
                try await provider().deleteNoteFiles(for: item)
                await MainActor.run { [weak self] in
                    guard let self else { return }
                    if self.selectedItem?.id == item.id {
                        self.dismissOverlay()
                    }
                    self.refresh()
                    self.notePreviews[item.id] = nil
                }
            } catch is CancellationError {
                return
            } catch {
                let message = ErrorHandler.userMessage(for: error, fallback: "Failed to delete note.")
                await MainActor.run { [weak self] in
                    self?.sidebarErrorMessage = message
                }
            }
        }
    }

    func openInObsidian() {
        guard let fileURL = selectedItem?.fileURL else { return }
        let path = fileURL.path
        var allowed = CharacterSet.urlQueryAllowed
        allowed.remove(charactersIn: "&+")
        guard let encoded = path.addingPercentEncoding(withAllowedCharacters: allowed),
              let obsidianURL = URL(string: "obsidian://open?path=\(encoded)") else {
            return
        }
        _ = NSWorkspace.shared.open(obsidianURL)
    }

    nonisolated private static func defaultBrowserProvider() -> any MeetingNotesBrowsing {
        let defaults = UserDefaults.standard
        let configuration = AppConfiguration(defaults: defaults)
        let bookmarkStore = UserDefaultsVaultBookmarkStore(
            defaults: defaults,
            key: AppConfiguration.Defaults.vaultRootBookmarkKey
        )
        let access = VaultAccess(bookmarkStore: bookmarkStore)
        return VaultMeetingNotesBrowser(
            vaultAccess: access,
            meetingsRelativePath: configuration.meetingsRelativePath,
            audioRelativePath: configuration.audioRelativePath,
            transcriptsRelativePath: configuration.transcriptsRelativePath
        )
    }

    private static func shouldRenderPlainText(_ content: String) -> Bool {
        do {
            _ = try AttributedString(markdown: content)
            return false
        } catch {
            return true
        }
    }

    private func refreshPreviews(for notes: [MeetingNoteItem]) {
        previewTask?.cancel()

        let configuration = AppConfiguration(defaults: UserDefaults.standard)
        let provider = browserProvider
        let vaultAccess = Self.makeVaultAccess()
        previewTask = Task.detached { [notes, configuration, provider, vaultAccess] in
            var previews: [String: NotePreview] = [:]
            previews.reserveCapacity(notes.count)

            let browser = provider()
            for item in notes {
                if Task.isCancelled { return }
                let summaryLine = await Self.loadSummaryLine(for: item, browser: browser)
                let durationSeconds = Self.loadDurationSeconds(
                    for: item,
                    configuration: configuration,
                    vaultAccess: vaultAccess
                )
                previews[item.id] = NotePreview(summaryLine: summaryLine, durationSeconds: durationSeconds)
            }

            await MainActor.run { [weak self] in
                self?.notePreviews = previews
            }
        }
    }

    nonisolated private static let summaryPreviewWordCount = 18

    nonisolated private static func loadSummaryLine(
        for item: MeetingNoteItem,
        browser: any MeetingNotesBrowsing
    ) async -> String {
        guard let content = try? await browser.loadNoteContent(for: item) else {
            return "No summary yet."
        }
        let summary = extractSummaryPreview(from: content)
        return summary.isEmpty ? "No summary yet." : summary
    }

    nonisolated private static func extractSummaryPreview(from content: String) -> String {
        let lines = content.split(separator: "\n", omittingEmptySubsequences: false)
        guard let summaryIndex = lines.firstIndex(where: { $0.trimmingCharacters(in: .whitespacesAndNewlines) == "## Summary" }) else {
            return ""
        }

        var summaryLines: [String] = []
        var index = summaryIndex + 1
        while index < lines.count {
            let line = lines[index].trimmingCharacters(in: .whitespacesAndNewlines)
            if line.hasPrefix("## ") {
                break
            }
            if !line.isEmpty {
                summaryLines.append(line)
            }
            index += 1
        }

        guard !summaryLines.isEmpty else { return "" }
        let summaryText = summaryLines.joined(separator: " ")
        let words = summaryText.split(whereSeparator: { $0.isWhitespace })
        guard !words.isEmpty else { return "" }

        let previewCount = min(words.count, summaryPreviewWordCount)
        let preview = words.prefix(previewCount).joined(separator: " ")
        if words.count > previewCount {
            return "\(preview)..."
        }
        return preview
    }

    nonisolated private static func loadDurationSeconds(
        for item: MeetingNoteItem,
        configuration: AppConfiguration,
        vaultAccess: VaultAccess
    ) -> TimeInterval? {
        let duration = try? vaultAccess.withVaultAccess { vaultRootURL -> TimeInterval? in
            let audioURL = audioFileURL(
                for: item,
                audioRelativePath: configuration.audioRelativePath,
                vaultRootURL: vaultRootURL
            )
            guard FileManager.default.fileExists(atPath: audioURL.path) else { return nil }
            guard let file = try? AVAudioFile(forReading: audioURL) else { return nil }
            let format = file.fileFormat
            guard format.sampleRate > 0 else { return nil }
            return TimeInterval(Double(file.length) / format.sampleRate)
        }
        return duration ?? nil
    }

    nonisolated private static func audioFileURL(
        for item: MeetingNoteItem,
        audioRelativePath: String,
        vaultRootURL: URL
    ) -> URL {
        vaultRootURL
            .appendingPathComponent(audioRelativePath)
            .appendingPathComponent("\(item.fileURL.deletingPathExtension().lastPathComponent).wav")
    }

    nonisolated private static func makeVaultAccess() -> VaultAccess {
        let defaults = UserDefaults.standard
        let bookmarkStore = UserDefaultsVaultBookmarkStore(
            defaults: defaults,
            key: AppConfiguration.Defaults.vaultRootBookmarkKey
        )
        return VaultAccess(bookmarkStore: bookmarkStore)
    }
}
