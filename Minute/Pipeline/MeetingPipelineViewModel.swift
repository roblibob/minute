import AppKit
import CoreGraphics
import QuartzCore
@preconcurrency import AVFoundation
import Combine
import Foundation
import MinuteCore
import MinuteLlama
import os

@MainActor
final class MeetingPipelineViewModel: ObservableObject {
    private enum DefaultsKey {
        static let vaultRootBookmark = "vaultRootBookmark"
        static let meetingsRelativePath = "meetingsRelativePath"
        static let audioRelativePath = "audioRelativePath"
        static let transcriptsRelativePath = "transcriptsRelativePath"
    }

    struct VaultStatus: Equatable {
        var displayText: String
        var isConfigured: Bool
    }

    struct ScreenInferenceStatus: Equatable {
        var processedCount: Int
        var skippedCount: Int
        var isInferenceRunning: Bool
    }

    @Published private(set) var state: MeetingPipelineState = .idle
    @Published private(set) var progress: Double? = nil
    @Published private(set) var vaultStatus: VaultStatus = VaultStatus(displayText: "Not selected", isConfigured: false)
    @Published private(set) var microphonePermissionGranted: Bool = false
    @Published private(set) var screenRecordingPermissionGranted: Bool = false
    @Published private(set) var audioLevelSamples: [CGFloat] = Array(repeating: 0, count: 24)
    @Published private(set) var screenInferenceStatus: ScreenInferenceStatus? = nil

    private let audioService: any AudioServicing
    private let mediaImportService: any MediaImporting
    private let pipelineCoordinator: MeetingPipelineCoordinator
    private let screenContextCaptureService: ScreenContextCaptureService
    private let screenContextVideoExtractor: ScreenContextVideoFrameExtractor
    private let screenContextSettingsStore: ScreenContextSettingsStore

    private let vaultAccess: VaultAccess

    private let logger = Logger(subsystem: "roblibob.Minute", category: "pipeline")

    private var defaultsObserver: AnyCancellable?
    private var processingTask: Task<Void, Never>?
    private var lastAudioLevelUpdate: CFTimeInterval = 0
    private var screenContextEvents: [ScreenContextEvent] = []

    private let audioLevelBucketCount = 24
    private let audioLevelUpdateInterval: CFTimeInterval = 1.0 / 24.0
    // Conservative sampling to limit capture overhead during long meetings.
    private let screenContextFrameIntervalSeconds: TimeInterval = 60.0
	
