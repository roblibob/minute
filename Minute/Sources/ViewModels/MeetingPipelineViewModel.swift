import AppKit
import CoreGraphics
import QuartzCore
@preconcurrency import AVFoundation
import Combine
import Foundation
import MinuteCore
import MinuteLlama
import os
import UniformTypeIdentifiers

@MainActor
final class MeetingPipelineViewModel: ObservableObject {
    struct VaultStatus: Equatable {
        var displayText: String
        var isConfigured: Bool
    }

    struct ScreenInferenceStatus: Equatable {
        var processedCount: Int
        var skippedCount: Int
        var isInferenceRunning: Bool
        var isFirstInferenceDeferred: Bool
    }

    enum CaptureState: Equatable {
        case ready
        case recording
    }

    @Published private(set) var state: MeetingPipelineState = .idle
    @Published private(set) var captureState: CaptureState = .ready
    @Published private(set) var progress: Double? = nil
    @Published private(set) var backgroundProcessingSnapshot: BackgroundProcessingSnapshot = BackgroundProcessingSnapshot()
    @Published private(set) var lastBackgroundProcessedNoteURL: URL? = nil
    @Published private(set) var vaultStatus: VaultStatus = VaultStatus(displayText: "Not selected", isConfigured: false)
    @Published private(set) var microphonePermissionGranted: Bool = false
    @Published private(set) var screenRecordingPermissionGranted: Bool = false
    @Published private(set) var microphoneCaptureEnabled: Bool = true
    @Published private(set) var systemAudioCaptureEnabled: Bool = true
    @Published private(set) var screenCaptureEnabled: Bool = false
    @Published private(set) var audioLevelSamples: [CGFloat] = Array(repeating: 0, count: 24)
    @Published private(set) var screenInferenceStatus: ScreenInferenceStatus? = nil
    @Published private(set) var latestScreenCaptureImage: NSImage? = nil
    @Published private(set) var recoverableRecordings: [RecoverableRecording] = []
    @Published var meetingType: MeetingType = .autodetect

    private let audioService: any AudioServicing
    private let mediaImportService: any MediaImporting
    private let recoveryService: any RecordingRecoveryServicing
    private let pipelineCoordinator: MeetingPipelineCoordinator
    private let processingBusyGate: ProcessingBusyGate
    private let processingOrchestrator: MeetingProcessingOrchestrator
    private let screenContextCaptureService: ScreenContextCaptureService
    private let screenContextVideoExtractor: ScreenContextVideoFrameExtractor
    private let screenContextSettingsStore: ScreenContextSettingsStore

    private let vaultAccess: VaultAccess

    private let logger = Logger(subsystem: "roblibob.Minute", category: "pipeline")

    private var defaultsObserver: AnyCancellable?
    private var processingTask: Task<Void, Never>?
    private var backgroundProcessingObserverTask: Task<Void, Never>?
    private var lastAudioLevelUpdate: CFTimeInterval = 0
    private var screenContextEvents: [ScreenContextEvent] = []
    private var screenCaptureSelection: ScreenContextWindowSelection?
    private var screenCaptureBaseProcessedCount = 0
    private var screenCaptureBaseSkippedCount = 0

    private let audioLevelBucketCount = 24
    private let audioLevelUpdateInterval: CFTimeInterval = 1.0 / 24.0
    private var screenContextFrameIntervalSeconds: TimeInterval {
        screenContextSettingsStore.captureIntervalSeconds
    }
	
    init(
        audioService: some AudioServicing,
        mediaImportService: some MediaImporting,
        recoveryService: some RecordingRecoveryServicing,
        pipelineCoordinator: MeetingPipelineCoordinator,
        screenContextCaptureService: ScreenContextCaptureService,
        screenContextVideoExtractor: ScreenContextVideoFrameExtractor,
        screenContextSettingsStore: ScreenContextSettingsStore,
        vaultAccess: VaultAccess
    ) {
        self.audioService = audioService
        self.mediaImportService = mediaImportService
        self.recoveryService = recoveryService
        self.pipelineCoordinator = pipelineCoordinator
        let busyGate = ProcessingBusyGate()
        self.processingBusyGate = busyGate
        self.processingOrchestrator = MeetingProcessingOrchestrator(busyGate: busyGate, coordinator: pipelineCoordinator)
        self.screenContextCaptureService = screenContextCaptureService
        self.screenContextVideoExtractor = screenContextVideoExtractor
        self.screenContextSettingsStore = screenContextSettingsStore
        self.vaultAccess = vaultAccess
        self.screenCaptureEnabled = screenContextSettingsStore.isEnabled

        refreshVaultStatus()
        refreshMicrophonePermission()
        refreshScreenRecordingPermission()

        defaultsObserver = NotificationCenter.default.publisher(for: UserDefaults.didChangeNotification)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.refreshVaultStatus()
            }

