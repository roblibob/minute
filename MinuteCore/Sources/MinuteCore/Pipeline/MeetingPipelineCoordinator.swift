import Foundation
import os

public actor MeetingPipelineCoordinator {
    private let transcriptionService: any TranscriptionServicing
    private let diarizationService: any DiarizationServicing
    private let summarizationServiceProvider: () -> any SummarizationServicing
    private let modelManager: any ModelManaging
    private let vaultAccess: VaultAccess
    private let vaultWriter: any VaultWriting
    private let dateProvider: @Sendable () -> Date

    private let logger = Logger(subsystem: "roblibob.Minute", category: "pipeline")

    public init(
        transcriptionService: some TranscriptionServicing,
        diarizationService: some DiarizationServicing,
        summarizationServiceProvider: @escaping () -> any SummarizationServicing,
        modelManager: some ModelManaging,
        vaultAccess: VaultAccess,
        vaultWriter: some VaultWriting,
        dateProvider: @escaping @Sendable () -> Date = Date.init
    ) {
        self.transcriptionService = transcriptionService
        self.diarizationService = diarizationService
        self.summarizationServiceProvider = summarizationServiceProvider
        self.modelManager = modelManager
        self.vaultAccess = vaultAccess
        self.vaultWriter = vaultWriter
        self.dateProvider = dateProvider
    }

    public func execute(
        context: PipelineContext,
        progress: (@Sendable (PipelineProgress) -> Void)? = nil
    ) async throws -> PipelineResult {
        do {
            try Task.checkCancellation()

            progress?(.downloadingModels(fractionCompleted: 0))
            try await modelManager.ensureModelsPresent { update in
                let clamped = min(max(update.fractionCompleted, 0), 1)
                progress?(.downloadingModels(fractionCompleted: clamped * 0.1))
            }

            try Task.checkCancellation()
            progress?(.transcribing(fractionCompleted: 0.1))

            let transcription = try await transcriptionService.transcribe(wavURL: context.audioTempURL)
            let diarizationSegments = await diarizeIfPossible(wavURL: context.audioTempURL)
            let attributedSegments = SpeakerAttribution.attribute(
                transcriptSegments: transcription.segments,
                speakerSegments: diarizationSegments
            )
            let timelineSegments: [AttributedTranscriptSegment]
            if attributedSegments.isEmpty {
                timelineSegments = transcription.segments.map { segment in
                    AttributedTranscriptSegment(
                        startSeconds: segment.startSeconds,
                        endSeconds: segment.endSeconds,
                        speakerId: 0,
                        text: segment.text
                    )
                }
            } else {
                timelineSegments = attributedSegments
            }
            let timelineEntries = MeetingTimelineBuilder.build(
                transcriptSegments: timelineSegments,
                screenEvents: context.screenContextEvents
            )
            let timelineText = MeetingTimelineRenderer().render(entries: timelineEntries)

            try Task.checkCancellation()
            progress?(.summarizing(fractionCompleted: 0.5))

            let summarizationService = summarizationServiceProvider()
            let meetingDate = context.startedAt
            let rawJSON = try await summarizationService.summarize(
                transcript: timelineText,
                meetingDate: meetingDate
            )
            let extraction = try await decodeOrRepairExtraction(
                rawJSON: rawJSON,
                meetingDate: meetingDate,
                summarizationService: summarizationService
            )

            try Task.checkCancellation()
            progress?(.writing(fractionCompleted: 0.85, extraction: extraction))

            let outputs = try writeOutputsToVault(
                context: context,
                extraction: extraction,
                transcription: transcription,
                attributedSegments: attributedSegments
            )

            cleanupTemporaryArtifacts(for: context)
            return outputs
        } catch is CancellationError {
            logger.info("Pipeline cancelled")
            throw CancellationError()
        } catch {
            if let minuteError = error as? MinuteError {
                logger.error("Pipeline failed: \(minuteError.debugSummary, privacy: .public)")
            } else {
                logger.error("Pipeline failed: \(String(describing: error), privacy: .public)")
            }
            cleanupTemporaryArtifacts(for: context)
            throw error
        }
    }

    private func decodeOrRepairExtraction(
        rawJSON: String,
        meetingDate: Date,
        summarizationService: any SummarizationServicing
    ) async throws -> MeetingExtraction {
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

    private func writeOutputsToVault(
        context: PipelineContext,
        extraction: MeetingExtraction,
        transcription: TranscriptionResult,
        attributedSegments: [AttributedTranscriptSegment]
    ) throws -> PipelineResult {
        let recordingDate = context.startedAt
        // Use extraction.date if parseable, otherwise fall back to the recording date.
        let meetingDate = MinuteISODate.parse(extraction.date) ?? recordingDate
        let meetingDateISO = MinuteISODate.format(meetingDate)

        let contract = MeetingFileContract(folders: context.vaultFolders)
        let noteRelativePath = contract.noteRelativePath(date: recordingDate, title: extraction.title)
        let audioRelativePath = context.saveAudio ? contract.audioRelativePath(date: recordingDate, title: extraction.title) : nil
        let transcriptRelativePath = context.saveTranscript ? contract.transcriptRelativePath(date: recordingDate, title: extraction.title) : nil

        let transcriptData: Data?
        if transcriptRelativePath != nil {
            let transcriptMarkdown = TranscriptMarkdownRenderer().render(
                title: extraction.title,
                dateISO: meetingDateISO,
                transcript: transcription.text,
                attributedSegments: attributedSegments
            )
            transcriptData = Data(transcriptMarkdown.utf8)
        } else {
            transcriptData = nil
        }

        let processedDateTime = MeetingNoteDateFormatter.format(dateProvider())
        let noteMarkdown = MarkdownRenderer().render(
            extraction: extraction,
            noteDateTime: processedDateTime,
            audioRelativePath: audioRelativePath,
            transcriptRelativePath: transcriptRelativePath
        )
        let noteData = Data(noteMarkdown.utf8)

        return try vaultAccess.withVaultAccess { vaultRootURL in
            let noteURL = vaultRootURL.appendingPathComponent(noteRelativePath)

            // Transcript
            if let transcriptRelativePath, let transcriptData {
                let transcriptURL = vaultRootURL.appendingPathComponent(transcriptRelativePath)
                try vaultWriter.writeAtomically(data: transcriptData, to: transcriptURL)
            }

            // Note
            try vaultWriter.writeAtomically(data: noteData, to: noteURL)

            // Audio (temporary implementation reads into memory; task 08 will stream/copy atomically).
            let audioURL: URL?
            if let audioRelativePath {
                let audioData = try Data(contentsOf: context.audioTempURL)
                let resolvedURL = vaultRootURL.appendingPathComponent(audioRelativePath)
                try vaultWriter.writeAtomically(data: audioData, to: resolvedURL)
                audioURL = resolvedURL
            } else {
                audioURL = nil
            }

            return PipelineResult(noteURL: noteURL, audioURL: audioURL)
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

    private func cleanupTemporaryArtifacts(for context: PipelineContext) {
        let fileManager = FileManager.default
        let tempRootURL = fileManager.temporaryDirectory.standardizedFileURL
        let tempRootPath = tempRootURL.path.hasSuffix("/") ? tempRootURL.path : tempRootURL.path + "/"

        let audioTempDir = context.audioTempURL.deletingLastPathComponent().standardizedFileURL.path
        if audioTempDir.hasPrefix(tempRootPath) {
            try? fileManager.removeItem(atPath: audioTempDir)
        }

        let workingDir = context.workingDirectoryURL.standardizedFileURL.path
        if workingDir.hasPrefix(tempRootPath) {
            try? fileManager.removeItem(atPath: workingDir)
        }
    }
}