    init(
        audioService: some AudioServicing,
        mediaImportService: some MediaImporting,
        pipelineCoordinator: MeetingPipelineCoordinator,
        screenContextCaptureService: ScreenContextCaptureService,
        screenContextVideoExtractor: ScreenContextVideoFrameExtractor,
        screenContextSettingsStore: ScreenContextSettingsStore,
        vaultAccess: VaultAccess
    ) {
        self.audioService = audioService
        self.mediaImportService = mediaImportService
        self.pipelineCoordinator = pipelineCoordinator
        self.screenContextCaptureService = screenContextCaptureService
        self.screenContextVideoExtractor = screenContextVideoExtractor
        self.screenContextSettingsStore = screenContextSettingsStore
        self.vaultAccess = vaultAccess

        refreshVaultStatus()
        refreshMicrophonePermission()
        refreshScreenRecordingPermission()

        defaultsObserver = NotificationCenter.default.publisher(for: UserDefaults.didChangeNotification)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.refreshVaultStatus()
            }
    }

    deinit {
        processingTask?.cancel()
        let captureService = screenContextCaptureService
        Task { [captureService] in
            await captureService.cancelCapture()
        }
    }

    static func mock() -> MeetingPipelineViewModel {
        let bookmarkStore = UserDefaultsVaultBookmarkStore(key: DefaultsKey.vaultRootBookmark)
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
            pipelineCoordinator: coordinator,
            screenContextCaptureService: ScreenContextCaptureService(inferencer: MockScreenContextInferenceService()),
            screenContextVideoExtractor: ScreenContextVideoFrameExtractor(inferencer: MockScreenContextInferenceService()),
            screenContextSettingsStore: ScreenContextSettingsStore(),
            vaultAccess: vaultAccess
        )
    }

    static func live() -> MeetingPipelineViewModel {
        let selectionStore = SummarizationModelSelectionStore()
        let summarizationServiceProvider: () -> any SummarizationServicing = {
            LlamaLibrarySummarizationService.liveDefault(selectionStore: selectionStore)
        }
        let transcriptionService: any TranscriptionServicing = WhisperXPCTranscriptionService.liveDefault()
        let screenInferencer: any ScreenContextInferencing = LlamaMTMDScreenInferenceService
            .liveDefault(selectionStore: selectionStore)
            ?? MissingScreenContextInferenceService()

        let bookmarkStore = UserDefaultsVaultBookmarkStore(key: DefaultsKey.vaultRootBookmark)
        let vaultAccess = VaultAccess(bookmarkStore: bookmarkStore)
        let coordinator = MeetingPipelineCoordinator(
            transcriptionService: transcriptionService,
            diarizationService: FluidAudioDiarizationService.meetingDefault(),
            summarizationServiceProvider: summarizationServiceProvider,
            modelManager: DefaultModelManager(selectionStore: selectionStore),
            vaultAccess: vaultAccess,
            vaultWriter: DefaultVaultWriter()
        )

        return MeetingPipelineViewModel(
            audioService: DefaultAudioService(),
            mediaImportService: DefaultMediaImportService(),
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

    // MARK: - Actions

    private func startRecordingIfAllowed(selection: ScreenContextWindowSelection?) {
        guard state.canStartRecording else { return }

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

                screenContextEvents = []
                screenInferenceStatus = nil
                try await audioService.startRecording()
                await startScreenContextCaptureIfNeeded(selection: selection)
                await startAudioLevelMonitoring()
                resetAudioLevelSamples()
                state = .recording(session: RecordingSession())
            } catch let minuteError as MinuteError {
                await stopAudioLevelMonitoring()
                await screenContextCaptureService.cancelCapture()
                screenInferenceStatus = nil
                screenContextEvents = []
                state = .failed(error: minuteError, debugOutput: minuteError.debugSummary)
            } catch {
                await stopAudioLevelMonitoring()
                await screenContextCaptureService.cancelCapture()
                screenInferenceStatus = nil
                screenContextEvents = []
                state = .failed(error: .audioExportFailed, debugOutput: String(describing: error))
            }
        }
    }

    private func stopRecordingIfAllowed() {
        guard case .recording(let session) = state else { return }

        let stoppedAt = Date()

        Task {
            do {
                let result = try await audioService.stopRecording()
                if let captureResult = await stopScreenContextCapture() {
                    screenContextEvents = captureResult.events
                    screenInferenceStatus = ScreenInferenceStatus(
                        processedCount: captureResult.processedCount,
                        skippedCount: captureResult.skippedCount,
                        isInferenceRunning: false
                    )
                }
                await stopAudioLevelMonitoring()
                resetAudioLevelSamples()
                state = .recorded(
                    audioTempURL: result.wavURL,
                    durationSeconds: result.duration,
                    startedAt: session.startedAt,
                    stoppedAt: stoppedAt
                )
            } catch let minuteError as MinuteError {
                await stopAudioLevelMonitoring()
                await screenContextCaptureService.cancelCapture()
                screenInferenceStatus = nil
                screenContextEvents = []
                state = .failed(error: minuteError, debugOutput: minuteError.debugSummary)
            } catch {
                await stopAudioLevelMonitoring()
                await screenContextCaptureService.cancelCapture()
                screenInferenceStatus = nil
                screenContextEvents = []
                state = .failed(error: .audioExportFailed, debugOutput: String(describing: error))
            }
        }
    }

    private func importFileIfAllowed(_ url: URL) {
        guard state.canImportMedia else { return }

        processingTask?.cancel()
        progress = nil
        screenContextEvents = []
        screenInferenceStatus = nil
        state = .importing(sourceURL: url)

        processingTask = Task(priority: .userInitiated) { [weak self] in
            guard let self else { return }
            do {
                let result = try await mediaImportService.importMedia(from: url)
                if screenContextSettingsStore.isVideoImportEnabled {
                    screenInferenceStatus = ScreenInferenceStatus(processedCount: 0, skippedCount: 0, isInferenceRunning: true)
                    if let inferenceResult = await extractScreenContextForImport(sourceURL: url) {
                        screenContextEvents = inferenceResult.events
                        screenInferenceStatus = ScreenInferenceStatus(
                            processedCount: inferenceResult.processedCount,
                            skippedCount: 0,
                            isInferenceRunning: false
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
                state = .idle
            } catch let minuteError as MinuteError {
                progress = nil
                screenInferenceStatus = nil
                screenContextEvents = []
                state = .failed(error: minuteError, debugOutput: minuteError.debugSummary)
            } catch {
                progress = nil
                screenInferenceStatus = nil
                screenContextEvents = []
                state = .failed(error: .audioExportFailed, debugOutput: String(describing: error))
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
        guard state.canCancelProcessing else { return }
        processingTask?.cancel()
    }

    private func resetIfAllowed() {
        guard state.canReset else { return }
        progress = nil
        state = .idle
        resetAudioLevelSamples()
        screenInferenceStatus = nil
        screenContextEvents = []
    }

    // MARK: - Pipeline

    private func startScreenContextCaptureIfNeeded(selection: ScreenContextWindowSelection?) async {
        guard screenContextSettingsStore.isEnabled else { return }
        guard let selection else { return }
        let selections = [selection]

        do {
            try await screenContextCaptureService.startCapture(
                selections: selections,
                minimumFrameInterval: screenContextFrameIntervalSeconds,
                statusHandler: { [weak self] status in
                    Task { @MainActor [weak self] in
                        self?.screenInferenceStatus = ScreenInferenceStatus(
                            processedCount: status.processedCount,
                            skippedCount: status.skippedCount,
                            isInferenceRunning: status.isInferenceRunning
                        )
                    }
                }
            )
        } catch {
            logger.error("Screen context capture failed: \(String(describing: error), privacy: .public)")
        }
    }

    private func stopScreenContextCapture() async -> ScreenContextCaptureResult? {
        await screenContextCaptureService.stopCapture()
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
            logger.error("Video screen context failed: \(String(describing: error), privacy: .public)")
            return nil
        }
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
            state = .failed(error: .vaultWriteFailed, debugOutput: String(describing: error))
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
        let defaults = UserDefaults.standard
        let meetings = defaults.string(forKey: DefaultsKey.meetingsRelativePath) ?? "Meetings"
        let audio = defaults.string(forKey: DefaultsKey.audioRelativePath) ?? "Meetings/_audio"
        let transcripts = defaults.string(forKey: DefaultsKey.transcriptsRelativePath) ?? "Meetings/_transcripts"
        let saveAudio = defaults.object(forKey: AppDefaultsKey.saveAudio) as? Bool ?? true
        let saveTranscript = defaults.object(forKey: AppDefaultsKey.saveTranscript) as? Bool ?? true

        // Validate vault selection.
        do {
            _ = try vaultAccess.resolveVaultRootURL()
        } catch {
            return nil
        }

        let workingDirectoryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("minute-work-\(UUID().uuidString)", isDirectory: true)

        return PipelineContext(
            vaultFolders: MeetingFileContract.VaultFolders(meetingsRoot: meetings, audioRoot: audio, transcriptsRoot: transcripts),
            audioTempURL: audioTempURL,
            audioDurationSeconds: audioDurationSeconds,
            startedAt: startedAt,
            stoppedAt: stoppedAt,
            workingDirectoryURL: workingDirectoryURL,
            saveAudio: saveAudio,
            saveTranscript: saveTranscript,
            screenContextEvents: screenContextEvents
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
            lines.append(error.errorDescription ?? "Error")
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
        if let minuteError = error as? MinuteError {
            self.error = minuteError
        } else {
            self.error = .whisperFailed(exitCode: -1, output: String(describing: error))
        }
    }

    func transcribe(wavURL: URL) async throws -> TranscriptionResult {
        throw error
    }
}
