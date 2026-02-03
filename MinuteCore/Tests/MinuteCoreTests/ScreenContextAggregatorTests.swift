import Testing
import Foundation
@testable import MinuteCore

struct ScreenContextAggregatorTests {
    @Test
    func summarizeExtractsAgendaAndParticipants() {
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

        expectEqual(summary.agendaItems, ["Intro", "Roadmap"])
        expectEqual(summary.participantCount, 3)
        expectEqual(summary.participantNames, ["Alice Johnson", "Bob Smith", "Carol Lee"])
    }

    @Test
    func summarizeRedactsEmails() {
        let snapshot = ScreenContextSnapshot(
            capturedAt: Date(),
            windowTitle: "Slack",
            extractedLines: [
                "Shared: agenda.pdf alice@example.com"
            ]
        )

        let summary = ScreenContextAggregator.summarize(snapshots: [snapshot])
        let artifact = summary.sharedArtifacts.first ?? ""

        #expect(artifact.contains("[redacted]"))
        #expect(!artifact.contains("alice@example.com"))
    }
}
