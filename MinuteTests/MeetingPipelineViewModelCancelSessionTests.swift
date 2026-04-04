import Foundation
import Testing
@testable import Minute
@testable import MinuteCore

struct MeetingPipelineViewModelCancelSessionTests {
    @Test
    func cancelSession_whileRecording_doesNotStopOrEnqueue_andReturnsIdle() async throws {
        let audioService = TestAudioService()

        let suiteName = "MeetingPipelineViewModelCancelSessionTests"
        let dependencies = try PipelineViewModelFixtureBuilder.makeDependencies(suiteName: suiteName)

        var model: MeetingPipelineViewModel? = await MainActor.run {
            return MeetingPipelineViewModel(
                audioService: audioService,
                mediaImportService: MockMediaImportService(),
                recoveryService: MockRecordingRecoveryService(),
                pipelineCoordinator: dependencies.coordinator,
                screenContextCaptureService: ScreenContextCaptureService(inferencer: MockScreenContextInferenceService()),
                screenContextVideoExtractor: ScreenContextVideoFrameExtractor(inferencer: MockScreenContextInferenceService()),
                screenContextSettingsStore: ScreenContextSettingsStore(),
                vaultAccess: dependencies.viewModelVaultAccess,
                recordingPermissions: .alwaysGranted(),
                stagePreferencesStore: dependencies.stagePreferencesStore
            )
        }
        #expect(model != nil)

        await MainActor.run {
            model?.send(.startRecording)
        }

        try await eventually(timeoutNanoseconds: 1_000_000_000) {
            await MainActor.run {
                if let model {
                    if case .recording = model.state { return true }
                }
                return false
            }
        }

        await MainActor.run {
            model?.send(.cancelRecording)
        }

        try await eventually(timeoutNanoseconds: 1_000_000_000) {
            await MainActor.run {
                guard let model else { return false }
                let isIdle: Bool
                if case .idle = model.state {
                    isIdle = true
                } else {
                    isIdle = false
                }
                return isIdle && model.captureState == .ready
            }
        }

        let observed = await audioService.observed
        #expect(observed.startRecordingCalls == 1)
        #expect(observed.cancelRecordingCalls == 1)
        #expect(observed.stopRecordingCalls == 0)

        await MainActor.run {
            model = nil
        }
    }

    @Test
    func startRecording_audioOnly_doesNotRequestScreenRecordingPermission() async throws {
        let audioService = TestAudioService()
        let permissionsProbe = RecordingPermissionProbe()

        let suiteName = "MeetingPipelineViewModelAudioOnlyPermissionTests"
        let dependencies = try PipelineViewModelFixtureBuilder.makeDependencies(suiteName: suiteName)

        let permissions = MeetingPipelineViewModel.RecordingPermissions(
            requestMicrophonePermission: {
                try await permissionsProbe.requestMicrophonePermission()
            },
            requestScreenRecordingPermission: {
                try await permissionsProbe.requestScreenRecordingPermission()
            }
        )

        var model: MeetingPipelineViewModel? = await MainActor.run {
            MeetingPipelineViewModel(
                audioService: audioService,
                mediaImportService: MockMediaImportService(),
                recoveryService: MockRecordingRecoveryService(),
                pipelineCoordinator: dependencies.coordinator,
                screenContextCaptureService: ScreenContextCaptureService(inferencer: MockScreenContextInferenceService()),
                screenContextVideoExtractor: ScreenContextVideoFrameExtractor(inferencer: MockScreenContextInferenceService()),
                screenContextSettingsStore: ScreenContextSettingsStore(),
                vaultAccess: dependencies.viewModelVaultAccess,
                recordingPermissions: permissions,
                stagePreferencesStore: dependencies.stagePreferencesStore
            )
        }
        #expect(model != nil)

        await MainActor.run {
            model?.setScreenCaptureEnabled(false)
        }

        await MainActor.run {
            model?.send(.startRecording)
        }

        try await eventually(timeoutNanoseconds: 1_000_000_000) {
            await MainActor.run {
                guard let model else { return false }
                if case .recording = model.state {
                    return true
                }
                return false
            }
        }

        let permissionSnapshot = await permissionsProbe.snapshot()
        #expect(permissionSnapshot.microphoneRequests == 1)
        #expect(permissionSnapshot.screenRecordingRequests == 0)

        await MainActor.run {
            model?.send(.cancelRecording)
        }

        try await eventually(timeoutNanoseconds: 1_000_000_000) {
            await MainActor.run {
                guard let model else { return false }
                if case .idle = model.state {
                    return model.captureState == .ready
                }
                return false
            }
        }

        await MainActor.run {
            model = nil
        }
    }

