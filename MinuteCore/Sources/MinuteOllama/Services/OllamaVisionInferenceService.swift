import Foundation
import MinuteCore

public struct OllamaVisionInferenceService: ScreenContextInferencing {
    public var maxTokens: Int
    public var modelTag: String
    public var client: OllamaAPIClient

    public init(
        modelTag: String,
        maxTokens: Int = 256,
        client: OllamaAPIClient = OllamaAPIClient()
    ) {
        self.maxTokens = maxTokens
        self.modelTag = modelTag
        self.client = client
    }

    public func inferScreenContext(from imageData: Data, windowTitle: String) async throws -> ScreenContextInference {
        let encodedImage = imageData.base64EncodedString()
        let response = try await client.chat(
            modelTag: modelTag,
            messages: [
                OllamaAPIClient.ChatMessage(
                    role: "user",
                    content: prompt(for: windowTitle),
                    images: [encodedImage]
                )
            ],
            options: OllamaAPIClient.GenerateOptions(
                temperature: 0.1,
                topP: 0.9,
                seed: 42,
                numPredict: maxTokens
            )
        )

        return ScreenContextInference(text: response.trimmingCharacters(in: .whitespacesAndNewlines))
    }
}

private extension OllamaVisionInferenceService {
    func prompt(for windowTitle: String) -> String {
        """
        Analyze this screenshot from the window titled "\(windowTitle)".
        Return a concise plain-text screen context summary for meeting notes.
        Focus on agenda items, participant names, visible headings, and shared artifacts.
        If nothing useful is visible, return an empty string.
        Do not include markdown fences.
        """
    }
}
