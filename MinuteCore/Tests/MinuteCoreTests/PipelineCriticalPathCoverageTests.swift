import Testing
import Foundation
@testable import MinuteCore

struct PipelineCriticalPathCoverageTests {
    @Test
    func pipelineProgressFactories_setStagesAndValues() {
        let extraction = MeetingExtraction(
            title: "Weekly Sync",
            date: "2025-12-19",
            summary: "",
            decisions: [],
            actionItems: [],
            openQuestions: [],
            keyPoints: []
        )

        let downloading = PipelineProgress.downloadingModels(fractionCompleted: 0.1)
        expectEqual(downloading.stage, .downloadingModels)
        expectEqual(downloading.fractionCompleted, 0.1)
        #expect(downloading.extraction == nil)

        let transcribing = PipelineProgress.transcribing(fractionCompleted: 0.4)
        expectEqual(transcribing.stage, .transcribing)
        expectEqual(transcribing.fractionCompleted, 0.4)

        let summarizing = PipelineProgress.summarizing(fractionCompleted: 0.7)
        expectEqual(summarizing.stage, .summarizing)
        expectEqual(summarizing.fractionCompleted, 0.7)

        let writing = PipelineProgress.writing(fractionCompleted: 1.0, extraction: extraction)
        expectEqual(writing.stage, .writing)
        expectEqual(writing.fractionCompleted, 1.0)
        expectEqual(writing.extraction?.title, "Weekly Sync")
    }
}
