import Foundation
import Testing
@testable import MinuteCore

struct PromptFactoryLanguageProcessingTests {
    @Test
    func systemPrompt_appendsLanguageProcessingAndOutputLanguageInstructions_withTrailingNewline() {
        let strategy = GeneralPromptStrategy()
        let processingInstruction = LanguageProcessingProfile.autoToEnglish
            .summarizationSystemInstruction
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let outputInstruction = OutputLanguage.japaneseJapan
            .summarizationSystemInstruction
            .trimmingCharacters(in: .whitespacesAndNewlines)

        let result = PromptFactory.systemPrompt(
            strategy: strategy,
            languageProcessing: .autoToEnglish,
            outputLanguage: .japaneseJapan
        )

        #expect(result.contains("### CORE INSTRUCTIONS"))
        #expect(result.contains(processingInstruction))
        #expect(result.contains(outputInstruction))
        #expect(result.hasSuffix("\n\n\(processingInstruction)\n\n\(outputInstruction)\n"))
    }

    @Test
    func systemPrompt_usesDifferentInstruction_forDifferentProfiles() {
        let strategy = GeneralPromptStrategy()

        let english = PromptFactory.systemPrompt(strategy: strategy, languageProcessing: .autoToEnglish)
        let preserve = PromptFactory.systemPrompt(strategy: strategy, languageProcessing: .autoPreserve)

        #expect(english != preserve)
        #expect(english.contains(LanguageProcessingProfile.autoToEnglish.summarizationSystemInstruction))
        #expect(!english.contains(LanguageProcessingProfile.autoPreserve.summarizationSystemInstruction))

        #expect(preserve.contains(LanguageProcessingProfile.autoPreserve.summarizationSystemInstruction))
        #expect(!preserve.contains(LanguageProcessingProfile.autoToEnglish.summarizationSystemInstruction))
    }

    @Test
    func promptStrategies_doNotHardcodeEnglishOutputLanguage() {
        for meetingType in MeetingType.allCases {
            let prompt = PromptFactory.strategy(for: meetingType).systemPrompt()
            #expect(!prompt.contains("output summary in English"))
            #expect(!prompt.contains("output the summary in English"))
            #expect(!prompt.contains("Always output the summary in English"))
        }
    }

    @Test
    func outputLanguageInstruction_isExplicitInSystemPrompt() {
        let prompt = PromptFactory.systemPrompt(
            strategy: GeneralPromptStrategy(),
            languageProcessing: .autoPreserve,
            outputLanguage: .germanGermany
        )

        #expect(prompt.contains("Output language requirement:"))
        #expect(prompt.contains("MANDATORY RULE"))
        #expect(prompt.contains(OutputLanguage.germanGermany.displayName))
        #expect(prompt.contains(OutputLanguage.germanGermany.rawValue))
        #expect(prompt.contains("overrides conflicting language output instructions"))
    }

    @Test
    func outputLanguageUserInstruction_isExplicit() {
        let instruction = OutputLanguage.portugueseBrazil.summarizationUserInstruction

        #expect(instruction.contains(OutputLanguage.portugueseBrazil.displayName))
        #expect(instruction.contains(OutputLanguage.portugueseBrazil.rawValue))
        #expect(instruction.contains("Apply this to all JSON string values"))
    }
}
