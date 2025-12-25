import XCTest
@testable import MinuteCore

final class ScreenContextAggregatorTests: XCTestCase {
    func testSummarizeExtractsAgendaAndParticipants() {
        let snapshot = ScreenContextSnapshot(
            capturedAt: Date(),
            windowTitle: "Teams",
            extractedLines: [
                "Agenda",
                "- Intro",
                "- Roadmap",
                "Participants (3)",
                "Alice Johnson",
                "Bob Smith",
                "Carol Lee"
            ]
        )

        let summary = ScreenContextAggregator.summarize(snapshots: [snapshot])

        XCTAssertEqual(summary.agendaItems, ["Intro", "Roadmap"])
        XCTAssertEqual(summary.participantCount, 3)
        XCTAssertEqual(summary.participantNames, ["Alice Johnson", "Bob Smith", "Carol Lee"])
    }

    func testSummarizeRedactsEmails() {
        let snapshot = ScreenContextSnapshot(
            capturedAt: Date(),
            windowTitle: "Slack",
            extractedLines: [
                "Shared: agenda.pdf alice@example.com"
            ]
        )

        let summary = ScreenContextAggregator.summarize(snapshots: [snapshot])
        let artifact = summary.sharedArtifacts.first ?? ""

        XCTAssertTrue(artifact.contains("[redacted]"))
        XCTAssertFalse(artifact.contains("alice@example.com"))
    }
}
