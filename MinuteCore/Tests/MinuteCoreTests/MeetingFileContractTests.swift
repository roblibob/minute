import Testing
import Foundation
@testable import MinuteCore

struct MeetingFileContractTests {
    @Test
    func paths_useExpectedFoldersAndFormat() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!

        let date = calendar.date(from: DateComponents(year: 2025, month: 12, day: 19, hour: 9, minute: 30))!
        let contract = MeetingFileContract(
            folders: .init(
                meetingsRoot: "Meetings",
                audioRoot: "Meetings/_audio",
                transcriptsRoot: "Meetings/_transcripts"
            )
        )

        let note = contract.noteRelativePath(date: date, title: "Weekly Sync", calendar: calendar)
        expectEqual(note, "Meetings/2025/12/2025-12-19 09.30 - Weekly Sync.md")

        let audio = contract.audioRelativePath(date: date, title: "Weekly Sync", calendar: calendar)
        expectEqual(audio, "Meetings/_audio/2025-12-19 09.30 - Weekly Sync.wav")

        let transcript = contract.transcriptRelativePath(date: date, title: "Weekly Sync", calendar: calendar)
        expectEqual(transcript, "Meetings/_transcripts/2025-12-19 09.30 - Weekly Sync.md")
    }

    @Test
    func paths_sanitizeTitle() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!

        let date = calendar.date(from: DateComponents(year: 2025, month: 1, day: 2, hour: 7, minute: 5))!
        let contract = MeetingFileContract()

        let audio = contract.audioRelativePath(date: date, title: "A/B:C", calendar: calendar)
        expectEqual(audio, "Meetings/_audio/2025-01-02 07.05 - A B C.wav")
    }
}
