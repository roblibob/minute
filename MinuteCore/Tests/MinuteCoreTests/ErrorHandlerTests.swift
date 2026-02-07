import Testing
import Foundation
@testable import MinuteCore

struct ErrorHandlerTests {
    private struct SampleError: Error {}

    @Test
    func userMessage_prefersMinuteErrorDescription() {
        let message = ErrorHandler.userMessage(for: MinuteError.whisperMissing, fallback: "Fallback")
        expectEqual(message, "Transcription component is missing.")
    }

    @Test
    func userMessage_usesFallbackForUnknownError() {
        let message = ErrorHandler.userMessage(for: SampleError(), fallback: "Something went wrong.")
        expectEqual(message, "Something went wrong.")
    }

    @Test
    func debugMessage_prefersMinuteErrorSummary() {
        let message = ErrorHandler.debugMessage(
            for: MinuteError.whisperFailed(exitCode: 1, output: "stderr")
        )
        expectEqual(message, "whisper failed (exitCode=1)\nstderr")
    }

    @Test
    func minuteError_returnsFallbackForUnknownError() {
        let minuteError = ErrorHandler.minuteError(for: SampleError(), fallback: .vaultWriteFailed)
        if case .vaultWriteFailed = minuteError {
            return
        }
        #expect(Bool(false))
    }
}
