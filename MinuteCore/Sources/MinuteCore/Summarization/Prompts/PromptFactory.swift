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
        }
    }

    public static func systemPrompt(
        strategy: PromptStrategy,
        languageProcessing: LanguageProcessingProfile,
        outputLanguage: OutputLanguage = .defaultSelection
    ) -> String {
        let base = strategy.systemPrompt().trimmingCharacters(in: .whitespacesAndNewlines)
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
}
