import Foundation
import Testing
@testable import MinuteCore

/// Tests for renaming a meeting note: pure markdown rewriting plus the
/// three-file vault rename in `VaultMeetingNotesBrowser`.
struct MeetingNoteRenamerTests {

    // MARK: - Pure markdown rewriting

    private let noteMarkdown = """
    ---
    type: meeting
    date: Jan 10, 2025 at 10:00
    title: "Team Sync"
    source: "Minute"
    meeting_type: general
    length: 30m
    tags:
    ---

    # Team Sync

    ## Summary
    The team synced. Team Sync is mentioned inline and must not change.

    ## Audio
    [[Meetings/_audio/2025-01-10 10.00 - Team Sync.wav]]

    ## Transcript
    [[Meetings/_transcripts/2025-01-10 10.00 - Team Sync.md]]
    """

    @Test
    func rewriteNote_updatesFrontmatterTitleHeadingAndLinks() {
        let result = MeetingNoteRenamer.rewrittenNoteMarkdown(
            noteMarkdown,
            oldTitle: "Team Sync",
            newTitle: "Weekly Platform Sync",
            oldBaseName: "2025-01-10 10.00 - Team Sync",
            newBaseName: "2025-01-10 10.00 - Weekly Platform Sync"
        )

        #expect(result.contains("title: \"Weekly Platform Sync\""))
        #expect(result.contains("# Weekly Platform Sync\n"))
        #expect(result.contains("[[Meetings/_audio/2025-01-10 10.00 - Weekly Platform Sync.wav]]"))
        #expect(result.contains("[[Meetings/_transcripts/2025-01-10 10.00 - Weekly Platform Sync.md]]"))
        // Body prose mentioning the old title must be preserved.
        #expect(result.contains("Team Sync is mentioned inline and must not change."))
        // No stale links remain.
        #expect(!result.contains("2025-01-10 10.00 - Team Sync.wav"))
        #expect(!result.contains("2025-01-10 10.00 - Team Sync.md"))
    }

    @Test
    func rewriteNote_leavesUnrelatedFrontmatterUntouched() {
        let result = MeetingNoteRenamer.rewrittenNoteMarkdown(
            noteMarkdown,
            oldTitle: "Team Sync",
            newTitle: "Renamed",
            oldBaseName: "2025-01-10 10.00 - Team Sync",
            newBaseName: "2025-01-10 10.00 - Renamed"
        )

        #expect(result.contains("type: meeting"))
        #expect(result.contains("meeting_type: general"))
        #expect(result.contains("length: 30m"))
        #expect(result.contains("date: Jan 10, 2025 at 10:00"))
    }

    @Test
    func rewriteTranscript_updatesTitleAndHeading() {
        let transcript = """
        ---
        type: meeting_transcript
        date: 2025-01-10
        title: "Team Sync"
        source: "Minute"
        ---

        # Team Sync — Transcript

        Speaker 1 [00:00 - 00:10]
        Hello Team Sync attendees.
        """

        let result = MeetingNoteRenamer.rewrittenTranscriptMarkdown(
            transcript,
            oldTitle: "Team Sync",
            newTitle: "Weekly Platform Sync"
        )

        #expect(result.contains("title: \"Weekly Platform Sync\""))
        #expect(result.contains("# Weekly Platform Sync — Transcript"))
        // Transcript body untouched.
        #expect(result.contains("Hello Team Sync attendees."))
    }

    @Test
    func newBaseName_preservesDateTimePrefixAndSanitizesTitle() {
        let base = MeetingNoteRenamer.newBaseName(
            oldBaseName: "2025-01-10 10.00 - Team Sync",
            newTitle: "  Bad/Name: with*chars?  "
        )
        #expect(base == "2025-01-10 10.00 - Bad Name with chars")
    }

    @Test
    func newBaseName_withoutDatePrefix_usesSanitizedTitleOnly() {
        let base = MeetingNoteRenamer.newBaseName(oldBaseName: "Untracked Note", newTitle: "Fresh Title")
        #expect(base == "Fresh Title")
    }

    // MARK: - Vault file renaming