    @Test
    func startRecording_whileImportingMedia_isIgnored() async throws {
        let audioService = TestAudioService()
        let importService = BlockingMediaImportService()

        let suiteName = "MeetingPipelineViewModelImportingStartRecordingTests"
        let dependencies = try PipelineViewModelFixtureBuilder.makeDependencies(suiteName: suiteName)

        var model: MeetingPipelineViewModel? = await MainActor.run {
            MeetingPipelineViewModel(
                audioService: audioService,
                mediaImportService: importService,
                recoveryService: MockRecordingRecoveryService(),
                pipelineCoordinator: dependencies.coordinator,
                screenContextCaptureService: ScreenContextCaptureService(inferencer: MockScreenContextInferenceService()),
                screenContextVideoExtractor: ScreenContextVideoFrameExtractor(inferencer: MockScreenContextInferenceService()),
                screenContextSettingsStore: ScreenContextSettingsStore(),
                vaultAccess: dependencies.viewModelVaultAccess,
                recordingPermissions: .alwaysGranted(),
                stagePreferencesStore: dependencies.stagePreferencesStore
            )
        }

        await MainActor.run {
            model?.send(.importFile(URL(fileURLWithPath: "/tmp/input.mov")))
        }

        try await eventually(timeoutNanoseconds: 1_000_000_000) {
            let didStartImport = await importService.didStartImport
            let isImporting = await MainActor.run {
                guard let model else { return false }
                if case .importing = model.state {
                    return true
                }
                return false
            }
            return didStartImport && isImporting
        }

        await MainActor.run {
            model?.send(.startRecording)
        }
        try await Task.sleep(nanoseconds: 200_000_000)

        let observed = await audioService.observed
        #expect(observed.startRecordingCalls == 0)

        let isStillImporting = await MainActor.run {
            guard let model else { return false }
            if case .importing = model.state {
                return true
            }
            return false
        }
        #expect(isStillImporting)

        await importService.finishImport()

        try await eventually(timeoutNanoseconds: 1_000_000_000) {
            await MainActor.run {
                guard let model else { return false }
                if case .recorded = model.state {
                    return true
                }
                return false
            }
        }

        await MainActor.run {
            model = nil
        }
    }

