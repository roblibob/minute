import Foundation
import Testing
@testable import MinuteCore
@testable import MinuteLMStudio
@testable import MinuteOllama

/// Local inference servers (LM Studio, Ollama, or shims in front of them) can
/// legitimately take longer than URLSession's 60-second default to produce a
/// full non-streaming completion. Both clients must use an extended timeout.
struct LocalServerRequestTimeoutTests {

    @Test
    func timeoutConstant_isTwoMinutes() {
        #expect(AppConfiguration.Defaults.localServerRequestTimeoutSeconds == 120)
    }

    @Test
    func lmStudioClient_defaultSession_usesExtendedRequestTimeout() {
        let timeout = LMStudioAPIClient.defaultSession.configuration.timeoutIntervalForRequest
        #expect(timeout == AppConfiguration.Defaults.localServerRequestTimeoutSeconds)
    }

    @Test
    func ollamaClient_defaultSession_usesExtendedRequestTimeout() {
        let timeout = OllamaAPIClient.defaultSession.configuration.timeoutIntervalForRequest
        #expect(timeout == AppConfiguration.Defaults.localServerRequestTimeoutSeconds)
    }
}
