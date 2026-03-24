import Foundation
import MinuteCore
import Testing
@testable import Minute

struct MeetingPipelineViewModelScreenContextAlertsTests {
    @Test
    func sharedWindowClosed_setsAlert_andCoexistsWithSilenceWarning() async throws {
        let audioService = AutoSilenceAudioService()

        let suiteName = "MeetingPipelineViewModelScreenContextAlertsTests"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)
        let stagePreferencesStore = StagePreferencesStore(defaults: defaults)
        stagePreferencesStore.clear()

        let coordinatorVaultAccess = VaultAccess(bookmarkStore: InMemoryVaultBookmarkStore(bookmark: nil))
        let viewModelVaultAccess = VaultAccess(bookmarkStore: InMemoryVaultBookmarkStore(bookmark: nil))
        let summarizationServiceProvider: @Sendable () -> any SummarizationServicing = { MockSummarizationService() }

        let coordinator = MeetingPipelineCoordinator(
            transcriptionService: MockTranscriptionService(),
            diarizationService: MockDiarizationService(),
            summarizationServiceProvider: summarizationServiceProvider,
            modelManager: MockModelManager(),
            vaultAccess: coordinatorVaultAccess,
            vaultWriter: DefaultVaultWriter()
        )

        let alertNotifier = await MainActor.run { MockRecordingAlertNotifier() }
        let shortPolicy = SilenceDetectionPolicy(
            silenceDurationSeconds: 0.15,
            warningCountdownSeconds: 0.6,
            rmsSilenceThreshold: 0.8,
            transientToleranceSeconds: 0
        )

        var model: MeetingPipelineViewModel? = await MainActor.run {
            MeetingPipelineViewModel(
                audioService: audioService,
                mediaImportService: MockMediaImportService(),
                recoveryService: MockRecordingRecoveryService(),
                pipelineCoordinator: coordinator,
                screenContextCaptureService: ScreenContextCaptureService(inferencer: MockScreenContextInferenceService()),
                screenContextVideoExtractor: ScreenContextVideoFrameExtractor(inferencer: MockScreenContextInferenceService()),
                screenContextSettingsStore: ScreenContextSettingsStore(),
                vaultAccess: viewModelVaultAccess,
                recordingPermissions: .alwaysGranted(),
                stagePreferencesStore: stagePreferencesStore,
                silenceDetectionPolicy: shortPolicy,
                recordingAlertNotifier: alertNotifier
            )
        }

        await MainActor.run {
            model?.send(.startRecording)
        }

        try await eventually(timeoutNanoseconds: 2_000_000_000) {
            await MainActor.run {
                model?.activeSilenceAlert != nil
            }
        }

        await MainActor.run {
            model?._testHandleScreenContextLifecycleEvent(
                ScreenContextLifecycleEvent(type: .sharedWindowClosed, windowTitle: "Slides")
            )
        }

        let bothVisible = await MainActor.run {
            guard let model else { return false }
            return model.activeSilenceAlert != nil && model.activeScreenContextAlert != nil
        }
        #expect(bothVisible)

        await MainActor.run {
            model?.keepRecordingFromWarning()
        }

        try await eventually(timeoutNanoseconds: 1_500_000_000) {
            await MainActor.run {
                guard let model else { return false }
                return model.activeSilenceAlert == nil
            }
        }

        let sawScreenContextEvent = await MainActor.run {
            guard let model else { return false }
            return model.recordingSessionEvents.contains { $0.eventType == .screenWindowClosedNotified }
        }
        #expect(sawScreenContextEvent)

        await MainActor.run {
            model?.send(.cancelRecording)
            model = nil
        }
    }

    @Test
    func invalidVisionConfiguration_showsActionableAlertWithoutBlockingRecording() async throws {
        let suiteName = "MeetingPipelineViewModelScreenContextAlertsTests.invalid.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)
        let stagePreferencesStore = StagePreferencesStore(defaults: defaults)
        stagePreferencesStore.clear()

        let coordinatorVaultAccess = VaultAccess(bookmarkStore: InMemoryVaultBookmarkStore(bookmark: nil))
        let viewModelVaultAccess = VaultAccess(bookmarkStore: InMemoryVaultBookmarkStore(bookmark: nil))
        let coordinator = MeetingPipelineCoordinator(
            transcriptionService: MockTranscriptionService(),
            diarizationService: MockDiarizationService(),
            summarizationServiceProvider: { MockSummarizationService() },
            modelManager: MockModelManager(),
            vaultAccess: coordinatorVaultAccess,
            vaultWriter: DefaultVaultWriter()
        )
        let selection = ScreenContextWindowSelection(
            bundleIdentifier: "com.apple.Keynote",
            applicationName: "Keynote",
            windowTitle: "Slides"
        )

        let model = await MainActor.run {
            MeetingPipelineViewModel(
                audioService: MockAudioService(),
                mediaImportService: MockMediaImportService(),
                recoveryService: MockRecordingRecoveryService(),
                pipelineCoordinator: coordinator,
                screenContextCaptureService: ScreenContextCaptureService(inferencer: MockScreenContextInferenceService()),
                screenContextVideoExtractor: ScreenContextVideoFrameExtractor(inferencer: MockScreenContextInferenceService()),
                screenContextSettingsStore: ScreenContextSettingsStore(),
                vaultAccess: viewModelVaultAccess,
                recordingPermissions: .alwaysGranted(),
                stagePreferencesStore: stagePreferencesStore,
                visionAvailabilityProvider: {
                    CapabilityAvailabilityState(
                        capabilityID: .vision,
                        providerID: .ollama,
                        isReady: false,
                        status: .visionUnsupported,
                        message: "Selected Ollama model does not advertise vision support.",
                        selectedReference: "phi4-mini"
                    )
                }
            )
        }

        await MainActor.run {
            model.send(.startRecordingWithWindow(selection))
        }

        try await eventually(timeoutNanoseconds: 1_500_000_000) {
            await MainActor.run {
                model.captureState == .recording && model.activeScreenContextAlertMessage != nil
            }
        }

        let message = await MainActor.run {
            model.activeScreenContextAlertMessage
        }
        #expect(message?.contains("does not advertise vision support") == true)

        await MainActor.run {
            model.send(.cancelRecording)
        }
    }
}