    @Test
    func dismissCloseableStatus_afterFailure_resetsToIdle_andAllowsNewRecording() async throws {
        let suiteName = "MeetingPipelineViewModelCancelSessionTests.failureReset.\(UUID().uuidString)"
        let dependencies = try PipelineViewModelFixtureBuilder.makeDependencies(suiteName: suiteName)
        let audioService = TestAudioService()
        let importService = FailingMediaImportService()

        let model = await MainActor.run {
            MeetingPipelineViewModel(
                audioService: audioService,
                mediaImportService: importService,
                recoveryService: MockRecordingRecoveryService(),
                pipelineCoordinator: dependencies.coordinator,
                screenContextCaptureService: ScreenContextCaptureService(inferencer: MockScreenContextInferenceService()),
                screenContextVideoExtractor: ScreenContextVideoFrameExtractor(inferencer: MockScreenContextInferenceService()),
                screenContextSettingsStore: ScreenContextSettingsStore(),
                vaultAccess: dependencies.viewModelVaultAccess,
                recordingPermissions: .alwaysGranted(),
                stagePreferencesStore: dependencies.stagePreferencesStore
            )
        }

        await MainActor.run {
            model.send(.importFile(URL(fileURLWithPath: "/tmp/failure.wav")))
        }

        try await eventually(timeoutNanoseconds: 1_000_000_000) {
            await MainActor.run {
                if case .failed = model.state { return true }
                return false
            }
        }

        await MainActor.run {
            model.dismissCloseableStatus()
        }

        let isIdleAfterDismiss = await MainActor.run {
            if case .idle = model.state {
                return model.captureState == .ready
            }
            return false
        }
        #expect(isIdleAfterDismiss)

        await MainActor.run {
            model.send(.startRecording)
        }

        try await eventually(timeoutNanoseconds: 1_000_000_000) {
            await MainActor.run {
                if case .recording = model.state { return true }
                return false
            }
        }

        let observed = await audioService.observed
        #expect(observed.startRecordingCalls == 1)

        await MainActor.run {
            model.send(.cancelRecording)
        }
    }

    @Test
    func changingScreenContextSelectionWhileRecording_restartsCaptureSession() async throws {
        let captureService = ScreenContextCaptureService(inferencer: MockScreenContextInferenceService())
        let seededSource = ScreenContextCaptureSource(
            windowTitle: "Seeded Window",
            captureImageData: {
                Data([0x01, 0x02, 0x03, 0x04])
            }
        )
        try await captureService._testStartCapture(
            sources: [seededSource],
            minimumFrameInterval: 1.0
        )
        try await Task.sleep(nanoseconds: 1_200_000_000)

        let audioService = TestAudioService()

        let suiteName = "MeetingPipelineViewModelScreenContextSelectionSwitchTests"
        let dependencies = try PipelineViewModelFixtureBuilder.makeDependencies(suiteName: suiteName)

        var model: MeetingPipelineViewModel? = await MainActor.run {
            MeetingPipelineViewModel(
                audioService: audioService,
                mediaImportService: MockMediaImportService(),
                recoveryService: MockRecordingRecoveryService(),
                pipelineCoordinator: dependencies.coordinator,
                screenContextCaptureService: captureService,
                screenContextVideoExtractor: ScreenContextVideoFrameExtractor(inferencer: MockScreenContextInferenceService()),
                screenContextSettingsStore: ScreenContextSettingsStore(),
                vaultAccess: dependencies.viewModelVaultAccess,
                recordingPermissions: .alwaysGranted(),
                stagePreferencesStore: dependencies.stagePreferencesStore
            )
        }

        await MainActor.run {
            model?.send(.startRecording)
        }

        try await eventually(timeoutNanoseconds: 1_000_000_000) {
            await MainActor.run {
                guard let model else { return false }
                if case .recording = model.state {
                    return true
                }
                return false
            }
        }

        await MainActor.run {
            model?.setScreenCaptureEnabled(true)
            model?.setScreenCaptureSelection(
                ScreenContextWindowSelection(
                    bundleIdentifier: "com.example.switch",
                    applicationName: "Switch App",
                    windowTitle: "Switch Window"
                )
            )
        }

        try await eventually(timeoutNanoseconds: 2_000_000_000) {
            await MainActor.run {
                guard let model else { return false }
                return (model.screenInferenceStatus?.processedCount ?? 0) > 0
            }
        }

        await MainActor.run {
            model?.send(.cancelRecording)
            model = nil
        }
    }

