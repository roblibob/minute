import Foundation
import MinuteCore
import Testing

struct RecordingAlertModelsTests {
    @Test
    func silencePolicy_defaultsAreValid() {
        let policy = SilenceDetectionPolicy.default
        #expect(policy.silenceDurationSeconds == 120)
        #expect(policy.warningCountdownSeconds == 30)
        #expect(policy.isValid)
    }

    @Test
    func silenceWarning_requiresExpiry() {
        let sessionID = UUID()

        let valid = RecordingAlert(
            type: .silenceStopWarning,
            sessionID: sessionID,
            message: "Recording will stop in 30 seconds.",
            expiresAt: Date().addingTimeInterval(30),
            actions: [.keepRecording]
        )
        #expect(valid.isValid)

        let invalid = RecordingAlert(
            type: .silenceStopWarning,
            sessionID: sessionID,
            message: "Recording will stop in 30 seconds.",
            expiresAt: nil,
            actions: [.keepRecording]
        )
        #expect(!invalid.isValid)
    }

    @Test
    func screenWindowClosed_forbidsExpiry() {
        let sessionID = UUID()

        let valid = RecordingAlert(
            type: .screenWindowClosed,
            sessionID: sessionID,
            message: "Shared window closed.",
            actions: [.acknowledge]
        )
        #expect(valid.isValid)

        let invalid = RecordingAlert(
            type: .screenWindowClosed,
            sessionID: sessionID,
            message: "Shared window closed.",
            expiresAt: Date(),
            actions: [.acknowledge]
        )
        #expect(!invalid.isValid)
    }

    @Test
    func screenWindowClosedStopWarning_requiresExpiry() {
        let sessionID = UUID()

        let valid = RecordingAlert(
            type: .screenWindowClosedStopWarning,
            sessionID: sessionID,
            message: "Shared window closed. Recording will stop in 30 seconds.",
            expiresAt: Date().addingTimeInterval(30),
            actions: [.keepRecording]
        )
        #expect(valid.isValid)

        let invalid = RecordingAlert(
            type: .screenWindowClosedStopWarning,
            sessionID: sessionID,
            message: "Shared window closed. Recording will stop in 30 seconds.",
            expiresAt: nil,
            actions: [.keepRecording]
        )
        #expect(!invalid.isValid)
    }

    @Test
    func screenContextConfigurationFailure_forbidsExpiry() {
        let sessionID = UUID()

        let valid = RecordingAlert(
            type: .screenContextConfigurationFailure,
            sessionID: sessionID,
            message: "Selected Ollama model does not advertise vision support.",
            actions: [.acknowledge]
        )
        #expect(valid.isValid)

        let invalid = RecordingAlert(
            type: .screenContextConfigurationFailure,
            sessionID: sessionID,
            message: "Selected Ollama model does not advertise vision support.",
            expiresAt: Date(),
            actions: [.acknowledge]
        )
        #expect(!invalid.isValid)
    }

    @Test
    func silenceSnapshot_warningRemainingSeconds_returnsZeroOrMore() {
        let snapshot = SilenceStatusSnapshot(
            sessionID: UUID(),
            phase: .warningActive,
            silenceAccumulatedSeconds: 120,
            warningStartedAt: Date(),
            warningDeadlineAt: Date().addingTimeInterval(2),
            pendingAutoStop: true
        )

        let remaining = snapshot.warningRemainingSeconds
        #expect(remaining != nil)
        if let remaining {
            #expect(remaining >= 0)
        }
    }
}
