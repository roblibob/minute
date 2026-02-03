import Foundation
import Testing
@testable import MinuteCore

struct VaultMeetingNotesBrowserTests {
    @Test
    func listNotesExcludesAudioAndTranscripts() async throws {
        let rootURL = try makeTemporaryVault()
        defer { try? FileManager.default.removeItem(at: rootURL) }

        try createFile(
            at: rootURL.appendingPathComponent("Meetings/2025/01/2025-01-10 10.00 - Team Sync.md"),
            contents: "# Team Sync"
        )
        try createFile(
            at: rootURL.appendingPathComponent("Meetings/_audio/2025-01-10 10.00 - Team Sync.md"),
            contents: "should ignore"
        )
        try createFile(
            at: rootURL.appendingPathComponent("Meetings/_transcripts/2025-01-10 10.00 - Team Sync.md"),
            contents: "should ignore"
        )

        let browser = try makeBrowser(vaultRootURL: rootURL)
        let notes = try await browser.listNotes()

        expectEqual(notes.count, 1)
        expectEqual(notes.first?.title, "Team Sync")
        expectEqual(
            notes.first?.relativePath,
            "Meetings/2025/01/2025-01-10 10.00 - Team Sync.md"
        )
        #expect(notes.first?.date != nil)
    }

    @Test
    func sortsNewestFirstByParsedDate() async throws {
        let rootURL = try makeTemporaryVault()
        defer { try? FileManager.default.removeItem(at: rootURL) }

        try createFile(
            at: rootURL.appendingPathComponent("Meetings/2025/01/2025-01-01 08.00 - First.md"),
            contents: "# First"
        )
        try createFile(
            at: rootURL.appendingPathComponent("Meetings/2025/02/2025-02-01 09.00 - Second.md"),
            contents: "# Second"
        )

        let browser = try makeBrowser(vaultRootURL: rootURL)
        let notes = try await browser.listNotes()

        expectEqual(notes.map(\.title), ["Second", "First"])
    }

    @Test
    func fallbackToModificationDateWhenParsingFails() async throws {
        let rootURL = try makeTemporaryVault()
        defer { try? FileManager.default.removeItem(at: rootURL) }

        let parsedURL = rootURL.appendingPathComponent("Meetings/2025/01/2025-01-01 08.00 - Parsed.md")
        let looseURL = rootURL.appendingPathComponent("Meetings/Loose.md")

        try createFile(at: parsedURL, contents: "# Parsed")
        try createFile(at: looseURL, contents: "# Loose")

        let futureDate = Date(timeIntervalSince1970: 1_893_456_000)
        try FileManager.default.setAttributes([.modificationDate: futureDate], ofItemAtPath: looseURL.path)

        let browser = try makeBrowser(vaultRootURL: rootURL)
        let notes = try await browser.listNotes()

        expectEqual(notes.first?.title, "Loose")
        #expect(notes.first?.date == nil)
    }

    @Test
    func deleteRemovesNoteAudioTranscriptWhenPresent() async throws {
        let rootURL = try makeTemporaryVault()
        defer { try? FileManager.default.removeItem(at: rootURL) }

        let noteURL = rootURL.appendingPathComponent("Meetings/2025/01/2025-01-10 10.00 - Team Sync.md")
        let audioURL = rootURL.appendingPathComponent("Meetings/_audio/2025-01-10 10.00 - Team Sync.wav")
        let transcriptURL = rootURL.appendingPathComponent("Meetings/_transcripts/2025-01-10 10.00 - Team Sync.md")

        try createFile(at: noteURL, contents: "# Team Sync")
        try createFile(at: audioURL, contents: "audio")
        try createFile(at: transcriptURL, contents: "transcript")

        let browser = try makeBrowser(vaultRootURL: rootURL)
        let notes = try await browser.listNotes()
        guard let note = notes.first else {
            #expect(false)
            return
        }

        try await browser.deleteNoteFiles(for: note)

        #expect(!FileManager.default.fileExists(atPath: noteURL.path))
        #expect(!FileManager.default.fileExists(atPath: audioURL.path))
        #expect(!FileManager.default.fileExists(atPath: transcriptURL.path))
    }

    @Test
    func loadTranscriptContentReturnsTranscriptFile() async throws {
        let rootURL = try makeTemporaryVault()
        defer { try? FileManager.default.removeItem(at: rootURL) }

        let noteURL = rootURL.appendingPathComponent("Meetings/2025/01/2025-01-10 10.00 - Team Sync.md")
        let transcriptURL = rootURL.appendingPathComponent("Meetings/_transcripts/2025-01-10 10.00 - Team Sync.md")

        try createFile(at: noteURL, contents: "# Team Sync")
        try createFile(at: transcriptURL, contents: "transcript contents")

        let browser = try makeBrowser(vaultRootURL: rootURL)
        guard let note = try await browser.listNotes().first else {
            #expect(false)
            return
        }

        let content = try await browser.loadTranscriptContent(for: note)

        expectEqual(content, "transcript contents")
    }
}

private final class InMemoryBookmarkStore: VaultBookmarkStoring {
    private var bookmark: Data?

    init(bookmark: Data?) {
        self.bookmark = bookmark
    }

    func loadVaultRootBookmark() -> Data? {
        bookmark
    }

    func saveVaultRootBookmark(_ bookmark: Data) {
        self.bookmark = bookmark
    }

    func clearVaultRootBookmark() {
        bookmark = nil
    }
}

private func makeTemporaryVault() throws -> URL {
    let url = FileManager.default.temporaryDirectory
        .appendingPathComponent("minute-vault-\(UUID().uuidString)", isDirectory: true)
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