    @Test
    func stopRecording_entersStoppingStateImmediately_beforeStopCompletes() async throws {
        let audioService = SlowStopAudioService(stopDelayNanoseconds: 700_000_000)

        let suiteName = "MeetingPipelineViewModelStoppingStateTests"
        let dependencies = try PipelineViewModelFixtureBuilder.makeDependencies(suiteName: suiteName)

        var model: MeetingPipelineViewModel? = await MainActor.run {
            MeetingPipelineViewModel(
                audioService: audioService,
                mediaImportService: MockMediaImportService(),
                recoveryService: MockRecordingRecoveryService(),
                pipelineCoordinator: dependencies.coordinator,
                screenContextCaptureService: ScreenContextCaptureService(inferencer: MockScreenContextInferenceService()),
                screenContextVideoExtractor: ScreenContextVideoFrameExtractor(inferencer: MockScreenContextInferenceService()),
                screenContextSettingsStore: ScreenContextSettingsStore(),
                vaultAccess: dependencies.viewModelVaultAccess,
                recordingPermissions: .alwaysGranted(),
                stagePreferencesStore: dependencies.stagePreferencesStore
            )
        }

        await MainActor.run {
            model?.send(.startRecording)
        }

        try await eventually(timeoutNanoseconds: 1_000_000_000) {
            await MainActor.run {
                guard let model else { return false }
                if case .recording = model.state {
                    return true
                }
                return false
            }
        }

        await MainActor.run {
            model?.send(.stopRecording)
        }

        let enteredStoppingImmediately = await MainActor.run {
            model?.captureState == .stopping
        }
        #expect(enteredStoppingImmediately)

        try await eventually(timeoutNanoseconds: 2_000_000_000) {
            await MainActor.run { model?.captureState == .ready }
        }

        #expect(await audioService.stopRecordingCalls == 1)

        await MainActor.run {
            model = nil
        }
    }

    @Test
    func quietMicrophoneLevel_updatesVisualizerSamples() async throws {
        let audioService = MeteringAudioService()

        let suiteName = "MeetingPipelineViewModelAudioLevelVisualizerTests"
        let dependencies = try PipelineViewModelFixtureBuilder.makeDependencies(suiteName: suiteName)

        var model: MeetingPipelineViewModel? = await MainActor.run {
            MeetingPipelineViewModel(
                audioService: audioService,
                mediaImportService: MockMediaImportService(),
                recoveryService: MockRecordingRecoveryService(),
                pipelineCoordinator: dependencies.coordinator,
                screenContextCaptureService: ScreenContextCaptureService(inferencer: MockScreenContextInferenceService()),
                screenContextVideoExtractor: ScreenContextVideoFrameExtractor(inferencer: MockScreenContextInferenceService()),
                screenContextSettingsStore: ScreenContextSettingsStore(),
                vaultAccess: dependencies.viewModelVaultAccess,
                recordingPermissions: .alwaysGranted(),
                stagePreferencesStore: dependencies.stagePreferencesStore
            )
        }

        await MainActor.run {
            model?.send(.startRecording)
        }

        try await eventually(timeoutNanoseconds: 1_000_000_000) {
            await MainActor.run {
                guard let model else { return false }
                if case .recording = model.state {
                    return true
                }
                return false
            }
        }

        await audioService.emitLevel(0.02)
        try await Task.sleep(nanoseconds: 80_000_000)
        await audioService.emitLevel(0.03)

        try await eventually(timeoutNanoseconds: 1_000_000_000) {
            await MainActor.run {
                guard let model else { return false }
                return model.audioLevelSamples.contains { $0 > 0.01 }
            }
        }

        await MainActor.run {
            model?.send(.cancelRecording)
            model = nil
        }
    }
}

