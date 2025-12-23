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

    @Published private(set) var state: MeetingPipelineState = .idle
    @Published private(set) var progress: Double? = nil
    @Published private(set) var vaultStatus: VaultStatus = VaultStatus(displayText: "Not selected", isConfigured: false)
    @Published private(set) var microphonePermissionGranted: Bool = false
    @Published private(set) var screenRecordingPermissionGranted: Bool = false
    @Published private(set) var audioLevelSamples: [CGFloat] = Array(repeating: 0, count: 24)

    private let audioService: any AudioServicing
    private let mediaImportService: any MediaImporting
    private let transcriptionService: any TranscriptionServicing
    private let diarizationService: any DiarizationServicing
    private let summarizationService: any SummarizationServicing
    private let modelManager: any ModelManaging

    private let bookmarkStore: UserDefaultsVaultBookmarkStore
    private let vaultAccess: VaultAccess
    private let vaultWriter: any VaultWriting

    private let logger = Logger(subsystem: "roblibob.Minute", category: "pipeline")

    private var defaultsObserver: AnyCancellable?
    private var processingTask: Task<Void, Never>?
    private var lastAudioLevelUpdate: CFTimeInterval = 0

    private let audioLevelBucketCount = 24
    private let audioLevelUpdateInterval: CFTimeInterval = 1.0 / 24.0
	
    init(
        audioService: some AudioServicing,
        mediaImportService: some MediaImporting,
        transcriptionService: some TranscriptionServicing,
        diarizationService: some DiarizationServicing,
        summarizationService: some SummarizationServicing,
        modelManager: some ModelManaging,
        bookmarkStore: UserDefaultsVaultBookmarkStore,
        vaultWriter: some VaultWriting
    ) {
        self.audioService = audioService
        self.mediaImportService = mediaImportService
        self.transcriptionService = transcriptionService
        self.diarizationService = diarizationService
        self.summarizationService = summarizationService
        self.modelManager = modelManager
        self.bookmarkStore = bookmarkStore
        self.vaultAccess = VaultAccess(bookmarkStore: bookmarkStore)
        self.vaultWriter = vaultWriter

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
    }

    static func mock() -> MeetingPipelineViewModel {
        MeetingPipelineViewModel(
            audioService: MockAudioService(),
            mediaImportService: MockMediaImportService(),
            transcriptionService: MockTranscriptionService(),
            diarizationService: MockDiarizationService(),
            summarizationService: MockSummarizationService(),
            modelManager: MockModelManager(),
            bookmarkStore: UserDefaultsVaultBookmarkStore(key: DefaultsKey.vaultRootBookmark),
            vaultWriter: DefaultVaultWriter()
        )
    }

    static func live() -> MeetingPipelineViewModel {
        let summarizationService: any SummarizationServicing = LlamaLibrarySummarizationService.liveDefault()
        let transcriptionService: any TranscriptionServicing = WhisperXPCTranscriptionService.liveDefault()

        return MeetingPipelineViewModel(
            audioService: DefaultAudioService(),
            mediaImportService: DefaultMediaImportService(),
            transcriptionService: transcriptionService,
            diarizationService: FluidAudioDiarizationService.meetingDefault(),
            summarizationService: summarizationService,
            modelManager: DefaultModelManager(),
            bookmarkStore: UserDefaultsVaultBookmarkStore(key: DefaultsKey.vaultRootBookmark),
            vaultWriter: DefaultVaultWriter()
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
            startRecordingIfAllowed()
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

    private func startRecordingIfAllowed() {
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

                let screenGranted = CGPreflightScreenCaptureAccess()
                if screenGranted {
                    screenRecordingPermissionGranted = true
                } else {
                    let granted = CGRequestScreenCaptureAccess()
                    screenRecordingPermissionGranted = granted
                    if !granted {
                        throw MinuteError.screenRecordingPermissionDenied
                    }
                }

                try await audioService.startRecording()
                await startAudioLevelMonitoring()
                resetAudioLevelSamples()
                state = .recording(session: RecordingSession())
            } catch let minuteError as MinuteError {
                await stopAudioLevelMonitoring()
                state = .failed(error: minuteError, debugOutput: minuteError.debugSummary)
            } catch {
                await stopAudioLevelMonitoring()
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
                state = .failed(error: minuteError, debugOutput: minuteError.debugSummary)
            } catch {
                await stopAudioLevelMonitoring()
                state = .failed(error: .audioExportFailed, debugOutput: String(describing: error))
            }
        }
    }

    private func importFileIfAllowed(_ url: URL) {
        guard state.canImportMedia else { return }

        processingTask?.cancel()
        progress = nil
        state = .importing(sourceURL: url)

        processingTask = Task(priority: .userInitiated) { [weak self] in
            guard let self else { return }
            do {
                let result = try await mediaImportService.importMedia(from: url)
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
                state = .idle
            } catch let minuteError as MinuteError {
                progress = nil
                state = .failed(error: minuteError, debugOutput: minuteError.debugSummary)
            } catch {
                progress = nil
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
            stoppedAt: stoppedAt
        ) else {
            state = .failed(error: .vaultUnavailable, debugOutput: nil)
            return
        }

        // One active task at a time.
        processingTask?.cancel()
        progress = 0

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
    }

    // MARK: - Pipeline

    private func runPipeline(context: PipelineContext) async {
        do {
            try Task.checkCancellation()

            // Download models (task 09)
            state = .processing(stage: .downloadingModels, context: context)
            progress = 0

            logger.info("Ensuring models are present")
            try await modelManager.ensureModelsPresent { [weak self] update in
                // Allocate the first 10% of the overall pipeline progress to model downloads.
                Task { @MainActor [weak self] in
                    self?.progress = min(max(update.fractionCompleted, 0), 1) * 0.1
                }
            }

            // Transcribe
            state = .processing(stage: .transcribing, context: context)
            progress = 0.1
            try Task.checkCancellation()

            let transcription = try await transcriptionService.transcribe(wavURL: context.audioTempURL)
            let diarizationSegments = await diarizeIfPossible(wavURL: context.audioTempURL)
            let attributedSegments = SpeakerAttribution.attribute(
                transcriptSegments: transcription.segments,
                speakerSegments: diarizationSegments
            )

            // Summarize (+ repair if needed)
            state = .processing(stage: .summarizing, context: context)
            progress = 0.5
            try Task.checkCancellation()

            let meetingDate = context.startedAt
            let rawJSON = try await summarizationService.summarize(transcript: transcription.text, meetingDate: meetingDate)
            let extraction = try await decodeOrRepairExtraction(rawJSON: rawJSON, meetingDate: meetingDate)

            // Write
            state = .writing(context: context, extraction: extraction)
            progress = 0.85
            try Task.checkCancellation()

            let outputs = try writeOutputsToVault(
                context: context,
                extraction: extraction,
                transcription: transcription,
                attributedSegments: attributedSegments
            )

            progress = nil
            state = .done(noteURL: outputs.noteURL, audioURL: outputs.audioURL)
        } catch is CancellationError {
            logger.info("Pipeline cancelled")
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
            logger.error("Pipeline failed: \(minuteError.debugSummary, privacy: .public)")
            progress = nil
            state = .failed(error: minuteError, debugOutput: minuteError.debugSummary)
        } catch {
            logger.error("Pipeline failed: \(String(describing: error), privacy: .public)")
            progress = nil
            state = .failed(error: .vaultWriteFailed, debugOutput: String(describing: error))
        }
    }

    private func decodeOrRepairExtraction(rawJSON: String, meetingDate: Date) async throws -> MeetingExtraction {
        do {
            let decoded = try decodeExtractionStrict(from: rawJSON)
            return MeetingExtractionValidation.validated(decoded, recordingDate: meetingDate)
        } catch {
            logger.info("Extraction JSON invalid; attempting repair")

            let repaired = try await summarizationService.repairJSON(rawJSON)

            do {
                let decoded = try decodeExtractionStrict(from: repaired)
                return MeetingExtractionValidation.validated(decoded, recordingDate: meetingDate)
            } catch {
                // Task 07: proceed with a fallback extraction rather than failing the entire pipeline.
                logger.error("Extraction still invalid after repair; proceeding with fallback")
                return MeetingExtractionValidation.fallback(recordingDate: meetingDate)
            }
        }
    }

    /// Strictly decodes the first top-level JSON object and rejects any non-whitespace outside it.
    private func decodeExtractionStrict(from rawOutput: String) throws -> MeetingExtraction {
        let trimmed = rawOutput.trimmingCharacters(in: .whitespacesAndNewlines)

        guard let extracted = JSONFirstObjectExtractor.extractFirstJSONObject(from: trimmed) else {
            throw MinuteError.jsonInvalid
        }

        do {
            return try JSONDecoder().decode(MeetingExtraction.self, from: Data(extracted.jsonObject.utf8))
        } catch {
            throw MinuteError.jsonInvalid
        }
    }

    private func makePipelineContext(
        audioTempURL: URL,
        audioDurationSeconds: TimeInterval,
        startedAt: Date,
        stoppedAt: Date
    ) -> PipelineContext? {
        let defaults = UserDefaults.standard
        let meetings = defaults.string(forKey: DefaultsKey.meetingsRelativePath) ?? "Meetings"
        let audio = defaults.string(forKey: DefaultsKey.audioRelativePath) ?? "Meetings/_audio"
        let transcripts = defaults.string(forKey: DefaultsKey.transcriptsRelativePath) ?? "Meetings/_transcripts"

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
            workingDirectoryURL: workingDirectoryURL
        )
    }

    private func writeOutputsToVault(
        context: PipelineContext,
        extraction: MeetingExtraction,
        transcription: TranscriptionResult,
        attributedSegments: [AttributedTranscriptSegment]
    ) throws -> (noteURL: URL, audioURL: URL) {
        // Use extraction.date if parseable, otherwise fall back to the recording date.
        let meetingDate = MinuteISODate.parse(extraction.date) ?? context.startedAt
        let meetingDateISO = MinuteISODate.format(meetingDate)

        let contract = MeetingFileContract(folders: context.vaultFolders)
        let noteRelativePath = contract.noteRelativePath(date: meetingDate, title: extraction.title)
        let audioRelativePath = contract.audioRelativePath(date: meetingDate, title: extraction.title)
        let transcriptRelativePath = contract.transcriptRelativePath(date: meetingDate, title: extraction.title)

        let transcriptMarkdown = TranscriptMarkdownRenderer().render(
            title: extraction.title,
            dateISO: meetingDateISO,
            transcript: transcription.text,
            attributedSegments: attributedSegments
        )
        let transcriptData = Data(transcriptMarkdown.utf8)

        let noteMarkdown = MarkdownRenderer().render(
            extraction: extraction,
            audioRelativePath: audioRelativePath
        )
        let noteData = Data(noteMarkdown.utf8)

        return try vaultAccess.withVaultAccess { vaultRootURL in
            let noteURL = vaultRootURL.appendingPathComponent(noteRelativePath)
            let audioURL = vaultRootURL.appendingPathComponent(audioRelativePath)
            let transcriptURL = vaultRootURL.appendingPathComponent(transcriptRelativePath)

            // Transcript
            try vaultWriter.writeAtomically(data: transcriptData, to: transcriptURL)

            // Note
            try vaultWriter.writeAtomically(data: noteData, to: noteURL)

            // Audio (temporary implementation reads into memory; task 08 will stream/copy atomically).
            let audioData = try Data(contentsOf: context.audioTempURL)
            try vaultWriter.writeAtomically(data: audioData, to: audioURL)

            return (noteURL: noteURL, audioURL: audioURL)
        }
    }

    private func diarizeIfPossible(wavURL: URL) async -> [SpeakerSegment] {
        do {
            return try await diarizationService.diarize(wavURL: wavURL)
        } catch {
            logger.error("Diarization failed: \(String(describing: error), privacy: .public)")
            return []
        }
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
        Task {
            let granted = CGRequestScreenCaptureAccess()
            screenRecordingPermissionGranted = granted
        }
    }

    private func refreshMicrophonePermission() {
        let status = AVCaptureDevice.authorizationStatus(for: .audio)
        microphonePermissionGranted = (status == .authorized)
    }

    private func refreshScreenRecordingPermission() {
        screenRecordingPermissionGranted = CGPreflightScreenCaptureAccess()
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