        refreshRecoverableRecordings()

        startBackgroundProcessingObservation()
    }

    deinit {
        processingTask?.cancel()
        backgroundProcessingObserverTask?.cancel()
        let captureService = screenContextCaptureService
        Task { [captureService] in
            await captureService.cancelCapture()
        }
    }

    static func mock() -> MeetingPipelineViewModel {
        let bookmarkStore = UserDefaultsVaultBookmarkStore(key: AppConfiguration.Defaults.vaultRootBookmarkKey)
        let vaultAccess = VaultAccess(bookmarkStore: bookmarkStore)
        let coordinator = MeetingPipelineCoordinator(
            transcriptionService: MockTranscriptionService(),
            diarizationService: MockDiarizationService(),
            summarizationServiceProvider: { MockSummarizationService() },
            modelManager: MockModelManager(),
            vaultAccess: vaultAccess,
            vaultWriter: DefaultVaultWriter()
        )

        return MeetingPipelineViewModel(
            audioService: MockAudioService(),
            mediaImportService: MockMediaImportService(),
            recoveryService: MockRecordingRecoveryService(),
            pipelineCoordinator: coordinator,
            screenContextCaptureService: ScreenContextCaptureService(inferencer: MockScreenContextInferenceService()),
            screenContextVideoExtractor: ScreenContextVideoFrameExtractor(inferencer: MockScreenContextInferenceService()),
            screenContextSettingsStore: ScreenContextSettingsStore(),
            vaultAccess: vaultAccess
        )
    }

    static func live() -> MeetingPipelineViewModel {
        let selectionStore = SummarizationModelSelectionStore()
        let transcriptionSelectionStore = TranscriptionModelSelectionStore()
        let transcriptionBackendStore = TranscriptionBackendSelectionStore()
        let fluidAudioModelStore = FluidAudioASRModelSelectionStore()
        let summarizationServiceProvider: () -> any SummarizationServicing = {
            LlamaLibrarySummarizationService.liveDefault(selectionStore: selectionStore)
        }
        let transcriptionService: any TranscriptionServicing
        switch transcriptionBackendStore.selectedBackend() {
        case .whisper:
            transcriptionService = WhisperXPCTranscriptionService.liveDefault()
        case .fluidAudio:
            transcriptionService = FluidAudioTranscriptionService.liveDefault(selectionStore: fluidAudioModelStore)
        }
        let screenInferencer: any ScreenContextInferencing = LlamaMTMDScreenInferenceService
            .liveDefault(selectionStore: selectionStore)
            ?? MissingScreenContextInferenceService()

        let bookmarkStore = UserDefaultsVaultBookmarkStore(key: AppConfiguration.Defaults.vaultRootBookmarkKey)
        let vaultAccess = VaultAccess(bookmarkStore: bookmarkStore)
        let coordinator = MeetingPipelineCoordinator(
            transcriptionService: transcriptionService,
            diarizationService: FluidAudioOfflineDiarizationService.meetingDefault(),
            summarizationServiceProvider: summarizationServiceProvider,
            audioLoudnessNormalizer: AudioLoudnessNormalizer(),
            modelManager: DefaultModelManager(
                selectionStore: selectionStore,
                transcriptionSelectionStore: transcriptionSelectionStore,
                transcriptionBackendStore: transcriptionBackendStore,
                fluidAudioModelStore: fluidAudioModelStore
            ),
            vaultAccess: vaultAccess,
            vaultWriter: DefaultVaultWriter()
        )

        return MeetingPipelineViewModel(
            audioService: DefaultAudioService(),
            mediaImportService: DefaultMediaImportService(),
            recoveryService: DefaultRecordingRecoveryService(),
            pipelineCoordinator: coordinator,
            screenContextCaptureService: ScreenContextCaptureService(inferencer: screenInferencer),
            screenContextVideoExtractor: ScreenContextVideoFrameExtractor(inferencer: screenInferencer),
            screenContextSettingsStore: ScreenContextSettingsStore(),
            vaultAccess: vaultAccess
        )
    }

    func refreshVaultStatus() {
        do {
            let url = try vaultAccess.resolveVaultRootURL()
            vaultStatus = VaultStatus(displayText: url.path, isConfigured: true)
        } catch {
            vaultStatus = VaultStatus(displayText: "Not selected", isConfigured: false)
        }
    }

    func refreshRecoverableRecordings() {
        Task { [weak self] in
            guard let self else { return }
            let recordings = await recoveryService.findRecoverableRecordings()
            self.recoverableRecordings = recordings
        }
    }

    func send(_ action: MeetingPipelineAction) {
        switch action {
        case .startRecording:
            startRecordingIfAllowed(selection: nil)
        case .startRecordingWithWindow(let selection):
            startRecordingIfAllowed(selection: selection)
        case .stopRecording:
            stopRecordingIfAllowed()
        case .process:
            processIfAllowed()
        case .importFile(let url):
            importFileIfAllowed(url)
        case .cancelProcessing:
            cancelProcessingIfAllowed()
        case .reset:
            resetIfAllowed()
        }
    }

    func cancelBackgroundProcessing(clearPending: Bool) {
        Task { [processingOrchestrator] in
            await processingOrchestrator.cancelActiveProcessing(clearPending: clearPending)
        }
    }

    func retryBackgroundProcessing() {
        Task { [processingOrchestrator] in
            _ = await processingOrchestrator.retryLastFailedOrCanceled()
        }
    }

    func recoverRecording(_ recording: RecoverableRecording) {
        guard state.canImportMedia else { return }

        processingTask?.cancel()
        progress = nil
        screenContextEvents = []
        screenInferenceStatus = nil
        screenCaptureBaseProcessedCount = 0
        screenCaptureBaseSkippedCount = 0
        state = .importing(sourceURL: recording.sessionURL)

        processingTask = Task(priority: .userInitiated) { [weak self] in
            guard let self else { return }
            do {
                let result = try await recoveryService.recover(recording: recording)
                let startedAt = result.startedAt
                let stoppedAt = result.stoppedAt
                state = .recorded(
                    audioTempURL: result.wavURL,
                    durationSeconds: result.duration,
                    startedAt: startedAt,
                    stoppedAt: stoppedAt
                )
                await MainActor.run {
                    self.refreshRecoverableRecordings()
                }
            } catch is CancellationError {
                progress = nil
                screenInferenceStatus = nil
                screenContextEvents = []
                screenCaptureBaseProcessedCount = 0
                screenCaptureBaseSkippedCount = 0
                state = .idle
            } catch let minuteError as MinuteError {
                progress = nil
                screenInferenceStatus = nil
                screenContextEvents = []
                screenCaptureBaseProcessedCount = 0
                screenCaptureBaseSkippedCount = 0
                state = .failed(error: minuteError, debugOutput: minuteError.debugSummary)
            } catch {
                progress = nil
                screenInferenceStatus = nil
                screenContextEvents = []
                screenCaptureBaseProcessedCount = 0
                screenCaptureBaseSkippedCount = 0
                state = .failed(error: .audioExportFailed, debugOutput: ErrorHandler.debugMessage(for: error))
            }
        }
    }

    func discardRecoverableRecording(_ recording: RecoverableRecording) {
        Task { [weak self] in
            guard let self else { return }
            await recoveryService.discard(recording: recording)
            await MainActor.run {
                self.refreshRecoverableRecordings()
            }
        }
    }

    var hasScreenCaptureSelection: Bool {
        screenCaptureSelection != nil
    }

    func setMicrophoneCaptureEnabled(_ enabled: Bool) {
        guard microphoneCaptureEnabled != enabled else { return }
        microphoneCaptureEnabled = enabled
        Task { [weak self] in
            await self?.applyAudioCaptureToggles()
        }
    }

    func setSystemAudioCaptureEnabled(_ enabled: Bool) {
        guard systemAudioCaptureEnabled != enabled else { return }
        systemAudioCaptureEnabled = enabled
        Task { [weak self] in
            await self?.applyAudioCaptureToggles()
        }
    }

    func setAudioCaptureConfiguration(microphoneEnabled: Bool, systemAudioEnabled: Bool) {
        guard microphoneCaptureEnabled != microphoneEnabled || systemAudioCaptureEnabled != systemAudioEnabled else { return }
        microphoneCaptureEnabled = microphoneEnabled
        systemAudioCaptureEnabled = systemAudioEnabled
        Task { [weak self] in
            await self?.applyAudioCaptureToggles()
        }
    }

    func setScreenCaptureEnabled(_ enabled: Bool) {
        guard screenCaptureEnabled != enabled else { return }
        screenCaptureEnabled = enabled

        if !enabled {
            latestScreenCaptureImage = nil
            Task { [weak self] in
                await self?.stopScreenContextCaptureAndAppend()
            }
            return
        }

        guard let selection = screenCaptureSelection else { return }
        guard case .recording(let session) = state else { return }
        let offsetSeconds = Date().timeIntervalSince(session.startedAt)
        Task { [weak self] in
            await self?.startScreenContextCapture(selection: selection, offsetSeconds: offsetSeconds)
        }
    }

    func setScreenCaptureSelection(_ selection: ScreenContextWindowSelection) {
        screenCaptureSelection = selection
        guard screenCaptureEnabled else { return }
        guard case .recording(let session) = state else { return }
        let offsetSeconds = Date().timeIntervalSince(session.startedAt)
        Task { [weak self] in
            await self?.startScreenContextCapture(selection: selection, offsetSeconds: offsetSeconds)
        }
    }

    // MARK: - Actions

    private func startRecordingIfAllowed(selection: ScreenContextWindowSelection?) {
        guard captureState == .ready else { return }

        Task {
            do {
                // Gate on microphone permission.
                let status = AVCaptureDevice.authorizationStatus(for: .audio)
                switch status {
                case .authorized:
                    microphonePermissionGranted = true

                case .notDetermined:
                    let granted = await AVCaptureDevice.requestAccess(for: .audio)
                    microphonePermissionGranted = granted
                    if !granted { throw MinuteError.permissionDenied }

                case .denied, .restricted:
                    microphonePermissionGranted = false
                    throw MinuteError.permissionDenied

                @unknown default:
                    microphonePermissionGranted = false
                    throw MinuteError.permissionDenied
                }

                let screenGranted = await ScreenRecordingPermission.refresh()
                screenRecordingPermissionGranted = screenGranted
                if !screenGranted {
                    throw MinuteError.screenRecordingPermissionDenied
                }

                if let selection {
                    screenCaptureSelection = selection
                    screenCaptureEnabled = true
                }

                latestScreenCaptureImage = nil
                screenContextEvents = []
                screenInferenceStatus = nil
                screenCaptureBaseProcessedCount = 0
                screenCaptureBaseSkippedCount = 0

                let session = RecordingSession()
                await applyAudioCaptureToggles()
                try await audioService.startRecording()
                await startScreenContextCaptureIfNeeded(selection: selection, offsetSeconds: 0)
                await startAudioLevelMonitoring()
                resetAudioLevelSamples()
                state = .recording(session: session)
                captureState = .recording
            } catch let minuteError as MinuteError {
                await stopAudioLevelMonitoring()
                await screenContextCaptureService.cancelCapture()
                screenInferenceStatus = nil
                screenContextEvents = []
                screenCaptureSelection = nil
                screenCaptureBaseProcessedCount = 0
                screenCaptureBaseSkippedCount = 0
                state = .failed(error: minuteError, debugOutput: minuteError.debugSummary)
                captureState = .ready
            } catch {
                await stopAudioLevelMonitoring()
                await screenContextCaptureService.cancelCapture()
                screenInferenceStatus = nil
                screenContextEvents = []
                screenCaptureSelection = nil
                screenCaptureBaseProcessedCount = 0
                screenCaptureBaseSkippedCount = 0
                state = .failed(error: .audioExportFailed, debugOutput: ErrorHandler.debugMessage(for: error))
                captureState = .ready
            }
        }
    }

    private func stopRecordingIfAllowed() {
        guard case .recording(let session) = state else { return }
        guard captureState == .recording else { return }

        let stoppedAt = Date()

        Task {
            do {
                let result = try await audioService.stopRecording()
                _ = await stopScreenContextCaptureAndAppend()
                await stopAudioLevelMonitoring()
                resetAudioLevelSamples()

                guard let context = makePipelineContext(
                    audioTempURL: result.wavURL,
                    audioDurationSeconds: result.duration,
                    startedAt: session.startedAt,
                    stoppedAt: stoppedAt,
                    screenContextEvents: screenContextEvents
                ) else {
                    throw MinuteError.vaultUnavailable
                }

                let accepted = await processingOrchestrator.enqueue(meetingID: session.id, context: context)

                screenCaptureSelection = nil
                captureState = .ready
                screenContextEvents = []

                if accepted {
                    state = .idle
                } else {
                    state = .recorded(
                        audioTempURL: result.wavURL,
                        durationSeconds: result.duration,
                        startedAt: session.startedAt,
                        stoppedAt: stoppedAt
                    )
                }
            } catch let minuteError as MinuteError {
                await stopAudioLevelMonitoring()
                await screenContextCaptureService.cancelCapture()
                screenInferenceStatus = nil
                screenContextEvents = []
                screenCaptureSelection = nil
                screenCaptureBaseProcessedCount = 0
                screenCaptureBaseSkippedCount = 0
                state = .failed(error: minuteError, debugOutput: minuteError.debugSummary)
                captureState = .ready
            } catch {
                await stopAudioLevelMonitoring()
                await screenContextCaptureService.cancelCapture()
                screenInferenceStatus = nil
                screenContextEvents = []
                screenCaptureSelection = nil
                screenCaptureBaseProcessedCount = 0
                screenCaptureBaseSkippedCount = 0
                state = .failed(error: .audioExportFailed, debugOutput: ErrorHandler.debugMessage(for: error))
                captureState = .ready
            }
        }
    }

    private func importFileIfAllowed(_ url: URL) {
        guard state.canImportMedia else { return }

        processingTask?.cancel()
        progress = nil
        screenContextEvents = []
        screenInferenceStatus = nil
        screenCaptureBaseProcessedCount = 0
        screenCaptureBaseSkippedCount = 0
        state = .importing(sourceURL: url)

        processingTask = Task(priority: .userInitiated) { [weak self] in
            guard let self else { return }
            do {
                let result = try await mediaImportService.importMedia(from: url)
                if screenContextSettingsStore.isVideoImportEnabled, isVideoImportURL(url) {
                    screenInferenceStatus = ScreenInferenceStatus(
                        processedCount: 0,
                        skippedCount: 0,
                        isInferenceRunning: true,
                        isFirstInferenceDeferred: false
                    )
                    if let inferenceResult = await extractScreenContextForImport(sourceURL: url) {
                        screenContextEvents = inferenceResult.events
                        screenInferenceStatus = ScreenInferenceStatus(
                            processedCount: inferenceResult.processedCount,
                            skippedCount: 0,
                            isInferenceRunning: false,
                            isFirstInferenceDeferred: false
                        )
                    } else {
                        logger.info("Screen context extraction returned nil for \(url.absoluteString, privacy: .public)")
                        screenInferenceStatus = nil
                    }
                }
                try Task.checkCancellation()
                let startedAt = result.suggestedStartDate
                let stoppedAt = startedAt.addingTimeInterval(result.duration)
                state = .recorded(
                    audioTempURL: result.wavURL,
                    durationSeconds: result.duration,
                    startedAt: startedAt,
                    stoppedAt: stoppedAt
                )
            } catch is CancellationError {
                progress = nil
                screenInferenceStatus = nil
                screenContextEvents = []
                screenCaptureBaseProcessedCount = 0
                screenCaptureBaseSkippedCount = 0
                state = .idle
            } catch let minuteError as MinuteError {
                progress = nil
                screenInferenceStatus = nil
                screenContextEvents = []
                screenCaptureBaseProcessedCount = 0
                screenCaptureBaseSkippedCount = 0
                state = .failed(error: minuteError, debugOutput: minuteError.debugSummary)
            } catch {
                progress = nil
                screenInferenceStatus = nil
                screenContextEvents = []
                screenCaptureBaseProcessedCount = 0
                screenCaptureBaseSkippedCount = 0
                state = .failed(error: .audioExportFailed, debugOutput: ErrorHandler.debugMessage(for: error))
            }
        }
    }

    private func processIfAllowed() {
        guard case .recorded(let audioTempURL, let durationSeconds, let startedAt, let stoppedAt) = state else { return }

        // Snapshot vault configuration.
        guard let context = makePipelineContext(
            audioTempURL: audioTempURL,
            audioDurationSeconds: durationSeconds,
            startedAt: startedAt,
            stoppedAt: stoppedAt,
            screenContextEvents: screenContextEvents
        ) else {
            state = .failed(error: .vaultUnavailable, debugOutput: nil)
            return
        }

        // One active task at a time.
        processingTask?.cancel()
        progress = 0
        state = .processing(stage: .downloadingModels, context: context)

        processingTask = Task(priority: .userInitiated) { [weak self] in
            guard let self else { return }
            await self.runPipeline(context: context)
        }
    }

    private func cancelProcessingIfAllowed() {
        if state.canCancelProcessing {
            processingTask?.cancel()
            return
        }

        if backgroundProcessingSnapshot.activeMeetingID != nil {
            cancelBackgroundProcessing(clearPending: true)
        }
    }

    private func resetIfAllowed() {
        guard state.canReset else { return }
        progress = nil
        state = .idle
        captureState = .ready
        resetAudioLevelSamples()
        screenInferenceStatus = nil
        screenContextEvents = []
        latestScreenCaptureImage = nil
        screenCaptureSelection = nil
        screenCaptureBaseProcessedCount = 0
        screenCaptureBaseSkippedCount = 0
        meetingType = .autodetect
    }

    private func applyAudioCaptureToggles() async {
        guard let controller = audioService as? (any AudioCaptureControlling) else { return }
        await controller.setMicrophoneEnabled(microphoneCaptureEnabled)
        await controller.setSystemAudioEnabled(systemAudioCaptureEnabled)
    }

    private func updateScreenInferenceStatus(_ status: ScreenContextCaptureStatus) {
        let processed = screenCaptureBaseProcessedCount + status.processedCount
        let skipped = screenCaptureBaseSkippedCount + status.skippedCount
        screenInferenceStatus = ScreenInferenceStatus(
            processedCount: processed,
            skippedCount: skipped,
            isInferenceRunning: status.isInferenceRunning,
            isFirstInferenceDeferred: status.isFirstInferenceDeferred
        )
    }

    private func updateLatestScreenCaptureImage(_ frame: ScreenContextCapturedFrame) {
        guard let image = NSImage(data: frame.imageData) else { return }
        latestScreenCaptureImage = image
    }

    // MARK: - Pipeline

    private func startScreenContextCaptureIfNeeded(
        selection: ScreenContextWindowSelection?,
        offsetSeconds: TimeInterval
    ) async {
        guard screenCaptureEnabled else { return }
        guard let selection else { return }
        let selections = [selection]

        screenInferenceStatus = ScreenInferenceStatus(
            processedCount: screenCaptureBaseProcessedCount,
            skippedCount: screenCaptureBaseSkippedCount,
            isInferenceRunning: true,
            isFirstInferenceDeferred: false
        )

        do {
            try await screenContextCaptureService.startCapture(
                selections: selections,
                minimumFrameInterval: screenContextFrameIntervalSeconds,
                timestampOffsetSeconds: offsetSeconds,
                processingBusyGate: processingBusyGate,
                statusHandler: { [weak self] status in
                    Task { @MainActor [weak self] in
                        self?.updateScreenInferenceStatus(status)
                    }
                },
                frameHandler: { [weak self] frame in
                    Task { @MainActor [weak self] in
                        self?.updateLatestScreenCaptureImage(frame)
                    }
                }
            )
        } catch {
            logger.error("Screen context capture failed: \(ErrorHandler.debugMessage(for: error), privacy: .public)")
        }
    }

    private func startScreenContextCapture(
        selection: ScreenContextWindowSelection,
        offsetSeconds: TimeInterval
    ) async {
        await startScreenContextCaptureIfNeeded(selection: selection, offsetSeconds: offsetSeconds)
    }

    private func stopScreenContextCaptureAndAppend() async -> ScreenContextCaptureResult? {
        guard let captureResult = await screenContextCaptureService.stopCapture() else { return nil }
        screenCaptureBaseProcessedCount += captureResult.processedCount
        screenCaptureBaseSkippedCount += captureResult.skippedCount
        screenContextEvents.append(contentsOf: captureResult.events)
        screenContextEvents.sort { $0.timestampSeconds < $1.timestampSeconds }
        screenInferenceStatus = ScreenInferenceStatus(
            processedCount: screenCaptureBaseProcessedCount,
            skippedCount: screenCaptureBaseSkippedCount,
            isInferenceRunning: false,
            isFirstInferenceDeferred: false
        )
        return captureResult
    }

    private func startBackgroundProcessingObservation() {
        backgroundProcessingObserverTask?.cancel()

        let orchestrator = processingOrchestrator
        backgroundProcessingObserverTask = Task { [weak self] in
            guard let self else { return }

            var lastCompletedNoteURL: URL?

            while !Task.isCancelled {
                let snapshot = await orchestrator.snapshot()

                if case let .completed(noteURL, _) = snapshot.lastOutcome {
                    lastCompletedNoteURL = noteURL
                }

                await MainActor.run {
                    self.backgroundProcessingSnapshot = snapshot
                    if self.lastBackgroundProcessedNoteURL != lastCompletedNoteURL {
                        self.lastBackgroundProcessedNoteURL = lastCompletedNoteURL
                    }
                }

                try? await Task.sleep(nanoseconds: 200_000_000)
            }
        }
    }

    private func extractScreenContextForImport(sourceURL: URL) async -> ScreenContextVideoInferenceResult? {
        guard screenContextSettingsStore.isVideoImportEnabled else { return nil }

        let access = sourceURL.startAccessingSecurityScopedResource()
        defer {
            if access {
                sourceURL.stopAccessingSecurityScopedResource()
            }
        }

        do {
            return try await screenContextVideoExtractor.inferEvents(from: sourceURL)
        } catch {
            logger.error("Video screen context failed: \(ErrorHandler.debugMessage(for: error), privacy: .public)")
            return nil
        }
    }

    private func isVideoImportURL(_ url: URL) -> Bool {
        let ext = url.pathExtension.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard let type = UTType(filenameExtension: ext) else { return false }
        return type.conforms(to: .movie)
    }

    private func runPipeline(context: PipelineContext) async {
        do {
            let outputs = try await pipelineCoordinator.execute(
                context: context,
                progress: { [weak self] update in
                    Task { @MainActor [weak self] in
                        self?.applyPipelineProgress(update, context: context)
                    }
                }
            )
            progress = nil
            state = .done(noteURL: outputs.noteURL, audioURL: outputs.audioURL)
        } catch is CancellationError {
            progress = nil

            if let recorded = state.recordedContextIfAvailable {
                state = .recorded(
                    audioTempURL: recorded.audioTempURL,
                    durationSeconds: recorded.durationSeconds,
                    startedAt: recorded.startedAt,
                    stoppedAt: recorded.stoppedAt
                )
            } else {
                state = .idle
            }
        } catch let minuteError as MinuteError {
            progress = nil
            state = .failed(error: minuteError, debugOutput: minuteError.debugSummary)
        } catch {
            progress = nil
            state = .failed(error: .vaultWriteFailed, debugOutput: ErrorHandler.debugMessage(for: error))
        }
    }

    private func applyPipelineProgress(_ update: PipelineProgress, context: PipelineContext) {
        progress = min(max(update.fractionCompleted, 0), 1)

        switch update.stage {
        case .downloadingModels:
            state = .processing(stage: .downloadingModels, context: context)
        case .transcribing:
            state = .processing(stage: .transcribing, context: context)
        case .summarizing:
            state = .processing(stage: .summarizing, context: context)
        case .writing:
            guard let extraction = update.extraction else { return }
            state = .writing(context: context, extraction: extraction)
        }
    }

    private func makePipelineContext(
        audioTempURL: URL,
        audioDurationSeconds: TimeInterval,
        startedAt: Date,
        stoppedAt: Date,
        screenContextEvents: [ScreenContextEvent]
    ) -> PipelineContext? {
        let configuration = AppConfiguration()

        // Validate vault selection.
        do {
            _ = try vaultAccess.resolveVaultRootURL()
        } catch {
            return nil
        }

        let workingDirectoryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("minute-work-\(UUID().uuidString)", isDirectory: true)

        return PipelineContext(
            vaultFolders: MeetingFileContract.VaultFolders(
                meetingsRoot: configuration.meetingsRelativePath,
                audioRoot: configuration.audioRelativePath,
                transcriptsRoot: configuration.transcriptsRelativePath
            ),
            audioTempURL: audioTempURL,
            audioDurationSeconds: audioDurationSeconds,
            startedAt: startedAt,
            stoppedAt: stoppedAt,
            workingDirectoryURL: workingDirectoryURL,
            saveAudio: configuration.saveAudio,
            saveTranscript: configuration.saveTranscript,
            normalizeAnalysisAudio: configuration.normalizeAnalysisAudio,
            screenContextEvents: screenContextEvents,
            transcriptionOverride: nil,
            meetingType: meetingType,
            knownSpeakerSuggestionsEnabled: configuration.knownSpeakerSuggestionsEnabled
        )
    }


    // MARK: - Audio levels

    private func startAudioLevelMonitoring() async {
        guard let meter = audioService as? (any AudioLevelMetering) else { return }
        await meter.setLevelHandler { [weak self] level in
            Task { @MainActor [weak self] in
                self?.pushAudioLevel(level)
            }
        }
    }

    private func stopAudioLevelMonitoring() async {
        guard let meter = audioService as? (any AudioLevelMetering) else { return }
        await meter.setLevelHandler(nil)
    }

    private func resetAudioLevelSamples() {
        audioLevelSamples = Array(repeating: 0, count: audioLevelBucketCount)
        lastAudioLevelUpdate = 0
    }

    private func pushAudioLevel(_ level: Float) {
        let now = CACurrentMediaTime()
        guard now - lastAudioLevelUpdate >= audioLevelUpdateInterval else { return }
        lastAudioLevelUpdate = now

        if audioLevelSamples.count != audioLevelBucketCount {
            audioLevelSamples = Array(repeating: 0, count: audioLevelBucketCount)
        }

        let clamped = min(max(level, 0), 1)
        let quantized = (clamped * 8).rounded() / 8
        audioLevelSamples.removeFirst()
        audioLevelSamples.append(CGFloat(quantized))
    }

    // MARK: - Permissions

    func requestMicrophonePermission() {
        Task {
            let granted = await AVCaptureDevice.requestAccess(for: .audio)
            microphonePermissionGranted = granted
        }
    }

    func requestScreenRecordingPermission() {
        Task { @MainActor [weak self] in
            let granted = await ScreenRecordingPermission.request()
            self?.screenRecordingPermissionGranted = granted
        }
    }

    private func refreshMicrophonePermission() {
        let status = AVCaptureDevice.authorizationStatus(for: .audio)
        microphonePermissionGranted = (status == .authorized)
    }

    private func refreshScreenRecordingPermission() {
        Task { @MainActor [weak self] in
            let granted = await ScreenRecordingPermission.refresh()
            self?.screenRecordingPermissionGranted = granted
        }
    }

    // MARK: - UI helpers

    func revealInFinder(_ url: URL) {
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }

    func copyDebugInfoToClipboard() {
        let content: String
        switch state {
        case .failed(let error, let debugOutput):
            var lines: [String] = []
            lines.append(ErrorHandler.userMessage(for: error, fallback: "Error"))
            lines.append(error.debugSummary)
            if let debugOutput, !debugOutput.isEmpty {
                lines.append(debugOutput)
            }
            content = lines.joined(separator: "\n\n")
        default:
            content = ""
        }

        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(content, forType: .string)
    }
}

private struct FailingTranscriptionService: TranscriptionServicing {
    let error: MinuteError

    init(error: Error) {
        self.error = ErrorHandler.minuteError(
            for: error,
            fallback: .whisperFailed(exitCode: -1, output: ErrorHandler.debugMessage(for: error))
        )
    }

    func transcribe(wavURL: URL) async throws -> TranscriptionResult {
        throw error
    }
}
