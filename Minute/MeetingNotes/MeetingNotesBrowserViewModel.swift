import AppKit
import Combine
import Foundation
import MinuteCore

enum MeetingNotePreviewTab: String, CaseIterable, Identifiable {
    case summary
    case transcription

    var id: String { rawValue }

    var title: String {
        switch self {
        case .summary:
            return "Summary"
        case .transcription:
            return "Transcription"
        }
    }
}

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
    @Published private(set) var isLoadingTranscript: Bool = false
    @Published private(set) var transcriptContent: String?
    @Published private(set) var transcriptErrorMessage: String?
    @Published private(set) var renderTranscriptPlainText: Bool = false
    @Published private(set) var selectedItem: MeetingNoteItem?
    @Published private(set) var selectedTab: MeetingNotePreviewTab = .summary
    @Published var isOverlayPresented: Bool = false

    private let browserProvider: @Sendable () -> any MeetingNotesBrowsing
    private var pendingSelectionURL: URL?
    private var listTask: Task<Void, Never>?
    private var loadTask: Task<Void, Never>?
    private var transcriptLoadTask: Task<Void, Never>?
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
        transcriptLoadTask?.cancel()
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
                    self?.applyPendingSelection(from: notes)
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
        selectedItem = item
        selectedTab = .summary
        resetTranscriptState()
        isOverlayPresented = true
        startLoadingSummary(for: item)
    }

    func retryLoadContent() {
        guard let item = selectedItem else { return }
        startLoadingSummary(for: item)
    }

    func retryLoadTranscript() {
        guard let item = selectedItem else { return }
        startLoadingTranscript(for: item, force: true)
    }

    func retryLoadContent(for tab: MeetingNotePreviewTab) {
        switch tab {
        case .summary:
            retryLoadContent()
        case .transcription:
            retryLoadTranscript()
        }
    }

    func selectTab(_ tab: MeetingNotePreviewTab) {
        guard selectedTab != tab else { return }
        selectedTab = tab
        if tab == .transcription {
            loadTranscriptIfNeeded()
        }
    }

    func dismissOverlay() {
        loadTask?.cancel()
        transcriptLoadTask?.cancel()
        isOverlayPresented = false
        selectedItem = nil
        selectedTab = .summary
        noteContent = nil
        overlayErrorMessage = nil
        renderPlainText = false
        isLoadingContent = false
        resetTranscriptState()
    }

    func preview(for item: MeetingNoteItem) -> NotePreview? {
        notePreviews[item.id]
    }

    func refreshAndSelect(noteURL: URL) {
        pendingSelectionURL = noteURL
        refresh()
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

    private func startLoadingSummary(for item: MeetingNoteItem) {
        loadTask?.cancel()
        noteContent = nil
        overlayErrorMessage = nil
        renderPlainText = false
        isLoadingContent = true

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

    private func loadTranscriptIfNeeded() {
        guard let item = selectedItem else { return }
        guard item.hasTranscript else { return }
        guard transcriptContent == nil, transcriptErrorMessage == nil, !isLoadingTranscript else { return }
        startLoadingTranscript(for: item, force: false)
    }

    private func startLoadingTranscript(for item: MeetingNoteItem, force: Bool) {
        if !force {
            guard transcriptContent == nil, transcriptErrorMessage == nil, !isLoadingTranscript else { return }
        }

        transcriptLoadTask?.cancel()
        transcriptContent = nil
        transcriptErrorMessage = nil
        renderTranscriptPlainText = false
        isLoadingTranscript = true

        let provider = browserProvider
        transcriptLoadTask = Task { [weak self] in
            do {
                let content = try await provider().loadTranscriptContent(for: item)
                let shouldRenderPlainText = Self.shouldRenderPlainText(content)

                await MainActor.run {
                    self?.transcriptContent = content
                    self?.renderTranscriptPlainText = shouldRenderPlainText
                    self?.isLoadingTranscript = false
                }
            } catch is CancellationError {
                await MainActor.run {
                    self?.isLoadingTranscript = false
                }
            } catch {
                let message = Self.transcriptErrorMessage(for: error)
                await MainActor.run {
                    self?.transcriptErrorMessage = message
                    self?.isLoadingTranscript = false
                }
            }
        }
    }

    private func resetTranscriptState() {
        transcriptLoadTask?.cancel()
        transcriptContent = nil
        transcriptErrorMessage = nil
        renderTranscriptPlainText = false
        isLoadingTranscript = false
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

    private static func transcriptErrorMessage(for error: Error) -> String {
        let nsError = error as NSError
        if nsError.domain == NSCocoaErrorDomain, nsError.code == NSFileReadNoSuchFileError {
            return "Transcript not available."
        }
        return ErrorHandler.userMessage(for: error, fallback: "Failed to load transcript.")
    }

    private func refreshPreviews(for notes: [MeetingNoteItem]) {
        previewTask?.cancel()

        let provider = browserProvider
        previewTask = Task.detached { [notes, provider] in
            let browser = provider()
            let previews = await Self.buildPreviews(for: notes, browser: browser)
            await MainActor.run { [weak self] in
                self?.notePreviews = previews
            }
        }
    }

    nonisolated private static let summaryPreviewWordCount = 18

    nonisolated private static func buildPreviews(
        for notes: [MeetingNoteItem],
        browser: any MeetingNotesBrowsing
    ) async -> [String: NotePreview] {
        var previews: [String: NotePreview] = [:]
        previews.reserveCapacity(notes.count)

        for item in notes {
            if Task.isCancelled { return previews }
            let preview = await loadPreview(for: item, browser: browser)
            previews[item.id] = preview
        }
        return previews
    }

    nonisolated private static func loadPreview(
        for item: MeetingNoteItem,
        browser: any MeetingNotesBrowsing
    ) async -> NotePreview {
        guard let content = try? await browser.loadNoteContent(for: item) else {
            return NotePreview(summaryLine: "No summary yet.", durationSeconds: nil)
        }
        let summary = extractSummaryPreview(from: content)
        let summaryLine = summary.isEmpty ? "No summary yet." : summary
        let durationSeconds = parseLengthSeconds(from: content)
        return NotePreview(summaryLine: summaryLine, durationSeconds: durationSeconds)
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

    nonisolated private static func parseLengthSeconds(from content: String) -> TimeInterval? {
        guard let rawValue = parseFrontmatterValue(named: "length", from: content) else {
            return nil
        }
        return parseDurationSeconds(rawValue)
    }

    nonisolated private static func parseFrontmatterValue(named key: String, from content: String) -> String? {
        let lines = content.split(separator: "\n", omittingEmptySubsequences: false)
        guard let first = lines.first,
              first.trimmingCharacters(in: .whitespacesAndNewlines) == "---" else {
            return nil
        }

        for line in lines.dropFirst() {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed == "---" { break }
            guard let colonIndex = trimmed.firstIndex(of: ":") else { continue }
            let name = trimmed[..<colonIndex].trimmingCharacters(in: .whitespacesAndNewlines)
            guard name == key else { continue }
            let rawValue = trimmed[trimmed.index(after: colonIndex)...]
                .trimmingCharacters(in: .whitespacesAndNewlines)
            return trimMatchingQuotes(String(rawValue))
        }

        return nil
    }

    nonisolated private static func trimMatchingQuotes(_ value: String) -> String {
        guard value.count >= 2,
              let first = value.first,
              let last = value.last,
              (first == "\"" && last == "\"") || (first == "'" && last == "'")
        else {
            return value
        }
        return String(value.dropFirst().dropLast())
    }

    nonisolated private static func parseDurationSeconds(_ value: String) -> TimeInterval? {
        let cleaned = value.lowercased()
        var totalMinutes = 0
        var buffer = ""
        var hasUnit = false

        for character in cleaned {
            if character.isNumber {
                buffer.append(character)
                continue
            }

            if character == "h" || character == "m" {
                guard let number = Int(buffer) else {
                    buffer = ""
                    continue
                }
                if character == "h" {
                    totalMinutes += number * 60
                } else {
                    totalMinutes += number
                }
                buffer = ""
                hasUnit = true
            } else if !buffer.isEmpty {
                buffer = ""
            }
        }

        guard hasUnit, totalMinutes > 0 else { return nil }
        return TimeInterval(totalMinutes * 60)
    }

    private func applyPendingSelection(from notes: [MeetingNoteItem]) {
        guard let pendingSelectionURL else { return }
        let pendingPath = pendingSelectionURL.standardizedFileURL.path
        guard let match = notes.first(where: { $0.fileURL.standardizedFileURL.path == pendingPath }) else { return }
        self.pendingSelectionURL = nil
        select(match)
    }
}
