import Foundation
@testable import MinuteCore

enum ReprocessMeetingFixtures {
    static let basename = "2026-03-20 09.41 - Product Review"
    static let noteRelativePath = "Meetings/2026/03/\(basename).md"
    static let transcriptRelativePath = "Meetings/_transcripts/\(basename).md"
    static let audioRelativePath = "Meetings/_audio/\(basename).wav"

    static func noteMarkdown(
        title: String = "Product Review",
        meetingTypeID: String = MeetingType.general.rawValue
    ) -> String {
        """
        ---
        title: \(title)
        meeting_type: \(meetingTypeID)
        ---

        # \(title)

        Existing managed note body.
        """
    }

    static func transcriptMarkdown() -> String {
        """
        ---
        title: Product Review
        ---

        Speaker 1 [00:00]
        We should move the launch review to next week.

        Speaker 2 [00:08]
        That gives design time to finish the final pass.
        """
    }

    static func meetingItem(
        in vaultRootURL: URL,
        hasTranscript: Bool = true,
        currentMeetingTypeId: String? = MeetingType.general.rawValue,
        reprocessBlockingReason: ReprocessBlockingReason? = nil
    ) -> MeetingNoteItem {
        let noteURL = vaultRootURL.appendingPathComponent(noteRelativePath)
        let transcriptURL = vaultRootURL.appendingPathComponent(transcriptRelativePath)

        return MeetingNoteItem(
            title: "Product Review",
            date: Date(timeIntervalSince1970: 1_742_462_460),
            relativePath: noteRelativePath,
            fileURL: noteURL,
            hasTranscript: hasTranscript,
            transcriptURL: hasTranscript ? transcriptURL : nil,
            currentMeetingTypeId: currentMeetingTypeId,
            reprocessBlockingReason: reprocessBlockingReason
        )
    }

    static func reprocessRequest(
        in vaultRootURL: URL,
        targetMeetingTypeId: String = MeetingType.planning.rawValue,
        currentMeetingTypeId: String? = MeetingType.general.rawValue,
        overwriteConfirmed: Bool = true
    ) -> ReprocessMeetingRequest {
        let noteURL = vaultRootURL.appendingPathComponent(noteRelativePath)
        let transcriptURL = vaultRootURL.appendingPathComponent(transcriptRelativePath)

        return ReprocessMeetingRequest(
            meetingId: noteRelativePath,
            noteURL: noteURL,
            transcriptURL: transcriptURL,
            targetMeetingTypeId: targetMeetingTypeId,
            currentMeetingTypeId: currentMeetingTypeId,
            overwriteConfirmed: overwriteConfirmed
        )
    }
}