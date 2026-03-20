import Foundation
import MinuteCore
@testable import Minute

enum ReprocessMeetingBrowserTestSupport {
    static let basename = "2026-03-20 09.41 - Product Review"

    static func makeMeetingItem(
        hasTranscript: Bool = true,
        currentMeetingTypeId: String? = MeetingType.general.rawValue,
        reprocessBlockingReason: ReprocessBlockingReason? = nil
    ) -> MeetingNoteItem {
        let rootURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("minute-browser-reprocess-tests", isDirectory: true)
        let noteURL = rootURL.appendingPathComponent("Meetings/2026/03/\(basename).md")
        let transcriptURL = rootURL.appendingPathComponent("Meetings/_transcripts/\(basename).md")

        return MeetingNoteItem(
            title: "Product Review",
            date: Date(timeIntervalSince1970: 1_742_462_460),
            relativePath: "Meetings/2026/03/\(basename).md",
            fileURL: noteURL,
            hasTranscript: hasTranscript,
            transcriptURL: hasTranscript ? transcriptURL : nil,
            currentMeetingTypeId: currentMeetingTypeId,
            reprocessBlockingReason: reprocessBlockingReason
        )
    }

    static func makePreview(summaryLine: String = "Recovered note summary") -> MeetingNotesBrowserViewModel.NotePreview {
        MeetingNotesBrowserViewModel.NotePreview(summaryLine: summaryLine, durationSeconds: 900)
    }
}