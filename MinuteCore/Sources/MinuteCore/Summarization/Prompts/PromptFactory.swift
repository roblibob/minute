//
//  PromptFactory.swift
//  MinuteCore
//
//  Created for Feature 003-meeting-type-prompts
//

import Foundation

public enum PromptFactory {
    /// Returns the appropriate prompt strategy for the given meeting type.
    /// - Parameter type: The selected meeting type.
    /// - Returns: A concrete implementation of `PromptStrategy`.
    public static func strategy(for type: MeetingType) -> PromptStrategy {
        switch type {
        case .general, .autodetect:
            // Autodetect should typically be resolved to a specific type before calling this factory.
            // If it remains .autodetect, we fallback to the General strategy.
            return GeneralPromptStrategy()

        case .standup:
            return StandupPromptStrategy()

        case .presentation:
            return PresentationPromptStrategy()

        case .oneOnOne:
            return OneOnOnePromptStrategy()

        case .planning:
            return PlanningPromptStrategy()

        case .designReview:
            return DesignReviewPromptStrategy()

        case .interviewTaken:
            return InterviewTakenPromptStrategy()

        case .interviewGiven:
            return InterviewGivenPromptStrategy()

        case .allHands:
            return AllHandsPromptStrategy()

        case .retrospective:
            return RetrospectivePromptStrategy()
        }
    }

    public static func systemPrompt(
        strategy: PromptStrategy,
        languageProcessing: LanguageProcessingProfile,
        outputLanguage: OutputLanguage = .defaultSelection
    ) -> String {
        let base = strategy.systemPrompt().trimmingCharacters(in: .whitespacesAndNewlines)
        return appendRuntimeLanguageInstructions(
            base: base,
            languageProcessing: languageProcessing,
            outputLanguage: outputLanguage
        )
    }

    public static func systemPrompt(
        promptComponents: PromptComponentSet,
        languageProcessing: LanguageProcessingProfile,
        outputLanguage: OutputLanguage = .defaultSelection
    ) -> String {
        let components = promptComponents
        let sections = [
            """
            You are an expert automated meeting secretary. Analyze a chronological meeting timeline and generate one structured JSON summary.

            ### MEETING OBJECTIVE
            \(components.objective)
            """,
            """
            ### SUMMARY FOCUS
            \(components.summaryFocus)
            """,
            optionalSection(
                title: "DECISION RULES",
                body: components.decisionRules,
                enabled: components.decisionRulesEnabled
            ),
            optionalSection(
                title: "ACTION ITEM RULES",
                body: components.actionItemRules,
                enabled: components.actionItemRulesEnabled
            ),
            optionalSection(
                title: "OPEN QUESTION RULES",
                body: components.openQuestionRules,
                enabled: components.openQuestionRulesEnabled
            ),
            optionalSection(
                title: "KEY POINT RULES",
                body: components.keyPointRules,
                enabled: components.keyPointRulesEnabled
            ),
            optionalSection(title: "NOISE FILTER RULES", body: components.noiseFilterRules),
            optionalSection(title: "ADDITIONAL GUIDANCE", body: components.additionalGuidance),
            outputFormatSection(for: components)
        ]

        let base = sections
            .compactMap { $0 }
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: "\n\n")

        return appendRuntimeLanguageInstructions(
            base: base,
            languageProcessing: languageProcessing,
            outputLanguage: outputLanguage
        )
    }

    public static func userPromptPreamble(
        strategy: PromptStrategy,
        languageProcessing: LanguageProcessingProfile,
        outputLanguage: OutputLanguage = .defaultSelection
    ) -> String {
        let base = strategy.userPrompt(for: "").trimmingCharacters(in: .whitespacesAndNewlines)
        return applyRuntimeUserInstructions(
            basePreamble: base.isEmpty ? "Timeline follows:" : base,
            languageProcessing: languageProcessing,
            outputLanguage: outputLanguage
        )
    }

    public static func userPromptPreamble(
        promptComponents: PromptComponentSet,
        languageProcessing: LanguageProcessingProfile,
        outputLanguage: OutputLanguage = .defaultSelection
    ) -> String {
        let guidance = promptComponents.additionalGuidance.trimmingCharacters(in: .whitespacesAndNewlines)
        let basePreamble: String
        if guidance.isEmpty {
            basePreamble = "Timeline follows:"
        } else {
            basePreamble = "Additional guidance: \(guidance)\n\nTimeline follows:"
        }
        return applyRuntimeUserInstructions(
            basePreamble: basePreamble,
            languageProcessing: languageProcessing,
            outputLanguage: outputLanguage
        )
    }

    public static func userPrompt(
        transcript: String,
        preamble: String
    ) -> String {
        let trimmedPreamble = preamble.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedTranscript = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedPreamble.isEmpty {
            return trimmedTranscript
        }
        if trimmedTranscript.isEmpty {
            return trimmedPreamble
        }
        return trimmedPreamble + "\n" + trimmedTranscript
    }

    private static func appendRuntimeLanguageInstructions(
        base: String,
        languageProcessing: LanguageProcessingProfile,
        outputLanguage: OutputLanguage
    ) -> String {
        let languageProcessingInstruction = languageProcessing
            .summarizationSystemInstruction
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let outputLanguageInstruction = outputLanguage
            .summarizationSystemInstruction
            .trimmingCharacters(in: .whitespacesAndNewlines)

        let instructions = [languageProcessingInstruction, outputLanguageInstruction]
            .filter { !$0.isEmpty }
            .joined(separator: "\n\n")
        guard !instructions.isEmpty else { return base }

        return base + "\n\n" + instructions + "\n"
    }

    private static func applyRuntimeUserInstructions(
        basePreamble: String,
        languageProcessing: LanguageProcessingProfile,
        outputLanguage: OutputLanguage
    ) -> String {
        let languageProcessingUserInstruction = languageProcessing
            .summarizationUserInstruction
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let outputLanguageUserInstruction = outputLanguage
            .summarizationUserInstruction
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let runtimeInstructions = [languageProcessingUserInstruction, outputLanguageUserInstruction]
            .filter { !$0.isEmpty }
            .joined(separator: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        if runtimeInstructions.isEmpty {
            return basePreamble
        }
        return runtimeInstructions + "\n\n" + basePreamble
    }

    private static func outputFormatSection(for components: PromptComponentSet) -> String {
        var fields: [String] = [
            "- title (string)",
            "- date (YYYY-MM-DD)",
            "- summary (string)",
            "- participants (array of objects with name and role; use Speaker N when the real name is not inferable)",
            "- topics (array of objects with title and points, capturing each distinct topic discussed)",
        ]

        if components.decisionRulesEnabled {
            fields.append("- decisions (array of string)")
        }
        if components.actionItemRulesEnabled {
            fields.append("- action_items (array of objects with owner, task, due_date, status, and comments)")
        }
        if components.openQuestionRulesEnabled {
            fields.append("- open_questions (array of string)")
        }
        if components.keyPointRulesEnabled {
            fields.append("- key_points (array of string)")
        }

        return """
        ### OUTPUT FORMAT
        Return one valid JSON object with exactly these fields:
        \(fields.joined(separator: "\n"))

        ### CRITICAL RULES
        - Use only information present in the timeline.
        - For every enabled array field above, return an empty array when evidence is missing.
        - Do not output markdown fences or extra prose outside JSON.
        """
    }

    private static func optionalSection(title: String, body: String, enabled: Bool = true) -> String? {
        guard enabled else { return nil }
        let trimmed = body.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return """
        ### \(title)
        \(trimmed)
        """
    }
}
