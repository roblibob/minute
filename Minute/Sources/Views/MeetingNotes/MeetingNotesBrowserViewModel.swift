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
    @Published private(set) var transcriptDisplayContent: String?
    @Published private(set) var transcriptErrorMessage: String?
    @Published private(set) var renderTranscriptPlainText: Bool = false
    @Published private(set) var selectedItem: MeetingNoteItem?
    @Published private(set) var selectedTab: MeetingNotePreviewTab = .summary
    @Published var isOverlayPresented: Bool = false

    // US3: Speaker naming (frontmatter-only persistence).
    @Published private(set) var speakerIDs: [Int] = []
    @Published private(set) var speakerNameDrafts: [Int: String] = [:]
    @Published private(set) var speakerSaveErrorMessage: String?
    @Published private(set) var isSavingSpeakerNames: Bool = false
    @Published private(set) var speakerTranscriptRewriteErrorMessage: String?
    @Published private(set) var isRewritingTranscriptHeadings: Bool = false

    // US4: Known speaker enrollment (explicit user action).
    @Published private(set) var speakerEnrollmentErrorMessage: String?
    @Published private(set) var enrollingSpeakerID: Int?

    // Known-speaker status for speakers in the selected meeting.
    // Key: speaker ID. Value: matched profile (id/name).
    @Published private(set) var knownSpeakerProfileIDBySpeakerID: [Int: String] = [:]
    @Published private(set) var knownSpeakerProfileNameBySpeakerID: [Int: String] = [:]

    // All known speaker profile names (for autocomplete while editing).
    @Published private(set) var knownSpeakerProfileNames: [String] = []
    private var knownSpeakerStatusTask: Task<Void, Never>?

    // Speaker IDs discovered from the transcript file, independent of which tab is currently selected.
    @Published private(set) var transcriptSpeakerIDs: [Int] = []

    private let browserProvider: @Sendable () -> any MeetingNotesBrowsing
    private var pendingSelectionURL: URL?
    private var listTask: Task<Void, Never>?
    private var loadTask: Task<Void, Never>?
    private var transcriptLoadTask: Task<Void, Never>?
    private var transcriptSpeakerIDsTask: Task<Void, Never>?
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
        transcriptSpeakerIDsTask?.cancel()
        deleteTask?.cancel()
        previewTask?.cancel()
        knownSpeakerStatusTask?.cancel()
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
        resetSpeakerNamingState()
        selectedItem = item
        selectedTab = .summary
        resetTranscriptState()
        isOverlayPresented = true
        startLoadingSummary(for: item)

        // Load speaker IDs from the transcript in the background so the Speakers UI is consistent
        // even when the user never switches to the transcript tab.
        startLoadingTranscriptSpeakerIDsIfNeeded(for: item)
    }

    private func resetSpeakerNamingState() {
        speakerIDs = []
        speakerNameDrafts = [:]
        speakerSaveErrorMessage = nil
        isSavingSpeakerNames = false
        speakerTranscriptRewriteErrorMessage = nil
        isRewritingTranscriptHeadings = false
        speakerEnrollmentErrorMessage = nil
        enrollingSpeakerID = nil
        knownSpeakerProfileIDBySpeakerID = [:]
        knownSpeakerProfileNameBySpeakerID = [:]
        knownSpeakerProfileNames = []
        knownSpeakerStatusTask?.cancel()
        knownSpeakerStatusTask = nil
        transcriptSpeakerIDs = []
        transcriptSpeakerIDsTask?.cancel()
        transcriptSpeakerIDsTask = nil
    }

    func isKnownSpeaker(speakerId: Int) -> Bool {
        knownSpeakerProfileIDBySpeakerID[speakerId] != nil
    }

    func knownSpeakerName(speakerId: Int) -> String? {
        knownSpeakerProfileNameBySpeakerID[speakerId]
    }

    func enrollKnownSpeaker(speakerId: Int) {
        guard let item = selectedItem else { return }
        speakerEnrollmentErrorMessage = nil

        let trimmedName = (speakerNameDrafts[speakerId] ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            speakerEnrollmentErrorMessage = "Enter a name for this speaker first."
            return
        }

        enrollingSpeakerID = speakerId
        let meetingKey = item.fileURL.path

        let policy = SpeakerProfileEnrollmentPolicy()
        let service = SpeakerProfileEnrollmentService()

        Task { [weak self] in
            let availability = await policy.availability(meetingKey: meetingKey, speakerID: speakerId)
            switch availability {
            case .available:
                do {
                    let profile = try await service.createProfileFromMeeting(
                        meetingKey: meetingKey,
                        speakerID: speakerId,
                        name: trimmedName
                    )
                    await MainActor.run {
                        self?.enrollingSpeakerID = nil
                        self?.speakerEnrollmentErrorMessage = nil

                        // Immediately reflect enrollment in the UI.
                        self?.knownSpeakerProfileIDBySpeakerID[speakerId] = profile.id
                        self?.knownSpeakerProfileNameBySpeakerID[speakerId] = profile.name
                    }
                } catch {
                    let message = ErrorHandler.userMessage(for: error, fallback: "Failed to save known speaker profile.")
                    await MainActor.run {
                        self?.enrollingSpeakerID = nil
                        self?.speakerEnrollmentErrorMessage = message
                    }
                }
            case .missingMeetingEmbeddings:
                await MainActor.run {
                    self?.enrollingSpeakerID = nil
                    self?.speakerEnrollmentErrorMessage = "Embeddings for this meeting aren’t available. Reprocess the meeting with Known Speaker Suggestions enabled, then try again."
                }
            case .missingSpeakerEmbedding:
                await MainActor.run {
                    self?.enrollingSpeakerID = nil
                    self?.speakerEnrollmentErrorMessage = "Embeddings for this speaker aren’t available. Reprocess the meeting and try again."
                }
            }
        }
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

        resetSpeakerNamingState()
    }

    func speakerName(for speakerId: Int) -> String {
        speakerNameDrafts[speakerId] ?? ""
    }

    func setSpeakerName(_ name: String, for speakerId: Int) {
        speakerNameDrafts[speakerId] = name
        updateTranscriptDisplayContent()
    }

    func saveSpeakerNames() {
        guard let item = selectedItem else { return }
        speakerSaveErrorMessage = nil
        speakerTranscriptRewriteErrorMessage = nil
        isSavingSpeakerNames = true

        // Capture the current persisted mapping before we write updates.
        // This allows the transcript heading rewriter to update headings that were previously renamed
        // (e.g., "Alice [..]" -> "Bob [..]") in the same explicit user action.
        let priorOwned = MeetingSpeakerNamingService(vaultWriter: DefaultVaultWriter())
            .loadOwnedParticipantFrontmatter(from: noteContent ?? "")
        let priorSpeakerDisplayNames = priorOwned.speakerMap

        // Build deterministic owned frontmatter from current drafts.
        let orderedSpeakerIDs = speakerIDs

        var speakerMap: [Int: String] = [:]
        speakerMap.reserveCapacity(orderedSpeakerIDs.count)
        for id in orderedSpeakerIDs {
            let trimmed = (speakerNameDrafts[id] ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                speakerMap[id] = trimmed
            }
        }

        var participants: [String] = []
        var seenParticipants: Set<String> = []
        for id in orderedSpeakerIDs {
            guard let name = speakerMap[id] else { continue }
            let key = name.lowercased()
            if seenParticipants.insert(key).inserted {
                participants.append(name)
            }
        }

        let owned = MeetingParticipantFrontmatter(
            participants: participants,
            speakerMap: speakerMap,
            speakerOrder: orderedSpeakerIDs
        )

        let access = Self.makeVaultAccess()
        let service = MeetingSpeakerNamingService(vaultWriter: DefaultVaultWriter())

        Task { [weak self] in
            do {
                try access.withVaultAccess { _ in
                    try service.updateMeetingNote(at: item.fileURL, ownedFrontmatter: owned)
                }

                await MainActor.run {
                    self?.isSavingSpeakerNames = false
                }

                await MainActor.run {
                    // Refresh visible content so the user sees updated frontmatter immediately.
                    self?.startLoadingSummary(for: item)
                }

                // As part of the same explicit user action, also rewrite transcript headings (if present)
                // so the transcript file itself reflects the chosen speaker names.
                if item.hasTranscript {
                    await MainActor.run {
                        self?.rewriteTranscriptHeadings(priorSpeakerDisplayNames: priorSpeakerDisplayNames)
                    }
                }
            } catch is CancellationError {
                await MainActor.run {
                    self?.isSavingSpeakerNames = false
                }
            } catch {
                let message = ErrorHandler.userMessage(for: error, fallback: "Failed to save speakers.")
                await MainActor.run {
                    self?.speakerSaveErrorMessage = message
                    self?.isSavingSpeakerNames = false
                }
            }
        }
    }

    func rewriteTranscriptHeadings(priorSpeakerDisplayNames: [Int: String] = [:]) {
        guard let item = selectedItem else { return }
        guard item.hasTranscript else { return }

        speakerTranscriptRewriteErrorMessage = nil
        isRewritingTranscriptHeadings = true

        let speakerDisplayNames: [Int: String] = speakerNameDrafts.compactMapValues {
            let trimmed = $0.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : trimmed
        }

        let access = Self.makeVaultAccess()
        let defaults = UserDefaults.standard
        let configuration = AppConfiguration(defaults: defaults)
        let vaultWriter = DefaultVaultWriter()

        Task { [weak self] in
            do {
                try Task.checkCancellation()
                let rewritten: String = try access.withVaultAccess { vaultRootURL in
                    try Task.checkCancellation()

                    let transcriptURL = Self.transcriptURL(
                        for: item,
                        vaultRootURL: vaultRootURL,
                        transcriptsRelativePath: configuration.transcriptsRelativePath
                    )

                    let data = try Data(contentsOf: transcriptURL)
                    let content = String(data: data, encoding: .utf8) ?? String(decoding: data, as: UTF8.self)
                    let output = TranscriptSpeakerHeadingRewriter.rewrite(
                        transcriptMarkdown: content,
                        speakerDisplayNames: speakerDisplayNames,
                        priorSpeakerDisplayNames: priorSpeakerDisplayNames
                    )

                    if output != content {
                        let outData = Data(output.utf8)
                        try vaultWriter.writeAtomically(data: outData, to: transcriptURL)
                    }

                    return output
                }

                await MainActor.run {
                    self?.transcriptContent = rewritten
                    self?.renderTranscriptPlainText = Self.shouldRenderPlainText(rewritten)
                    self?.transcriptErrorMessage = nil
                    self?.isLoadingTranscript = false
                    self?.updateTranscriptDisplayContent()
                    self?.isRewritingTranscriptHeadings = false
                }
            } catch is CancellationError {
                await MainActor.run {
                    self?.isRewritingTranscriptHeadings = false
                }
            } catch {
                let message = Self.transcriptErrorMessage(for: error)
                await MainActor.run {
                    self?.speakerTranscriptRewriteErrorMessage = message
                    self?.isRewritingTranscriptHeadings = false
                }
            }
        }
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
        openInObsidianOrDefault(fileURL)
    }

    func openSummaryInApp(for item: MeetingNoteItem) {
        select(item)
    }

    func openTranscriptInApp(for item: MeetingNoteItem) {
        guard item.hasTranscript else { return }
        select(item)
        selectTab(.transcription)
    }

    func openSummaryInObsidian(for item: MeetingNoteItem) {
        openInObsidianOrDefault(item.fileURL)
    }

    func openTranscriptInObsidian(for item: MeetingNoteItem) {
        guard item.hasTranscript else { return }
        guard let transcriptURL = item.transcriptURL else { return }
        openInObsidianOrDefault(transcriptURL)
    }

    func revealInFinder(for item: MeetingNoteItem) {
        NSWorkspace.shared.activateFileViewerSelecting([item.fileURL])
    }

    private func openInObsidianOrDefault(_ fileURL: URL) {
        let path = fileURL.path
        var allowed = CharacterSet.urlQueryAllowed
        allowed.remove(charactersIn: "&+")
        if let encoded = path.addingPercentEncoding(withAllowedCharacters: allowed),
           let obsidianURL = URL(string: "obsidian://open?path=\(encoded)"),
           NSWorkspace.shared.open(obsidianURL) {
            return
        }

        _ = NSWorkspace.shared.open(fileURL)
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

                    self?.refreshSpeakerDraftsIfPossible()
                    self?.updateTranscriptDisplayContent()
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

                    self?.transcriptSpeakerIDs = Self.parseSpeakerIDs(fromTranscriptMarkdown: content)

                    self?.refreshSpeakerDraftsIfPossible()
                    self?.updateTranscriptDisplayContent()
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
        transcriptDisplayContent = nil
        transcriptErrorMessage = nil
        renderTranscriptPlainText = false
        isLoadingTranscript = false
    }

    private func startLoadingTranscriptSpeakerIDsIfNeeded(for item: MeetingNoteItem) {
        guard item.hasTranscript else { return }
        guard transcriptSpeakerIDs.isEmpty else { return }
        guard transcriptSpeakerIDsTask == nil else { return }

        let provider = browserProvider
        transcriptSpeakerIDsTask = Task { [weak self] in
            do {
                let content = try await provider().loadTranscriptContent(for: item)
                let ids = Self.parseSpeakerIDs(fromTranscriptMarkdown: content)
                await MainActor.run {
                    self?.transcriptSpeakerIDs = ids
                    self?.refreshSpeakerDraftsIfPossible()
                }
            } catch is CancellationError {
                // Ignore.
            } catch {
                // Ignore transcript read failures here; transcript tab handles user-visible errors.
            }

            await MainActor.run {
                self?.transcriptSpeakerIDsTask = nil
            }
        }
    }

    private func refreshSpeakerDraftsIfPossible() {
        let speakerIDsFromTranscript = Set(Self.parseSpeakerIDs(fromTranscriptMarkdown: transcriptContent))
            .union(transcriptSpeakerIDs)

        // Load existing mapping from the meeting note frontmatter, if present.
        let existingOwned = MeetingSpeakerNamingService(vaultWriter: DefaultVaultWriter())
            .loadOwnedParticipantFrontmatter(from: noteContent ?? "")

        let allIDs = speakerIDsFromTranscript.union(existingOwned.speakerMap.keys)
        var orderedIDs: [Int] = []
        orderedIDs.reserveCapacity(allIDs.count)

        var seen: Set<Int> = []
        if let existingOrder = existingOwned.speakerOrder {
            for id in existingOrder where allIDs.contains(id) {
                if seen.insert(id).inserted {
                    orderedIDs.append(id)
                }
            }
        }

        let remaining = allIDs
            .subtracting(seen)
            .sorted()
        orderedIDs.append(contentsOf: remaining)
        speakerIDs = orderedIDs

        // Initialize drafts from existing mapping if drafts are empty.
        if speakerNameDrafts.isEmpty {
            speakerNameDrafts = existingOwned.speakerMap.mapValues { $0 }
        } else {
            // Ensure any newly discovered speaker IDs exist in the draft map.
            for id in orderedIDs {
                if speakerNameDrafts[id] == nil, let existing = existingOwned.speakerMap[id] {
                    speakerNameDrafts[id] = existing
                }
            }
        }

        refreshKnownSpeakerStatusIfPossible()
    }

    private func refreshKnownSpeakerStatusIfPossible() {
        guard let item = selectedItem else { return }
        guard !speakerIDs.isEmpty else { return }

        let meetingKey = item.fileURL.path
        let speakerIDsSnapshot = speakerIDs

        knownSpeakerStatusTask?.cancel()
        knownSpeakerStatusTask = Task { [weak self] in
            let cache = MeetingSpeakerEmbeddingCache()
            let store = SpeakerProfileStore()
            let matcher = SpeakerEmbeddingMatcher()

            let profiles: [SpeakerProfile]
            do {
                profiles = try await store.listProfiles()
            } catch {
                return
            }

            let profileNames = profiles
                .map(\.name)
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
                .sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }

            await MainActor.run {
                self?.knownSpeakerProfileNames = profileNames
            }

            let meetingEmbeddings: MeetingSpeakerEmbeddingCache.MeetingEmbeddings?
            do {
                meetingEmbeddings = try await cache.get(meetingKey: meetingKey)
            } catch {
                return
            }
            guard let meetingEmbeddings else { return }

            if profiles.isEmpty { return }

            var idBySpeaker: [Int: String] = [:]
            var nameBySpeaker: [Int: String] = [:]
            idBySpeaker.reserveCapacity(speakerIDsSnapshot.count)
            nameBySpeaker.reserveCapacity(speakerIDsSnapshot.count)

            for speakerID in speakerIDsSnapshot {
                guard let embedding = meetingEmbeddings.embeddingsBySpeakerID[speakerID] else { continue }
                do {
                    if let match = try matcher.bestMatch(
                        embedding: embedding,
                        candidates: profiles,
                        embeddingModelVersion: meetingEmbeddings.embeddingModelVersion
                    ) {
                        idBySpeaker[speakerID] = match.profile.id
                        nameBySpeaker[speakerID] = match.profile.name
                    }
                } catch {
                    // Best-effort only.
                }
            }

            await MainActor.run {
                self?.knownSpeakerProfileIDBySpeakerID = idBySpeaker
                self?.knownSpeakerProfileNameBySpeakerID = nameBySpeaker
            }
        }
    }

    private func updateTranscriptDisplayContent() {
        guard let raw = transcriptContent else {
            transcriptDisplayContent = nil
            return
        }

        // Display-only transform: replace "Speaker N" headings when a name exists.
        transcriptDisplayContent = Self.rewriteSpeakerHeadingsForDisplay(
            transcriptMarkdown: raw,
            speakerDisplayNames: speakerNameDrafts
        )
    }

    nonisolated static func parseSpeakerIDs(fromTranscriptMarkdown markdown: String?) -> [Int] {
        guard let markdown else { return [] }

        var ids: Set<Int> = []
        for line in markdown.split(separator: "\n", omittingEmptySubsequences: false) {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard trimmed.hasPrefix("Speaker ") else { continue }

            let afterPrefix = trimmed.dropFirst("Speaker ".count)
            let digits = afterPrefix.prefix { $0.isNumber }
            if let id = Int(digits) {
                ids.insert(id)
            }
        }

        return ids.sorted()
    }

    nonisolated static func rewriteSpeakerHeadingsForDisplay(
        transcriptMarkdown: String,
        speakerDisplayNames: [Int: String]
    ) -> String {
        let lines = transcriptMarkdown.split(separator: "\n", omittingEmptySubsequences: false)
        var out: [String] = []
        out.reserveCapacity(lines.count)

        for lineSub in lines {
            let line = String(lineSub)
            let leadingWhitespace = line.prefix { $0.isWhitespace }
            let remainder = line.dropFirst(leadingWhitespace.count)
            let trimmed = remainder.trimmingCharacters(in: .whitespaces)

            if trimmed.hasPrefix("Speaker ") {
                let afterPrefix = trimmed.dropFirst("Speaker ".count)
                let digits = afterPrefix.prefix { $0.isNumber }
                if let id = Int(digits),
                   let name = speakerDisplayNames[id]?.trimmingCharacters(in: .whitespacesAndNewlines),
                   !name.isEmpty,
                   let bracketRange = trimmed.range(of: " [") {
                    // Replace the entire heading token (Speaker N + optional " (Name)") with the current name.
                    let suffix = String(trimmed[bracketRange.lowerBound...])
                    out.append(String(leadingWhitespace) + name + suffix)
                    continue
                }
            }
            out.append(line)
        }

        return out.joined(separator: "\n")
    }

    nonisolated private static func makeVaultAccess() -> VaultAccess {
        let defaults = UserDefaults.standard
        let bookmarkStore = UserDefaultsVaultBookmarkStore(
            defaults: defaults,
            key: AppConfiguration.Defaults.vaultRootBookmarkKey
        )
        return VaultAccess(bookmarkStore: bookmarkStore)
    }

    nonisolated private static func transcriptURL(
        for item: MeetingNoteItem,
        vaultRootURL: URL,
        transcriptsRelativePath: String
    ) -> URL {
        let baseName = item.fileURL.deletingPathExtension().lastPathComponent
        let root = Self.directoryURL(from: vaultRootURL, relativePath: transcriptsRelativePath)
        return root.appendingPathComponent("\(baseName).md")
    }

    nonisolated private static func directoryURL(from vaultRootURL: URL, relativePath: String) -> URL {
        let components = relativePath
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            .split(separator: "/")
            .map(String.init)
            .filter { !$0.isEmpty && $0 != "." && $0 != ".." }

        return components.reduce(vaultRootURL) { partial, component in
            partial.appendingPathComponent(component, isDirectory: true)
        }
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
