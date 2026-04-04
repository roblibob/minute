import Foundation
import MinuteCore

public struct LMStudioVisionInferenceService: ScreenContextInferencing {
    public var maxTokens: Int
    public var modelIdentifier: String
    public var client: LMStudioAPIClient

    public init(
        modelIdentifier: String,
        maxTokens: Int = 256,
        client: LMStudioAPIClient = LMStudioAPIClient()
    ) {
        self.maxTokens = maxTokens
        self.modelIdentifier = modelIdentifier
        self.client = client
    }

    public func inferScreenContext(from imageData: Data, windowTitle: String) async throws -> ScreenContextInference {
        let encodedImage = imageData.base64EncodedString()
        let response = try await client.chat(
            modelIdentifier: modelIdentifier,
            messages: [
                LMStudioAPIClient.ChatMessage(
                    role: "user",
                    content: [
                        .text(prompt(for: windowTitle)),
                        .imageDataURL("data:image/png;base64,\(encodedImage)"),
                    ]
                )
            ],
            maxTokens: maxTokens
        )

        return ScreenContextInference(text: response.trimmingCharacters(in: .whitespacesAndNewlines))
    }
}

private extension LMStudioVisionInferenceService {
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
