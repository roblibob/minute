import Foundation
import XCTest
@testable import MinuteCore

final class VaultMeetingNotesBrowserTests: XCTestCase {
    func testListNotesExcludesAudioAndTranscripts() async throws {
        let rootURL = try makeTemporaryVault()
        defer { try? FileManager.default.removeItem(at: rootURL) }

        try createFile(
            at: rootURL.appendingPathComponent("Meetings/2025/01/2025-01-10 10:00 - Team Sync.md"),
            contents: "# Team Sync"
        )
        try createFile(
            at: rootURL.appendingPathComponent("Meetings/_audio/2025-01-10 10:00 - Team Sync.md"),
            contents: "should ignore"
        )
        try createFile(
            at: rootURL.appendingPathComponent("Meetings/_transcripts/2025-01-10 10:00 - Team Sync.md"),
            contents: "should ignore"
        )

        let browser = try makeBrowser(vaultRootURL: rootURL)
        let notes = try await browser.listNotes()

        XCTAssertEqual(notes.count, 1)
        XCTAssertEqual(notes.first?.title, "Team Sync")
        XCTAssertEqual(
            notes.first?.relativePath,
            "Meetings/2025/01/2025-01-10 10:00 - Team Sync.md"
        )
        XCTAssertNotNil(notes.first?.date)
    }

    func testSortsNewestFirstByParsedDate() async throws {
        let rootURL = try makeTemporaryVault()
        defer { try? FileManager.default.removeItem(at: rootURL) }

        try createFile(
            at: rootURL.appendingPathComponent("Meetings/2025/01/2025-01-01 08:00 - First.md"),
            contents: "# First"
        )
        try createFile(
            at: rootURL.appendingPathComponent("Meetings/2025/02/2025-02-01 09:00 - Second.md"),
            contents: "# Second"
        )

        let browser = try makeBrowser(vaultRootURL: rootURL)
        let notes = try await browser.listNotes()

        XCTAssertEqual(notes.map(\.title), ["Second", "First"])
    }

    func testFallbackToModificationDateWhenParsingFails() async throws {
        let rootURL = try makeTemporaryVault()
        defer { try? FileManager.default.removeItem(at: rootURL) }

        let parsedURL = rootURL.appendingPathComponent("Meetings/2025/01/2025-01-01 08:00 - Parsed.md")
        let looseURL = rootURL.appendingPathComponent("Meetings/Loose.md")

        try createFile(at: parsedURL, contents: "# Parsed")
        try createFile(at: looseURL, contents: "# Loose")

        let futureDate = Date(timeIntervalSince1970: 1_893_456_000)
        try FileManager.default.setAttributes([.modificationDate: futureDate], ofItemAtPath: looseURL.path)

        let browser = try makeBrowser(vaultRootURL: rootURL)
        let notes = try await browser.listNotes()

        XCTAssertEqual(notes.first?.title, "Loose")
        XCTAssertNil(notes.first?.date)
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
