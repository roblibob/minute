import Testing
@testable import MinuteCore

struct MeetingTypeClassifierPromptTests {

    @Test
    func prompt_containsExplicitDefaultToGeneralRule() {
        let prompt = MeetingTypeClassifier.prompt(for: "Hello")
        let lower = prompt.lowercased()

        #expect(lower.contains("uncertain"))
        #expect(prompt.contains("General"))
        #expect(lower.contains("return") && lower.contains("only"))
    }

    @Test
    func prompt_containsAllAllowedLabelsAsExactOutputs() {
        let prompt = MeetingTypeClassifier.prompt(for: "Hello")

        for label in ["General", "Standup", "Design Review", "One-on-One", "Presentation", "Planning"] {
            #expect(prompt.contains(label))
        }
    }

    @Test
    func prompt_isBoundedForVeryLongInput() {
        let longInput = String(repeating: "A", count: 5_000) + String(repeating: "B", count: 5_000)
        let prompt = MeetingTypeClassifier.prompt(for: longInput)

        #expect(prompt.count <= 20_000)
        #expect(prompt.contains(String(repeating: "A", count: 200)))
        #expect(!prompt.contains(String(repeating: "B", count: 200)))
    }
}
