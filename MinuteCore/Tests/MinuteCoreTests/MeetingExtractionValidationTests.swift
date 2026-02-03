import Foundation
import Testing
@testable import MinuteCore

struct MeetingExtractionValidationTests {
    @Test
    func validated_normalizesTitleAndDateAndFiltersEmptyValues() {
        let extraction = MeetingExtraction(
            title: "  Weekly\nSync  ",
            date: "not-a-date",
            summary: "  Line 1\r\nLine 2  ",
            decisions: [" Ship v1 ", ""],
            actionItems: [ActionItem(owner: "  ", task: "   "), ActionItem(owner: "Alex", task: " Draft ")],
            openQuestions: ["  ", "Need ffmpeg?"],
            keyPoints: ["  Local-only  "]
        )

        let recordingDate = Date(timeIntervalSince1970: 1_700_000_000)
        let validated = MeetingExtractionValidation.validated(extraction, recordingDate: recordingDate)

        expectEqual(validated.title, "Weekly Sync")
        expectEqual(validated.date, MeetingFileContract.isoDate(recordingDate))
        expectEqual(validated.summary, "Line 1\nLine 2")
        expectEqual(validated.decisions, ["Ship v1"])
        expectEqual(validated.openQuestions, ["Need ffmpeg?"])
        expectEqual(validated.keyPoints, ["Local-only"])
        expectEqual(validated.actionItems, [ActionItem(owner: "Alex", task: "Draft")])
    }

    @Test
    func fallback_usesUntitledAndRecordingDate() {
        let recordingDate = Date(timeIntervalSince1970: 1_700_000_000)
        let fallback = MeetingExtractionValidation.fallback(recordingDate: recordingDate)

        expectEqual(fallback.title, "Untitled")
        expectEqual(fallback.date, MeetingFileContract.isoDate(recordingDate))
        #expect(fallback.summary.contains("Failed to structure output"))
        expectEqual(fallback.decisions, [])
        expectEqual(fallback.actionItems, [])
        expectEqual(fallback.openQuestions, [])
        expectEqual(fallback.keyPoints, [])
    }
}
