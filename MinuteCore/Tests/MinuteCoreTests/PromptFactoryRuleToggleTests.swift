import Testing
@testable import MinuteCore

struct PromptFactoryRuleToggleTests {
    @Test
    func systemPrompt_omitsDisabledRulesAndOutputFields() {
        let components = PromptLibraryFixture.promptComponents(
            objective: "Summarize accurately.",
            summaryFocus: "Capture clear outcomes.",
            decisionRulesEnabled: false,
            decisionRules: "Capture only confirmed decisions.",
            actionItemRulesEnabled: true,
            actionItemRules: "Extract owner and task.",
            openQuestionRulesEnabled: false,
            openQuestionRules: "Capture unresolved concerns.",
            keyPointRulesEnabled: true,
            keyPointRules: "Preserve key context.",
            noiseFilterRules: "Ignore greetings.",
            additionalGuidance: "Stay concise."
        )

        let prompt = PromptFactory.systemPrompt(
            promptComponents: components,
            languageProcessing: .autoToEnglish,
            outputLanguage: .defaultSelection
        )

        #expect(prompt.contains("### ACTION ITEM RULES"))
        #expect(prompt.contains("### KEY POINT RULES"))
        #expect(!prompt.contains("### DECISION RULES"))
        #expect(!prompt.contains("### OPEN QUESTION RULES"))

        #expect(prompt.contains("- action_items (array of objects with owner, task, due_date, status, and comments)"))
        #expect(prompt.contains("- participants (array of objects with name and role"))
        #expect(prompt.contains("- topics (array of objects with title and points"))
        #expect(prompt.contains("- key_points (array of string)"))
        #expect(!prompt.contains("- decisions (array of string)"))
        #expect(!prompt.contains("- open_questions (array of string)"))

        #expect(prompt.contains("### NOISE FILTER RULES"))
        #expect(prompt.contains("### ADDITIONAL GUIDANCE"))
    }

    @Test
    func systemPrompt_whenAllToggleableRulesDisabled_usesBaseSchemaOnly() {
        let components = PromptLibraryFixture.promptComponents(
            objective: "Summarize accurately.",
            summaryFocus: "Capture clear outcomes.",
            decisionRulesEnabled: false,
            actionItemRulesEnabled: false,
            openQuestionRulesEnabled: false,
            keyPointRulesEnabled: false
        )

        let prompt = PromptFactory.systemPrompt(
            promptComponents: components,
            languageProcessing: .autoToEnglish,
            outputLanguage: .defaultSelection
        )

        #expect(prompt.contains("- title (string)"))
        #expect(prompt.contains("- date (YYYY-MM-DD)"))
        #expect(prompt.contains("- summary (string)"))
        #expect(!prompt.contains("- decisions (array of string)"))
        #expect(!prompt.contains("- action_items (array of objects with owner and task)"))
        #expect(!prompt.contains("- open_questions (array of string)"))
        #expect(!prompt.contains("- key_points (array of string)"))
    }
}