private actor TestAudioService: AudioServicing, AudioLevelMetering, AudioCaptureControlling {
    struct Observed: Sendable {
        var startRecordingCalls: Int = 0
        var stopRecordingCalls: Int = 0
        var cancelRecordingCalls: Int = 0
    }

    private(set) var observed = Observed()
    private var levelHandler: (@Sendable (Float) -> Void)?

    func startRecording() async throws {
        observed.startRecordingCalls += 1
        levelHandler?(0)
    }

    func cancelRecording() async {
        observed.cancelRecordingCalls += 1
    }

    func stopRecording() async throws -> AudioCaptureResult {
        observed.stopRecordingCalls += 1
        throw MinuteError.audioExportFailed
    }

    func convertToContractWav(inputURL: URL, outputURL: URL) async throws {
        _ = inputURL
        _ = outputURL
    }

    func setLevelHandler(_ handler: (@Sendable (Float) -> Void)?) async {
        levelHandler = handler
    }

    func setMicrophoneEnabled(_ enabled: Bool) async {
        _ = enabled
    }

    func setSystemAudioEnabled(_ enabled: Bool) async {
        _ = enabled
    }
}

private actor SlowStopAudioService: AudioServicing, AudioLevelMetering, AudioCaptureControlling {
    private let stopDelayNanoseconds: UInt64
    private(set) var startRecordingCalls = 0
    private(set) var stopRecordingCalls = 0
    private var levelHandler: (@Sendable (Float) -> Void)?

    init(stopDelayNanoseconds: UInt64) {
        self.stopDelayNanoseconds = stopDelayNanoseconds
    }

    func startRecording() async throws {
        startRecordingCalls += 1
        levelHandler?(0)
    }

    func cancelRecording() async {}

    func stopRecording() async throws -> AudioCaptureResult {
        stopRecordingCalls += 1
        try await Task.sleep(nanoseconds: stopDelayNanoseconds)
        throw MinuteError.audioExportFailed
    }

    func convertToContractWav(inputURL: URL, outputURL: URL) async throws {
        _ = inputURL
        _ = outputURL
    }

    func setLevelHandler(_ handler: (@Sendable (Float) -> Void)?) async {
        levelHandler = handler
    }

    func setMicrophoneEnabled(_ enabled: Bool) async {
        _ = enabled
    }

    func setSystemAudioEnabled(_ enabled: Bool) async {
        _ = enabled
    }
}

private actor MeteringAudioService: AudioServicing, AudioLevelMetering, AudioCaptureControlling {
    private var levelHandler: (@Sendable (Float) -> Void)?

    func startRecording() async throws {}

    func cancelRecording() async {}

    func stopRecording() async throws -> AudioCaptureResult {
        throw MinuteError.audioExportFailed
    }

    func convertToContractWav(inputURL: URL, outputURL: URL) async throws {
        _ = inputURL
        _ = outputURL
    }

    func setLevelHandler(_ handler: (@Sendable (Float) -> Void)?) async {
        levelHandler = handler
    }

    func setMicrophoneEnabled(_ enabled: Bool) async {
        _ = enabled
    }

    func setSystemAudioEnabled(_ enabled: Bool) async {
        _ = enabled
    }

    func emitLevel(_ level: Float) {
        levelHandler?(level)
    }
}

private actor RecordingPermissionProbe {
    struct Snapshot: Sendable {
        var microphoneRequests: Int
        var screenRecordingRequests: Int
    }

    private var microphoneRequests = 0
    private var screenRecordingRequests = 0

    func requestMicrophonePermission() throws -> Bool {
        microphoneRequests += 1
        return true
    }

    func requestScreenRecordingPermission() throws -> Bool {
        screenRecordingRequests += 1
        return true
    }

    func snapshot() -> Snapshot {
        Snapshot(
            microphoneRequests: microphoneRequests,
            screenRecordingRequests: screenRecordingRequests
        )
    }
}

private actor BlockingMediaImportService: MediaImporting {
    private var continuation: CheckedContinuation<MediaImportResult, Error>?
    private(set) var didStartImport = false

    func importMedia(from sourceURL: URL) async throws -> MediaImportResult {
        _ = sourceURL
        didStartImport = true
        return try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
        }
    }

    func finishImport() {
        guard let continuation else { return }
        self.continuation = nil
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("minute-import-blocked-\(UUID().uuidString).wav")
        try? Data().write(to: url, options: [.atomic])
        continuation.resume(returning: MediaImportResult(
            wavURL: url,
            duration: 0,
            suggestedStartDate: Date()
        ))
    }
}

