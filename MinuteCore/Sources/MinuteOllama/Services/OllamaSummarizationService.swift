import Foundation
import MinuteCore

public struct OllamaSummarizationService: SummarizationServicing {
    public var maxTokens: Int
    public var modelTag: String
    public var client: OllamaAPIClient

    public init(
        modelTag: String,
        maxTokens: Int = 1_024,
        client: OllamaAPIClient = OllamaAPIClient()
    ) {
        self.modelTag = modelTag
        self.maxTokens = maxTokens
        self.client = client
    }

    public func summarize(
        transcript: String,
        meetingDate: Date,
        meetingType: MeetingType,
        languageProcessing: LanguageProcessingProfile,
        outputLanguage: OutputLanguage
    ) async throws -> String {
        try await summarize(
            transcript: transcript,
            meetingDate: meetingDate,
            meetingType: meetingType,
            languageProcessing: languageProcessing,
            outputLanguage: outputLanguage,
            resolvedPromptBundle: nil
        )
    }

    public func summarize(
        transcript: String,
        meetingDate: Date,
        meetingType: MeetingType,
        languageProcessing: LanguageProcessingProfile,
        outputLanguage: OutputLanguage,
        resolvedPromptBundle: ResolvedPromptBundle?
    ) async throws -> String {
        let prompts = resolvedPrompts(
            meetingType: meetingType,
            languageProcessing: languageProcessing,
            outputLanguage: outputLanguage,
            resolvedPromptBundle: resolvedPromptBundle
        )
        return try await client.generate(
            modelTag: modelTag,
            prompt: PromptFactory.userPrompt(
                transcript: datedTranscript(transcript, meetingDate: meetingDate),
                preamble: prompts.userPromptPreamble
            ),
            systemPrompt: prompts.systemPrompt,
            format: "json",
            options: OllamaAPIClient.GenerateOptions(
                temperature: 0.2,
                topP: 0.9,
                topK: 40,
                seed: 42,
                numPredict: maxTokens
            )
        )
    }

    public func classify(transcript: String) async throws -> MeetingType {
        let response = try await client.generate(
            modelTag: modelTag,
            prompt: MeetingTypeClassifier.prompt(for: transcript),
            options: OllamaAPIClient.GenerateOptions(
                temperature: 0.0,
                seed: 42,
                numPredict: 16
            )
        )
        return MeetingTypeClassifier.parseResponse(response)
    }

    public func classify(
        transcript: String,
        candidates: [MeetingTypeClassifierCandidate],
        fallbackTypeID: String
    ) async throws -> String {
        let fallbackLabel = candidates.first(where: { $0.typeId == fallbackTypeID })?.label ?? "General"
        let response = try await client.generate(
            modelTag: modelTag,
            prompt: MeetingTypeClassifier.prompt(
                for: transcript,
                candidates: candidates,
                fallbackLabel: fallbackLabel
            ),
            options: OllamaAPIClient.GenerateOptions(
                temperature: 0.0,
                seed: 42,
                numPredict: 32
            )
        )
        return MeetingTypeClassifier.parseResponse(
            response,
            candidates: candidates,
            fallbackTypeID: fallbackTypeID
        )
    }

    public func repairJSON(_ invalidJSON: String) async throws -> String {
        try await client.generate(
            modelTag: modelTag,
            prompt: repairPrompt(invalidJSON),
            format: "json",
            options: OllamaAPIClient.GenerateOptions(
                temperature: 0.0,
                seed: 42,
                numPredict: maxTokens
            )
        )
    }
}

private extension OllamaSummarizationService {
    func resolvedPrompts(
        meetingType: MeetingType,
        languageProcessing: LanguageProcessingProfile,
        outputLanguage: OutputLanguage,
        resolvedPromptBundle: ResolvedPromptBundle?
    ) -> (systemPrompt: String, userPromptPreamble: String) {
        if let resolvedPromptBundle {
            return (
                systemPrompt: resolvedPromptBundle.systemPrompt,
                userPromptPreamble: resolvedPromptBundle.userPromptPreamble
            )
        }

        let strategy = PromptFactory.strategy(for: meetingType)
        return (
            systemPrompt: PromptFactory.systemPrompt(
                strategy: strategy,
                languageProcessing: languageProcessing,
                outputLanguage: outputLanguage
            ),
            userPromptPreamble: PromptFactory.userPromptPreamble(
                strategy: strategy,
                languageProcessing: languageProcessing,
                outputLanguage: outputLanguage
            )
        )
    }

    func datedTranscript(_ transcript: String, meetingDate: Date) -> String {
        "Meeting Date: \(MinuteISODate.format(meetingDate))\n\n\(transcript)"
    }

    func repairPrompt(_ invalidJSON: String) -> String {
        """
        Repair the following invalid JSON so it becomes one valid JSON object.
        Preserve the intended meaning.
        Do not add markdown fences or commentary.

        Invalid JSON:
        \(invalidJSON)
        """
    }
}
