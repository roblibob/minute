import Foundation
import os

public actor MeetingPipelineCoordinator {
    private let transcriptionService: any TranscriptionServicing
    private let diarizationService: any DiarizationServicing
    private let audioLoudnessNormalizer: any AudioLoudnessNormalizing
    private let summarizationServiceProvider: () -> any SummarizationServicing
    private let modelManager: any ModelManaging
    private let vaultAccess: VaultAccess
    private let vaultWriter: any VaultWriting
    private let speakerProfileStore: SpeakerProfileStore
    private let dateProvider: @Sendable () -> Date

    private let logger = Logger(subsystem: "roblibob.Minute", category: "pipeline")

    public init(
        transcriptionService: some TranscriptionServicing,
        diarizationService: some DiarizationServicing,
        summarizationServiceProvider: @escaping () -> any SummarizationServicing,
        audioLoudnessNormalizer: any AudioLoudnessNormalizing = NoOpAudioLoudnessNormalizer(),
        modelManager: some ModelManaging,
        vaultAccess: VaultAccess,
        vaultWriter: some VaultWriting,
        speakerProfileStore: SpeakerProfileStore = SpeakerProfileStore(),
        dateProvider: @escaping @Sendable () -> Date = Date.init
    ) {
        self.transcriptionService = transcriptionService
        self.diarizationService = diarizationService
        self.audioLoudnessNormalizer = audioLoudnessNormalizer
        self.summarizationServiceProvider = summarizationServiceProvider
        self.modelManager = modelManager
        self.vaultAccess = vaultAccess
        self.vaultWriter = vaultWriter
        self.speakerProfileStore = speakerProfileStore
        self.dateProvider = dateProvider
    }

    public func execute(
        context: PipelineContext,
        progress: (@Sendable (PipelineProgress) -> Void)? = nil
    ) async throws -> PipelineResult {
        do {
            var context = context
            try Task.checkCancellation()

            progress?(.downloadingModels(fractionCompleted: 0))
            try await modelManager.ensureModelsPresent { update in
                let clamped = min(max(update.fractionCompleted, 0), 1)
                progress?(.downloadingModels(fractionCompleted: clamped * 0.1))
            }

            try Task.checkCancellation()
            progress?(.transcribing(fractionCompleted: 0.1))

            if context.normalizeAnalysisAudio {
                do {
                    let normalizedURL = try await audioLoudnessNormalizer.normalizeForAnalysis(
                        inputURL: context.audioTempURL,
                        workingDirectoryURL: context.workingDirectoryURL
                    )
                    context.analysisAudioURL = normalizedURL
                } catch {
                    // Normalization is a quality improvement. If ffmpeg is missing or input audio is unreadable,
                    // proceed with the original analysis audio rather than failing the whole pipeline.
                    logger.error("Analysis audio normalization failed; proceeding without normalization: \(ErrorHandler.debugMessage(for: error), privacy: .public)")
                }
            }

            // Capture the canonical audio bytes early (analysis normalization must not affect vault output).
            // This also decouples the vault write from the temp-file lifetime across async boundaries.
            let originalAudioData: Data?
            if context.saveAudio {
                originalAudioData = try Data(contentsOf: context.audioTempURL)
            } else {
                originalAudioData = nil
            }

            let transcription: TranscriptionResult
            if let override = context.transcriptionOverride, !override.text.isEmpty {
                transcription = override
            } else {
                transcription = try await transcriptionService.transcribe(wavURL: context.analysisAudioURL)
            }
            let embeddingExportURL = context.knownSpeakerSuggestionsEnabled
                ? context.workingDirectoryURL.appendingPathComponent("diarization-embeddings.json")
                : nil

            let diarizationSegments = await diarizeIfPossible(
                wavURL: context.analysisAudioURL,
                embeddingExportURL: embeddingExportURL
            )
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
            
            var effectiveType = context.meetingType
            if effectiveType == .autodetect {
                effectiveType = try await summarizationService.classify(transcript: timelineText)
                logger.info("Autodetected meeting type: \(effectiveType.rawValue, privacy: .public)")
            }
            
            let rawJSON = try await summarizationService.summarize(
                transcript: timelineText,
                meetingDate: meetingDate,
                meetingType: effectiveType
            )
            var extraction = try await decodeOrRepairExtraction(
                rawJSON: rawJSON,
                meetingDate: meetingDate,
                summarizationService: summarizationService
            )
            extraction.meetingType = effectiveType

            try Task.checkCancellation()
            progress?(.writing(fractionCompleted: 0.85, extraction: extraction))

            let participantFrontmatter = await suggestKnownSpeakersFrontmatterIfEnabled(
                context: context,
                diarizationSegments: diarizationSegments,
                embeddingExportURL: embeddingExportURL
            )

            let outputs = try writeOutputsToVault(
                context: context,
                extraction: extraction,
                transcription: transcription,
                attributedSegments: attributedSegments,
                originalAudioData: originalAudioData,
                participantFrontmatter: participantFrontmatter
            )

            cleanupTemporaryArtifacts(for: context)
            return outputs
        } catch is CancellationError {
            logger.info("Pipeline cancelled")
            throw CancellationError()
        } catch {
            logger.error("Pipeline failed: \(ErrorHandler.debugMessage(for: error), privacy: .public)")
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
        attributedSegments: [AttributedTranscriptSegment],
        originalAudioData: Data?,
        participantFrontmatter: MeetingParticipantFrontmatter?
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

        return try vaultAccess.withVaultAccess { vaultRootURL in
            let resolvedPaths = resolveOutputPaths(
                vaultRootURL: vaultRootURL,
                noteRelativePath: noteRelativePath,
                audioRelativePath: audioRelativePath,
                transcriptRelativePath: transcriptRelativePath
            )

            let processedDateTime = MeetingNoteDateFormatter.format(dateProvider())
            let noteMarkdown = MarkdownRenderer().render(
                extraction: extraction,
                noteDateTime: processedDateTime,
                audioDurationSeconds: context.audioDurationSeconds,
                audioRelativePath: resolvedPaths.audioRelativePath,
                transcriptRelativePath: resolvedPaths.transcriptRelativePath,
                participantFrontmatter: participantFrontmatter
            )
            let noteData = Data(noteMarkdown.utf8)

            let noteURL = vaultRootURL.appendingPathComponent(resolvedPaths.noteRelativePath)

            // Transcript
            if let transcriptRelativePath = resolvedPaths.transcriptRelativePath, let transcriptData {
                let transcriptURL = vaultRootURL.appendingPathComponent(transcriptRelativePath)
                try vaultWriter.writeAtomically(data: transcriptData, to: transcriptURL)
            }

            // Note
            try vaultWriter.writeAtomically(data: noteData, to: noteURL)

            // Audio (temporary implementation reads into memory; task 08 will stream/copy atomically).
            let audioURL: URL?
            if let audioRelativePath = resolvedPaths.audioRelativePath {
                guard let audioData = originalAudioData else {
                    throw MinuteError.audioExportFailed
                }
                let resolvedURL = vaultRootURL.appendingPathComponent(audioRelativePath)
                try vaultWriter.writeAtomically(data: audioData, to: resolvedURL)
                audioURL = resolvedURL
            } else {
                audioURL = nil
            }

            return PipelineResult(noteURL: noteURL, audioURL: audioURL)
        }
    }

    private func resolveOutputPaths(
        vaultRootURL: URL,
        noteRelativePath: String,
        audioRelativePath: String?,
        transcriptRelativePath: String?
    ) -> (noteRelativePath: String, audioRelativePath: String?, transcriptRelativePath: String?) {
        let fileManager = FileManager.default

        func normalizeRelativePath(_ relativePath: String) -> String {
            relativePath.hasPrefix("/") ? String(relativePath.dropFirst()) : relativePath
        }

        let noteRelativePath = normalizeRelativePath(noteRelativePath)
        let audioRelativePath = audioRelativePath.map(normalizeRelativePath)
        let transcriptRelativePath = transcriptRelativePath.map(normalizeRelativePath)

        func withSuffix(_ relativePath: String, suffix: String) -> String {
            let ns = relativePath as NSString
            let ext = ns.pathExtension
            let base = ns.deletingPathExtension
            return ext.isEmpty ? base + suffix : base + suffix + "." + ext
        }

        func exists(_ relativePath: String?) -> Bool {
            guard let relativePath else { return false }
            return fileManager.fileExists(atPath: vaultRootURL.appendingPathComponent(relativePath).path)
        }

        // Fast path: no collision.
        if !exists(noteRelativePath) {
            return (noteRelativePath, audioRelativePath, transcriptRelativePath)
        }

        // Collision: choose a stable, user-readable suffix.
        for index in 2...99 {
            let suffix = " (\(index))"
            let candidateNote = withSuffix(noteRelativePath, suffix: suffix)
            let candidateAudio = audioRelativePath.map { withSuffix($0, suffix: suffix) }
            let candidateTranscript = transcriptRelativePath.map { withSuffix($0, suffix: suffix) }

            if !exists(candidateNote), !exists(candidateAudio), !exists(candidateTranscript) {
                return (candidateNote, candidateAudio, candidateTranscript)
            }
        }

        // As a last resort, fall back to the original path (writer will overwrite or throw depending on implementation).
        return (noteRelativePath, audioRelativePath, transcriptRelativePath)
    }

    private func diarizeIfPossible(wavURL: URL, embeddingExportURL: URL?) async -> [SpeakerSegment] {
        do {
            return try await diarizationService.diarize(wavURL: wavURL, embeddingExportURL: embeddingExportURL)
        } catch {
            logger.error("Diarization failed: \(ErrorHandler.debugMessage(for: error), privacy: .public)")
            return []
        }
    }

    private func suggestKnownSpeakersFrontmatterIfEnabled(
        context: PipelineContext,
        diarizationSegments: [SpeakerSegment],
        embeddingExportURL: URL?
    ) async -> MeetingParticipantFrontmatter? {
        guard context.knownSpeakerSuggestionsEnabled else { return nil }
        guard let embeddingExportURL else { return nil }

        do {
            let entries = try OfflineDiarizerEmbeddingExport.load(from: embeddingExportURL)
            let aggregated = try OfflineDiarizerEmbeddingExport.aggregateByCluster(entries: entries)
            if aggregated.isEmpty { return nil }

            let meetingSpeakerOrder = SpeakerOrdering.orderedSpeakerIDs(from: diarizationSegments)
            let clusters = aggregated.map(\.speakerCluster).sorted()
            let speakerIDsSorted = Array(Set(meetingSpeakerOrder)).sorted()

            // Best-effort mapping: align sorted cluster IDs with sorted speaker IDs.
            // If counts mismatch, fall back to matching by cluster value.
            let clusterToSpeakerId: [Int: Int]
            if clusters.count == speakerIDsSorted.count, !clusters.isEmpty {
                var map: [Int: Int] = [:]
                for i in 0..<clusters.count {
                    map[clusters[i]] = speakerIDsSorted[i]
                }
                clusterToSpeakerId = map
            } else {
                clusterToSpeakerId = Dictionary(uniqueKeysWithValues: clusters.map { ($0, $0) })
            }

            let profiles = try await speakerProfileStore.listProfiles()
            if profiles.isEmpty { return nil }

            let matcher = SpeakerEmbeddingMatcher()

            var speakerMap: [Int: String] = [:]
            for item in aggregated {
                let speakerId = clusterToSpeakerId[item.speakerCluster] ?? item.speakerCluster
                if let match = try matcher.bestMatch(
                    embedding: item.embedding,
                    candidates: profiles,
                    embeddingModelVersion: SpeakerEmbeddingModelVersions.fluidAudioOfflineVbx256
                ) {
                    speakerMap[speakerId] = match.profile.name
                }
            }

            let participants = Array(Set(speakerMap.values)).sorted()
            if participants.isEmpty && speakerMap.isEmpty { return nil }

            let speakerOrder = meetingSpeakerOrder
            return MeetingParticipantFrontmatter(
                participants: participants,
                speakerMap: speakerMap,
                speakerOrder: speakerOrder
            )
        } catch {
            // Suggestions are best-effort: never fail the pipeline.
            logger.error("Known-speaker suggestion step failed: \(ErrorHandler.debugMessage(for: error), privacy: .public)")
            return nil
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