private struct FailingMediaImportService: MediaImporting {
    func importMedia(from _: URL) async throws -> MediaImportResult {
        throw MinuteError.audioExportFailed
    }
}

struct MeetingPipelineViewModelSilenceBehaviorTests {
    @Test
    func autoStop_withoutUserAction_stopsRecordingAfterWarningCountdown() async throws {
        let audioService = ContinuousSilenceAudioService()
        let model = try await makeSilenceBehaviorModel(audioService: audioService)

        await MainActor.run {
            model.send(.startRecording)
        }

        try await eventually(timeoutNanoseconds: 2_000_000_000) {
            await audioService.stopRecordingCalls > 0
        }

        let sawAutoStopEvent = await MainActor.run {
            model.recordingSessionEvents.contains { $0.eventType == .autoStopExecuted }
        }
        #expect(sawAutoStopEvent)

        await MainActor.run {
            model.send(.cancelRecording)
        }
    }

    @Test
    func keepRecordingAction_cancelsPendingAutoStop() async throws {
        let audioService = ContinuousSilenceAudioService()
        let model = try await makeSilenceBehaviorModel(audioService: audioService)

        await MainActor.run {
            model.send(.startRecording)
        }

        try await eventually(timeoutNanoseconds: 2_000_000_000) {
            await MainActor.run { model.activeSilenceAlert != nil }
        }

        await MainActor.run {
            model.keepRecordingFromWarning()
        }

        try await Task.sleep(nanoseconds: 500_000_000)
        #expect(await audioService.stopRecordingCalls == 0)

        let sawKeepRecordingEvent = await MainActor.run {
            model.recordingSessionEvents.contains { $0.eventType == .keepRecordingSelected }
        }
        #expect(sawKeepRecordingEvent)

        await MainActor.run {
            model.send(.cancelRecording)
        }
    }

    @Test
    func sharedWindowClosed_setsAlert_andCoexistsWithSilenceWarning() async throws {
        let audioService = ContinuousSilenceAudioService()
        let model = try await makeSilenceBehaviorModel(audioService: audioService)

        await MainActor.run {
            model.send(.startRecording)
        }

        try await eventually(timeoutNanoseconds: 2_000_000_000) {
            await MainActor.run { model.activeSilenceAlert != nil }
        }

        await MainActor.run {
            model._testHandleScreenContextLifecycleEvent(
                ScreenContextLifecycleEvent(type: .sharedWindowClosed, windowTitle: "Slides")
            )
        }

        let bothVisible = await MainActor.run {
            model.activeSilenceAlert != nil && model.activeScreenContextAlert != nil
        }
        #expect(bothVisible)

        let sawScreenContextEvent = await MainActor.run {
            model.recordingSessionEvents.contains { $0.eventType == .screenWindowClosedNotified }
        }
        #expect(sawScreenContextEvent)

        await MainActor.run {
            model.send(.cancelRecording)
        }
    }

    @Test
    func sharedWindowClosed_withoutAction_stopsRecordingAfterCountdown() async throws {
        let audioService = ContinuousSilenceAudioService()
        let policy = SilenceDetectionPolicy(
            silenceDurationSeconds: 10,
            warningCountdownSeconds: 0.3,
            rmsSilenceThreshold: 0.8,
            transientToleranceSeconds: 0
        )
        let model = try await makeSilenceBehaviorModel(audioService: audioService, silenceDetectionPolicy: policy)

        await MainActor.run {
            model.send(.startRecording)
        }

        try await eventually(timeoutNanoseconds: 1_000_000_000) {
            await MainActor.run {
                if case .recording = model.state { return true }
                return false
            }
        }

        await MainActor.run {
            model._testHandleScreenContextLifecycleEvent(
                ScreenContextLifecycleEvent(type: .sharedWindowClosed, windowTitle: "Slides")
            )
        }

        try await eventually(timeoutNanoseconds: 1_500_000_000) {
            await audioService.stopRecordingCalls > 0
        }

        let didAutoStopFromScreenAlert = await MainActor.run {
            model.recordingSessionEvents.contains {
                $0.eventType == .autoStopExecuted && $0.metadata["source"] == "screen_window_closed"
            }
        }
        #expect(didAutoStopFromScreenAlert)
    }

