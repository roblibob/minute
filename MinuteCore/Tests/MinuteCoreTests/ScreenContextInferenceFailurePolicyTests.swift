import Foundation
import Testing
@testable import MinuteCore

struct ScreenContextInferenceFailurePolicyTests {
    @Test
    func imageTokenMismatch_isTerminalAndActionable() {
        let error = MinuteError.llamaMTMDFailed(
            exitCode: 400,
            output: "Error in iterating prediction stream: ValueError: Number of image token positions (1450) does not match number of image features (448) for batch 0"
        )

        let message = ScreenContextInferenceFailurePolicy.terminalMessage(for: error)

        #expect(message?.contains("could not process image input") == true)
        #expect(message?.contains("Number of image token positions") == true)
    }

    @Test
    func unrelatedFailure_isNotTerminal() {
        let error = MinuteError.llamaMTMDFailed(
            exitCode: 1,
            output: "temporary transport failure"
        )

        #expect(ScreenContextInferenceFailurePolicy.terminalMessage(for: error) == nil)
    }
}
