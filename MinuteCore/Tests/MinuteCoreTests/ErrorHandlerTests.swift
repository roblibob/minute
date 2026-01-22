import XCTest
@testable import MinuteCore

final class ErrorHandlerTests: XCTestCase {
    private struct SampleError: Error {}

    func testUserMessage_prefersMinuteErrorDescription() {
        let message = ErrorHandler.userMessage(for: MinuteError.whisperMissing, fallback: "Fallback")
        XCTAssertEqual(message, "Transcription component is missing.")
    }

    func testUserMessage_usesFallbackForUnknownError() {
        let message = ErrorHandler.userMessage(for: SampleError(), fallback: "Something went wrong.")
        XCTAssertEqual(message, "Something went wrong.")
    }

    func testDebugMessage_prefersMinuteErrorSummary() {
        let message = ErrorHandler.debugMessage(
            for: MinuteError.whisperFailed(exitCode: 1, output: "stderr")
        )
        XCTAssertEqual(message, "whisper failed (exitCode=1)\nstderr")
    }

    func testMinuteError_returnsFallbackForUnknownError() {
        let minuteError = ErrorHandler.minuteError(for: SampleError(), fallback: .vaultWriteFailed)
        if case .vaultWriteFailed = minuteError {
            return
        }
        XCTFail("Expected fallback MinuteError.vaultWriteFailed")
    }
}
