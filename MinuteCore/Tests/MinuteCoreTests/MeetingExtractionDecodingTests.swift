import XCTest
@testable import MinuteCore

final class MeetingExtractionDecodingTests: XCTestCase {
    func testDecoding_matchesFixedSchemaKeys() throws {
        let json = #"""
        {
          "title": "Weekly Sync",
          "date": "2025-12-19",
          "summary": "We aligned on next steps.",
          "decisions": ["Ship v1"],
          "action_items": [{"owner":"Alex","task":"Draft release notes","due":""}],
          "open_questions": ["Do we need ffmpeg?"],
          "key_points": ["Local-only processing"]
        }
        """#

        let data = Data(json.utf8)
        let extraction = try JSONDecoder().decode(MeetingExtraction.self, from: data)

        XCTAssertEqual(extraction.title, "Weekly Sync")
        XCTAssertEqual(extraction.date, "2025-12-19")
        XCTAssertEqual(extraction.summary, "We aligned on next steps.")
        XCTAssertEqual(extraction.decisions, ["Ship v1"])
        XCTAssertEqual(extraction.actionItems, [ActionItem(owner: "Alex", task: "Draft release notes", due: "")])
        XCTAssertEqual(extraction.openQuestions, ["Do we need ffmpeg?"])
        XCTAssertEqual(extraction.keyPoints, ["Local-only processing"])
    }
}