    @Test
    func sharedWindowClosed_keepRecording_cancelsPendingAutoStop() async throws {
        let audioService = ContinuousSilenceAudioService()
        let policy = SilenceDetectionPolicy(
            silenceDurationSeconds: 10,
            warningCountdownSeconds: 0.3,
            rmsSilenceThreshold: 0.8,
            transientToleranceSeconds: 0
        )
        let model = try await makeSilenceBehaviorModel(audioService: audioService, silenceDetectionPolicy: policy)

        await MainActor.run {
            model.send(.startRecording)
        }

        try await eventually(timeoutNanoseconds: 1_000_000_000) {
            await MainActor.run {
                if case .recording = model.state { return true }
                return false
            }
        }

        await MainActor.run {
            model._testHandleScreenContextLifecycleEvent(
                ScreenContextLifecycleEvent(type: .sharedWindowClosed, windowTitle: "Slides")
            )
        }

        try await eventually(timeoutNanoseconds: 1_000_000_000) {
            await MainActor.run { model.activeScreenContextAlert != nil }
        }

        await MainActor.run {
            model.keepRecordingFromWarning()
        }

        try await Task.sleep(nanoseconds: 600_000_000)
        #expect(await audioService.stopRecordingCalls == 0)

        let didLogKeepSelection = await MainActor.run {
            model.recordingSessionEvents.contains {
                $0.eventType == .keepRecordingSelected && $0.metadata["source"] == "screen_window_closed"
            }
        }
        #expect(didLogKeepSelection)

        await MainActor.run {
            model.send(.cancelRecording)
        }
    }
}

private func makeSilenceBehaviorModel(
    audioService: ContinuousSilenceAudioService,
    silenceDetectionPolicy: SilenceDetectionPolicy? = nil
) async throws -> MeetingPipelineViewModel {
    let suiteName = "MeetingPipelineViewModelSilenceBehaviorTests-\(UUID().uuidString)"
    let dependencies = try PipelineViewModelFixtureBuilder.makeDependencies(suiteName: suiteName)

    let alertNotifier = await MainActor.run { MockRecordingAlertNotifier() }
    let defaultPolicy = SilenceDetectionPolicy(
        silenceDurationSeconds: 0.15,
        warningCountdownSeconds: 0.8,
        rmsSilenceThreshold: 0.8,
        transientToleranceSeconds: 0
    )
    let effectivePolicy = silenceDetectionPolicy ?? defaultPolicy

    return await MainActor.run {
        MeetingPipelineViewModel(
            audioService: audioService,
            mediaImportService: MockMediaImportService(),
            recoveryService: MockRecordingRecoveryService(),
            pipelineCoordinator: dependencies.coordinator,
            screenContextCaptureService: ScreenContextCaptureService(inferencer: MockScreenContextInferenceService()),
            screenContextVideoExtractor: ScreenContextVideoFrameExtractor(inferencer: MockScreenContextInferenceService()),
            screenContextSettingsStore: ScreenContextSettingsStore(),
            vaultAccess: dependencies.viewModelVaultAccess,
            recordingPermissions: .alwaysGranted(),
            stagePreferencesStore: dependencies.stagePreferencesStore,
            silenceDetectionPolicy: effectivePolicy,
            recordingAlertNotifier: alertNotifier
        )
    }
}
