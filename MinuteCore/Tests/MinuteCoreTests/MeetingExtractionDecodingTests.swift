import Testing
import Foundation
@testable import MinuteCore

struct MeetingExtractionDecodingTests {
    @Test
    func decoding_matchesFixedSchemaKeys() throws {
        let json = #"""
        {
          "title": "Weekly Sync",
          "date": "2025-12-19",
          "summary": "We aligned on next steps.",
          "decisions": ["Ship v1"],
          "action_items": [{"owner":"Alex","task":"Draft release notes"}],
          "open_questions": ["Do we need ffmpeg?"],
          "key_points": ["Local-only processing"]
        }
        """#

        let data = Data(json.utf8)
        let extraction = try JSONDecoder().decode(MeetingExtraction.self, from: data)

        expectEqual(extraction.title, "Weekly Sync")
        expectEqual(extraction.date, "2025-12-19")
        expectEqual(extraction.summary, "We aligned on next steps.")
        expectEqual(extraction.decisions, ["Ship v1"])
        expectEqual(extraction.actionItems, [ActionItem(owner: "Alex", task: "Draft release notes")])
        expectEqual(extraction.openQuestions, ["Do we need ffmpeg?"])
        expectEqual(extraction.keyPoints, ["Local-only processing"])
    }
}