    @Test
    func renameNoteFiles_renamesAllThreeFilesAndRewritesContent() async throws {
        let rootURL = try makeTemporaryVault()
        defer { try? FileManager.default.removeItem(at: rootURL) }

        let noteURL = rootURL.appendingPathComponent("Meetings/2025/01/2025-01-10 10.00 - Team Sync.md")
        let transcriptURL = rootURL.appendingPathComponent("Meetings/_transcripts/2025-01-10 10.00 - Team Sync.md")
        let audioURL = rootURL.appendingPathComponent("Meetings/_audio/2025-01-10 10.00 - Team Sync.wav")

        try createFile(at: noteURL, contents: noteMarkdown)
        try createFile(
            at: transcriptURL,
            contents: "---\ntitle: \"Team Sync\"\n---\n\n# Team Sync — Transcript\n\nBody."
        )
        try createFile(at: audioURL, contents: "RIFF-FAKE-AUDIO")

        let browser = try makeBrowser(vaultRootURL: rootURL)
        let items = try await browser.listNotes()
        let item = try #require(items.first)

        let renamed = try await browser.renameNoteFiles(for: item, to: "Weekly Platform Sync")

        let newNoteURL = rootURL.appendingPathComponent("Meetings/2025/01/2025-01-10 10.00 - Weekly Platform Sync.md")
        let newTranscriptURL = rootURL.appendingPathComponent("Meetings/_transcripts/2025-01-10 10.00 - Weekly Platform Sync.md")
        let newAudioURL = rootURL.appendingPathComponent("Meetings/_audio/2025-01-10 10.00 - Weekly Platform Sync.wav")

        #expect(FileManager.default.fileExists(atPath: newNoteURL.path))
        #expect(FileManager.default.fileExists(atPath: newTranscriptURL.path))
        #expect(FileManager.default.fileExists(atPath: newAudioURL.path))
        #expect(!FileManager.default.fileExists(atPath: noteURL.path))
        #expect(!FileManager.default.fileExists(atPath: transcriptURL.path))
        #expect(!FileManager.default.fileExists(atPath: audioURL.path))

        let newNote = try String(contentsOf: newNoteURL, encoding: .utf8)
        #expect(newNote.contains("title: \"Weekly Platform Sync\""))
        #expect(newNote.contains("[[Meetings/_audio/2025-01-10 10.00 - Weekly Platform Sync.wav]]"))
        #expect(newNote.contains("[[Meetings/_transcripts/2025-01-10 10.00 - Weekly Platform Sync.md]]"))

        let newTranscript = try String(contentsOf: newTranscriptURL, encoding: .utf8)
        #expect(newTranscript.contains("title: \"Weekly Platform Sync\""))
        #expect(newTranscript.contains("# Weekly Platform Sync — Transcript"))

        #expect(renamed.title == "Weekly Platform Sync")
        #expect(renamed.fileURL.lastPathComponent == "2025-01-10 10.00 - Weekly Platform Sync.md")
    }

    @Test
    func renameNoteFiles_withMissingAudioAndTranscript_renamesNoteOnly() async throws {
        let rootURL = try makeTemporaryVault()
        defer { try? FileManager.default.removeItem(at: rootURL) }

        let noteURL = rootURL.appendingPathComponent("Meetings/2025/01/2025-01-10 10.00 - Team Sync.md")
        try createFile(at: noteURL, contents: noteMarkdown)

        let browser = try makeBrowser(vaultRootURL: rootURL)
        let item = try #require(try await browser.listNotes().first)

        let renamed = try await browser.renameNoteFiles(for: item, to: "Solo Note")

        let newNoteURL = rootURL.appendingPathComponent("Meetings/2025/01/2025-01-10 10.00 - Solo Note.md")
        #expect(FileManager.default.fileExists(atPath: newNoteURL.path))
        #expect(renamed.title == "Solo Note")
    }

    @Test
    func renameNoteFiles_rejectsEmptyTitleAndCollisions() async throws {
        let rootURL = try makeTemporaryVault()
        defer { try? FileManager.default.removeItem(at: rootURL) }

        let noteURL = rootURL.appendingPathComponent("Meetings/2025/01/2025-01-10 10.00 - Team Sync.md")
        let collidingURL = rootURL.appendingPathComponent("Meetings/2025/01/2025-01-10 10.00 - Existing.md")
        try createFile(at: noteURL, contents: noteMarkdown)
        try createFile(at: collidingURL, contents: "# Existing")

        let browser = try makeBrowser(vaultRootURL: rootURL)
        let items = try await browser.listNotes()
        let item = try #require(items.first { $0.fileURL.lastPathComponent.contains("Team Sync") })

        await #expect(throws: MeetingNoteRenameError.emptyTitle) {
            _ = try await browser.renameNoteFiles(for: item, to: "   ")
        }
        await #expect(throws: MeetingNoteRenameError.destinationAlreadyExists) {
            _ = try await browser.renameNoteFiles(for: item, to: "Existing")
        }
        await #expect(throws: MeetingNoteRenameError.titleUnchanged) {
            _ = try await browser.renameNoteFiles(for: item, to: "Team Sync")
        }

        // Original files untouched after failed attempts.
        #expect(FileManager.default.fileExists(atPath: noteURL.path))
    }
}

private final class InMemoryBookmarkStore: VaultBookmarkStoring {
    private var bookmark: Data?

    init(bookmark: Data?) {
        self.bookmark = bookmark
    }

    func loadVaultRootBookmark() -> Data? { bookmark }
    func saveVaultRootBookmark(_ bookmark: Data) { self.bookmark = bookmark }
    func clearVaultRootBookmark() { bookmark = nil }
}

private func makeTemporaryVault() throws -> URL {
    let url = FileManager.default.temporaryDirectory
        .appendingPathComponent("minute-rename-vault-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    return url
}

private func makeBrowser(vaultRootURL: URL) throws -> VaultMeetingNotesBrowser {
    let bookmark = try VaultAccess.makeBookmarkData(forVaultRootURL: vaultRootURL)
    let store = InMemoryBookmarkStore(bookmark: bookmark)
    let access = VaultAccess(bookmarkStore: store)
    return VaultMeetingNotesBrowser(vaultAccess: access, meetingsRelativePath: "Meetings")
}

private func createFile(at url: URL, contents: String) throws {
    try FileManager.default.createDirectory(
        at: url.deletingLastPathComponent(),
        withIntermediateDirectories: true
    )
    try Data(contents.utf8).write(to: url, options: [.atomic])
}
