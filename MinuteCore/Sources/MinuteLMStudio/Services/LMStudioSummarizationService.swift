import Foundation
import MinuteCore

public struct LMStudioSummarizationService: SummarizationServicing {
    public var maxTokens: Int
    public var modelIdentifier: String
    public var client: LMStudioAPIClient

    public init(
        modelIdentifier: String,
        maxTokens: Int = 1_024,
        client: LMStudioAPIClient = LMStudioAPIClient()
    ) {
        self.modelIdentifier = modelIdentifier
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
        return try await client.complete(
            modelIdentifier: modelIdentifier,
            systemPrompt: prompts.systemPrompt,
            prompt: PromptFactory.userPrompt(
                transcript: datedTranscript(transcript, meetingDate: meetingDate),
                preamble: prompts.userPromptPreamble
            ),
            maxTokens: maxTokens
        )
    }

    public func classify(transcript: String) async throws -> MeetingType {
        let response = try await client.complete(
            modelIdentifier: modelIdentifier,
            systemPrompt: nil,
            prompt: MeetingTypeClassifier.prompt(for: transcript),
            maxTokens: 16
        )
        return MeetingTypeClassifier.parseResponse(response)
    }

    public func classify(
        transcript: String,
        candidates: [MeetingTypeClassifierCandidate],
        fallbackTypeID: String
    ) async throws -> String {
        let fallbackLabel = candidates.first(where: { $0.typeId == fallbackTypeID })?.label ?? "General"
        let response = try await client.complete(
            modelIdentifier: modelIdentifier,
            systemPrompt: nil,
            prompt: MeetingTypeClassifier.prompt(
                for: transcript,
                candidates: candidates,
                fallbackLabel: fallbackLabel
            ),
            maxTokens: 32
        )
        return MeetingTypeClassifier.parseResponse(
            response,
            candidates: candidates,
            fallbackTypeID: fallbackTypeID
        )
    }

    public func repairJSON(_ invalidJSON: String) async throws -> String {
        try await client.complete(
            modelIdentifier: modelIdentifier,
            systemPrompt: nil,
            prompt: repairPrompt(invalidJSON),
            maxTokens: maxTokens
        )
    }
}

private extension LMStudioSummarizationService {
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
