import XCTest
@testable import MinuteCore

final class MeetingFileContractTests: XCTestCase {
    func testPaths_useExpectedFoldersAndFormat() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!

        let date = calendar.date(from: DateComponents(year: 2025, month: 12, day: 19))!
        let contract = MeetingFileContract(
            folders: .init(
                meetingsRoot: "Meetings",
                audioRoot: "Meetings/_audio",
                transcriptsRoot: "Meetings/_transcripts"
            )
        )

        let note = contract.noteRelativePath(date: date, title: "Weekly Sync", calendar: calendar)
        XCTAssertEqual(note, "Meetings/2025/12/2025-12-19 - Weekly Sync.md")

        let audio = contract.audioRelativePath(date: date, title: "Weekly Sync", calendar: calendar)
        XCTAssertEqual(audio, "Meetings/_audio/2025-12-19 - Weekly Sync.wav")

        let transcript = contract.transcriptRelativePath(date: date, title: "Weekly Sync", calendar: calendar)
        XCTAssertEqual(transcript, "Meetings/_transcripts/2025-12-19 - Weekly Sync.md")
    }

    func testPaths_sanitizeTitle() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!

        let date = calendar.date(from: DateComponents(year: 2025, month: 1, day: 2))!
        let contract = MeetingFileContract()

        let audio = contract.audioRelativePath(date: date, title: "A/B:C", calendar: calendar)
        XCTAssertEqual(audio, "Meetings/_audio/2025-01-02 - A B C.wav")
    }
}
