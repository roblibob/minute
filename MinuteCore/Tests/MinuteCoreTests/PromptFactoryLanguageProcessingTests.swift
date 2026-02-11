import Foundation
import Testing
@testable import MinuteCore

struct PromptFactoryLanguageProcessingTests {
    @Test
    func systemPrompt_appendsLanguageProcessingInstruction_withTrailingNewline() {
        let strategy = GeneralPromptStrategy()
        let instruction = LanguageProcessingProfile.autoToEnglish
            .summarizationSystemInstruction
            .trimmingCharacters(in: .whitespacesAndNewlines)

        let result = PromptFactory.systemPrompt(strategy: strategy, languageProcessing: .autoToEnglish)

        #expect(result.contains("### CORE INSTRUCTIONS"))
        #expect(result.contains(instruction))
        #expect(result.hasSuffix("\n\n\(instruction)\n"))
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
    func languageInstruction_autoPreserve_requiresTranscriptionLanguageOutput() {
        let prompt = PromptFactory.systemPrompt(
            strategy: GeneralPromptStrategy(),
            languageProcessing: .autoPreserve
        )

        #expect(prompt.contains("Language output mode: Auto -> Preserve."))
        #expect(prompt.contains("Determine the dominant language from the transcription text"))
        #expect(prompt.contains("Do not translate to English unless the transcription is predominantly English."))
    }

    @Test
    func languageInstruction_autoEnglish_forcesEnglishOutput() {
        let prompt = PromptFactory.systemPrompt(
            strategy: GeneralPromptStrategy(),
            languageProcessing: .autoToEnglish
        )

        #expect(prompt.contains("Language output mode: Auto -> English."))
        #expect(prompt.contains("MANDATORY RULE"))
        #expect(prompt.contains("ALWAYS write all user-visible JSON values"))
        #expect(prompt.contains("in English"))
    }

    @Test
    func languageUserInstruction_autoPreserve_forbidsForcedEnglishTranslation() {
        let instruction = LanguageProcessingProfile.autoPreserve.summarizationUserInstruction

        #expect(instruction.contains("Detect the dominant transcript language"))
        #expect(instruction.contains("do not translate the output to English"))
    }
}
