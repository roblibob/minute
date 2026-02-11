import Foundation
import MinuteCore
import Testing
@testable import Minute

struct MeetingPipelineViewModelCancelSessionTests {
    @Test
    func cancelSession_whileRecording_doesNotStopOrEnqueue_andReturnsIdle() async throws {
        let audioService = TestAudioService()

        let suiteName = "MeetingPipelineViewModelCancelSessionTests"
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

        var model: MeetingPipelineViewModel? = await MainActor.run {
            return MeetingPipelineViewModel(
                audioService: audioService,
                mediaImportService: MockMediaImportService(),
                recoveryService: MockRecordingRecoveryService(),
                pipelineCoordinator: coordinator,
                screenContextCaptureService: ScreenContextCaptureService(inferencer: MockScreenContextInferenceService()),
                screenContextVideoExtractor: ScreenContextVideoFrameExtractor(inferencer: MockScreenContextInferenceService()),
                screenContextSettingsStore: ScreenContextSettingsStore(),
                vaultAccess: viewModelVaultAccess,
                recordingPermissions: .alwaysGranted(),
                stagePreferencesStore: stagePreferencesStore
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
                pipelineCoordinator: coordinator,
                screenContextCaptureService: ScreenContextCaptureService(inferencer: MockScreenContextInferenceService()),
                screenContextVideoExtractor: ScreenContextVideoFrameExtractor(inferencer: MockScreenContextInferenceService()),
                screenContextSettingsStore: ScreenContextSettingsStore(),
                vaultAccess: viewModelVaultAccess,
                recordingPermissions: permissions,
                stagePreferencesStore: stagePreferencesStore
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

private final class InMemoryVaultBookmarkStore: VaultBookmarkStoring {
    private var bookmark: Data?

    init(bookmark: Data?) {
        self.bookmark = bookmark
    }

    func loadVaultRootBookmark() -> Data? {
        bookmark
    }

    func saveVaultRootBookmark(_ bookmark: Data) {
        self.bookmark = bookmark
    }

    func clearVaultRootBookmark() {
        bookmark = nil
    }
}

private func eventually(
    timeoutNanoseconds: UInt64,
    pollIntervalNanoseconds: UInt64 = 10_000_000,
    condition: @escaping @Sendable () async -> Bool
) async throws {
    let deadline = DispatchTime.now().uptimeNanoseconds + timeoutNanoseconds
    while DispatchTime.now().uptimeNanoseconds < deadline {
        if await condition() {
            return
        }
        try await Task.sleep(nanoseconds: pollIntervalNanoseconds)
    }

    throw TestTimeoutError()
}

private struct TestTimeoutError: Error {}
