import Foundation
import os

public actor MeetingPipelineCoordinator {
    private let transcriptionService: any TranscriptionServicing
    private let diarizationService: any DiarizationServicing
    private let audioLoudnessNormalizer: any AudioLoudnessNormalizing
    private let summarizationServiceProvider: @Sendable () -> any SummarizationServicing
    private let modelManager: any ModelManaging
    private let meetingTypeLibraryStore: any MeetingTypeLibraryStoring
    private let promptBundleResolver: any ResolvedPromptBundleResolving
    private let checkpointStore: any SummarizationCheckpointStoring
    private let runGate: any MeetingRunGating
    private let vaultAccess: VaultAccess
    private let vaultWriter: any VaultWriting
    private let speakerProfileStore: SpeakerProfileStore
    private let meetingSpeakerEmbeddingCache: MeetingSpeakerEmbeddingCache
    private let summarizationServiceForBinding: (@Sendable (InferenceTaskBinding) -> any SummarizationServicing)?
    private let summarizationModelIDProvider: @Sendable () -> String
    private let summarizationPreflightConfigurationForBinding: (@Sendable (InferenceTaskBinding) -> SummarizationPreflightConfiguration)?
    private let summarizationPreflightConfigurationProvider: @Sendable () -> SummarizationPreflightConfiguration
    private let dateProvider: @Sendable () -> Date

    private let logger = Logger(subsystem: "roblibob.Minute", category: "pipeline")

    private struct ResolvedOutputPaths: Sendable {
        var noteRelativePath: String
        var audioRelativePath: String?
        var transcriptRelativePath: String?
    }

    private struct ReprocessInputs: Sendable {
        var existingNoteMarkdown: String
        var transcriptMarkdown: String
    }

    public init(
        transcriptionService: some TranscriptionServicing,
        diarizationService: some DiarizationServicing,
        summarizationServiceProvider: @escaping @Sendable () -> any SummarizationServicing,
        audioLoudnessNormalizer: any AudioLoudnessNormalizing = NoOpAudioLoudnessNormalizer(),
        modelManager: some ModelManaging,
        meetingTypeLibraryStore: any MeetingTypeLibraryStoring = MeetingTypeLibraryStore(),
        promptBundleResolver: any ResolvedPromptBundleResolving = ResolvedPromptBundleResolver(),
        checkpointStore: any SummarizationCheckpointStoring = DefaultSummarizationCheckpointStore(),
        runGate: any MeetingRunGating = SingleActiveMeetingRunGate(),
        vaultAccess: VaultAccess,
        vaultWriter: some VaultWriting,
        speakerProfileStore: SpeakerProfileStore = SpeakerProfileStore(),
        meetingSpeakerEmbeddingCache: MeetingSpeakerEmbeddingCache = MeetingSpeakerEmbeddingCache(),
        summarizationServiceForBinding: (@Sendable (InferenceTaskBinding) -> any SummarizationServicing)? = nil,
        summarizationModelIDProvider: @escaping @Sendable () -> String = { SummarizationModelCatalog.defaultModel.id },
        summarizationPreflightConfigurationForBinding: (@Sendable (InferenceTaskBinding) -> SummarizationPreflightConfiguration)? = nil,
        summarizationPreflightConfigurationProvider: @escaping @Sendable () -> SummarizationPreflightConfiguration = { .default },
        dateProvider: @escaping @Sendable () -> Date = Date.init
    ) {
        self.transcriptionService = transcriptionService
        self.diarizationService = diarizationService
        self.audioLoudnessNormalizer = audioLoudnessNormalizer
        self.summarizationServiceProvider = summarizationServiceProvider
        self.modelManager = modelManager
        self.meetingTypeLibraryStore = meetingTypeLibraryStore
        self.promptBundleResolver = promptBundleResolver
        self.checkpointStore = checkpointStore
        self.runGate = runGate
        self.vaultAccess = vaultAccess
        self.vaultWriter = vaultWriter
        self.speakerProfileStore = speakerProfileStore
        self.meetingSpeakerEmbeddingCache = meetingSpeakerEmbeddingCache
        self.summarizationServiceForBinding = summarizationServiceForBinding
        self.summarizationModelIDProvider = summarizationModelIDProvider
        self.summarizationPreflightConfigurationForBinding = summarizationPreflightConfigurationForBinding
        self.summarizationPreflightConfigurationProvider = summarizationPreflightConfigurationProvider
        self.dateProvider = dateProvider
    }

    public func execute(
        context: PipelineContext,
        progress: (@Sendable (PipelineProgress) -> Void)? = nil
    ) async throws -> PipelineResult {
        let meetingRunID = makeMeetingRunID(context: context)
        guard await runGate.beginIfPossible(meetingID: meetingRunID) else {
            throw MinuteError.pipelineRunAlreadyActive
        }

        do {
            let result = try await executePipelineRun(
                context: context,
                meetingRunID: meetingRunID,
                progress: progress
            )
            await runGate.end(meetingID: meetingRunID)
            return result
        } catch {
            await runGate.end(meetingID: meetingRunID)
            throw error
        }
    }

    public func reprocessMeeting(
        request: ReprocessMeetingRequest,
        progress: (@Sendable (PipelineProgress) -> Void)? = nil
    ) async throws -> PipelineResult {
        let meetingTypeLibrary = meetingTypeLibraryStore.load()
        let availableTargetTypeIDs = Set(
            meetingTypeLibrary.activeDefinitions
                .map(\.typeId)
                .filter { $0 != MeetingType.autodetect.rawValue }
        )
        let request = try request.validated(availableTargetTypeIDs: availableTargetTypeIDs)

        do {
            try Task.checkCancellation()
            progress?(.downloadingModels(fractionCompleted: 0))
            try await modelManager.ensureModelsPresent { update in
                let clamped = min(max(update.fractionCompleted, 0), 1)
                progress?(.downloadingModels(fractionCompleted: clamped * 0.1))
            }

            progress?(.summarizing(fractionCompleted: 0.2))

            let reprocessInputs = try loadReprocessInputs(
                noteURL: request.noteURL,
                transcriptURL: request.transcriptURL
            )
            let transcriptSource = MeetingNoteParsing.summarizationSourceText(
                fromTranscriptMarkdown: reprocessInputs.transcriptMarkdown
            )
            let meetingDate = reprocessMeetingDate(noteURL: request.noteURL) ?? dateProvider()

            let participantFrontmatter = MeetingSpeakerNamingService(vaultWriter: vaultWriter)
                .loadOwnedParticipantFrontmatter(from: reprocessInputs.existingNoteMarkdown)
            let targetMeetingType = MeetingType(rawValue: request.targetMeetingTypeId) ?? .general
            let selection = MeetingTypeSelection(selectionMode: .manual, selectedTypeId: request.targetMeetingTypeId)
            let resolvedPromptBundle: ResolvedPromptBundle
            do {
                resolvedPromptBundle = try promptBundleResolver.resolvePromptBundle(
                    library: meetingTypeLibrary,
                    selection: selection,
                    languageProcessing: .autoToEnglish,
                    outputLanguage: .defaultSelection,
                    autodetectResolvedTypeID: nil
                )
            } catch ResolvedPromptBundleResolverError.selectedTypeUnavailable(let typeID) {
                logger.error("Reprocess prompt bundle resolution failed due to unavailable meeting type: \(typeID, privacy: .public)")
                throw MinuteError.invalidMeetingTypeSelection
            } catch {
                logger.error("Reprocess prompt bundle resolution failed unexpectedly: \(ErrorHandler.debugMessage(for: error), privacy: .private(mask: .hash))")
                throw error
            }
            let sectionVisibility = summarySectionVisibility(for: resolvedPromptBundle.typeId, in: meetingTypeLibrary)

            let summarizationBinding = request.summarizationBinding
            let summarizationService = if let summarizationBinding, let summarizationServiceForBinding {
                summarizationServiceForBinding(summarizationBinding)
            } else {
                summarizationServiceProvider()
            }
            let rawSummaryJSON = try await summarizationService.summarize(
                transcript: transcriptSource,
                meetingDate: meetingDate,
                meetingType: targetMeetingType,
                languageProcessing: .autoToEnglish,
                outputLanguage: .defaultSelection,
                resolvedPromptBundle: resolvedPromptBundle
            )
            var extraction = try await decodeOrRepairExtraction(
                rawOutput: rawSummaryJSON,
                summarizationService: summarizationService
            )
            extraction.meetingType = targetMeetingType

            progress?(.writing(fractionCompleted: 0.85, extraction: extraction))

            return try vaultAccess.withVaultAccess { vaultRootURL in
                let transcriptRelativePath = VaultPathNormalizer.relativePath(from: vaultRootURL, to: request.transcriptURL)
                let audioRelativePath = MeetingNoteParsing.linkedRelativePath(
                    inNoteMarkdown: reprocessInputs.existingNoteMarkdown,
                    sectionHeading: "## Audio"
                ) ?? findAudioRelativePath(forNoteURL: request.noteURL, vaultRootURL: vaultRootURL)

                let noteDateTime = MeetingNoteParsing.frontmatterValue(forKey: "date", inNoteMarkdown: reprocessInputs.existingNoteMarkdown)
                    ?? MeetingNoteDateFormatter.format(dateProvider())
                let audioDurationSeconds = MeetingNoteParsing.parseAudioDurationSeconds(fromNoteMarkdown: reprocessInputs.existingNoteMarkdown)

                let noteMarkdown = MarkdownRenderer().render(
                    extraction: extraction,
                    noteDateTime: noteDateTime,
                    audioDurationSeconds: audioDurationSeconds,
                    audioRelativePath: audioRelativePath,
                    transcriptRelativePath: transcriptRelativePath,
                    participantFrontmatter: participantFrontmatter,
                    sectionVisibility: sectionVisibility
                )
                try vaultWriter.writeAtomically(data: Data(noteMarkdown.utf8), to: request.noteURL)

                return PipelineResult(
                    noteURL: request.noteURL,
                    audioURL: audioRelativePath.map { vaultRootURL.appendingPathComponent($0) }
                )
            }
        } catch {
            logger.error("Reprocess failed: \(ErrorHandler.debugMessage(for: error), privacy: .private(mask: .hash))")
            throw error
        }
    }

    private func executePipelineRun(
        context: PipelineContext,
        meetingRunID: String,
        progress: (@Sendable (PipelineProgress) -> Void)? = nil
    ) async throws -> PipelineResult {
        do {
            var context = context
            try Task.checkCancellation()
            let existingRunState: SummarizationRunState?
            do {
                existingRunState = try await checkpointStore.load(meetingID: meetingRunID)
            } catch {
                existingRunState = nil
            }
            await attemptRecoverMissingContractAudioIfNeeded(context: context)

            progress?(.downloadingModels(fractionCompleted: 0))
            try await modelManager.ensureModelsPresent { update in
                let clamped = min(max(update.fractionCompleted, 0), 1)
                progress?(.downloadingModels(fractionCompleted: clamped * 0.1))
            }

            try Task.checkCancellation()

            if context.normalizeAnalysisAudio {
                progress?(.normalizingAudioLevels(fractionCompleted: 0.14))
                let normalizationStartedAt = Date()
                let inputName = context.audioTempURL.lastPathComponent
                logger.info("Analysis audio normalization started [file=\(inputName, privacy: .public)]")
                print("[Minute] Analysis audio normalization started: \(inputName)")
                do {
                    let normalizedURL = try await audioLoudnessNormalizer.normalizeForAnalysis(
                        inputURL: context.audioTempURL,
                        workingDirectoryURL: context.workingDirectoryURL
                    )
                    context.analysisAudioURL = normalizedURL
                    let elapsedSeconds = Date().timeIntervalSince(normalizationStartedAt)
                    logger.info(
                        "Analysis audio normalization finished [file=\(inputName, privacy: .public), normalizedFile=\(normalizedURL.lastPathComponent, privacy: .public), elapsedSeconds=\(elapsedSeconds, privacy: .public)]"
                    )
                    print(
                        "[Minute] Analysis audio normalization finished in \(String(format: "%.1f", elapsedSeconds))s: \(normalizedURL.lastPathComponent)"
                    )
                } catch {
                    let elapsedSeconds = Date().timeIntervalSince(normalizationStartedAt)
                    logger.error(
                        "Analysis audio normalization failed [file=\(inputName, privacy: .public), elapsedSeconds=\(elapsedSeconds, privacy: .public), error=\(ErrorHandler.debugMessage(for: error), privacy: .private(mask: .hash))]"
                    )
                    print(
                        "[Minute] Analysis audio normalization failed after \(String(format: "%.1f", elapsedSeconds))s: \(ErrorHandler.userMessage(for: error, fallback: "Normalization failed."))"
                    )
                    // Normalization is a quality improvement. If ffmpeg is missing or input audio is unreadable,
                    // proceed with the original analysis audio rather than failing the whole pipeline.
                    logger.error("Analysis audio normalization failed; proceeding without normalization: \(ErrorHandler.debugMessage(for: error), privacy: .private(mask: .hash))")
                }
            }

            progress?(.transcribing(fractionCompleted: context.normalizeAnalysisAudio ? 0.18 : 0.1))

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
            } else if let vocabularyService = transcriptionService as? (any VocabularyBoostingTranscriptionServicing) {
                transcription = try await vocabularyService.transcribe(
                    wavURL: context.analysisAudioURL,
                    vocabulary: context.transcriptionVocabulary
                )
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

            if context.skipSummarization {
                let dateISO = MinuteISODate.format(context.startedAt)
                var extraction = MeetingExtraction(title: "Meeting", date: dateISO, summary: "")
                extraction.meetingType = context.meetingType

                progress?(.writing(fractionCompleted: 0.85, extraction: extraction))

                let suggestionResult = await suggestKnownSpeakersFrontmatterIfEnabled(
                    context: context,
                    diarizationSegments: diarizationSegments,
                    embeddingExportURL: embeddingExportURL
                )
                let participantFrontmatter = suggestionResult?.frontmatter

                let outputs = try writeOutputsToVault(
                    context: context,
                    extraction: extraction,
                    transcription: transcription,
                    attributedSegments: attributedSegments,
                    originalAudioData: originalAudioData,
                    participantFrontmatter: participantFrontmatter,
                    sectionVisibility: .allEnabled
                )

                if let embeddingsBySpeakerID = suggestionResult?.embeddingsBySpeakerID, !embeddingsBySpeakerID.isEmpty {
                    try await meetingSpeakerEmbeddingCache.upsert(
                        meetingKey: outputs.noteURL.path,
                        embeddingsBySpeakerID: embeddingsBySpeakerID,
                        embeddingModelVersion: SpeakerEmbeddingModelVersions.fluidAudioOfflineVbx256
                    )
                }

                cleanupTemporaryArtifacts(for: context)
                await checkpointStore.clear(meetingID: meetingRunID)
                return outputs
            }

            let summarizationBinding = context.summarizationBinding
            let preflightConfiguration = if let summarizationBinding, let summarizationPreflightConfigurationForBinding {
                summarizationPreflightConfigurationForBinding(summarizationBinding)
            } else {
                summarizationPreflightConfigurationProvider()
            }
            let preflight = SummarizationPassPlanner.estimate(
                transcript: timelineText,
                contextWindowTokens: preflightConfiguration.contextWindowTokens,
                reservedOutputTokens: preflightConfiguration.reservedOutputTokens,
                safetyMarginTokens: preflightConfiguration.safetyMarginTokens,
                promptOverheadTokens: preflightConfiguration.promptOverheadTokens
            )
            let chunks = SummarizationPassPlanner.chunkTranscript(
                timelineText,
                availableInputTokensPerPass: preflight.availableInputTokensPerPass
            )
            let runID = existingRunState?.runID ?? UUID().uuidString
            let summarizationModelID = summarizationBinding?.providerReference ?? summarizationModelIDProvider()
            var budgetEstimate = SummarizationTokenBudgetEstimate(
                runID: runID,
                modelID: summarizationModelID,
                contextWindowTokens: preflight.contextWindowTokens,
                reservedOutputTokens: preflight.reservedOutputTokens,
                safetyMarginTokens: preflight.safetyMarginTokens,
                promptOverheadTokens: preflight.promptOverheadTokens,
                availableInputTokensPerPass: preflight.availableInputTokensPerPass,
                estimatedTotalInputTokens: preflight.estimatedTotalInputTokens,
                estimatedPassCount: preflight.estimatedPassCount
            )
            var chunkTexts = chunks
            var passPlan = makePassPlan(runID: runID, chunks: chunks)
            var passRecords = passPlan.chunks.map {
                SummarizationPassRecord(passIndex: $0.passIndex, chunkID: $0.chunkID, status: .pending)
            }
            let completedPassCountFromCheckpoint = existingRunState?.lastValidCheckpoint?.completedPassIndex ?? 0
            if completedPassCountFromCheckpoint > 0 {
                passRecords = passRecords.map { record in
                    guard record.passIndex <= completedPassCountFromCheckpoint else { return record }
                    var updated = record
                    updated.status = .completed
                    return updated
                }
            }
            let planningState = SummarizationRunState(
                runID: runID,
                meetingID: meetingRunID,
                status: .planning,
                currentPassIndex: 0,
                totalPassCount: max(1, passPlan.chunks.count),
                tokenBudgetEstimate: budgetEstimate,
                passPlan: passPlan,
                outputPaths: existingRunState?.outputPaths,
                lastValidCheckpoint: existingRunState?.lastValidCheckpoint,
                passRecords: passRecords
            )
            await saveCheckpointState(planningState, for: meetingRunID, operation: "planning")

            try Task.checkCancellation()
            let summarizationService = if let summarizationBinding, let summarizationServiceForBinding {
                summarizationServiceForBinding(summarizationBinding)
            } else {
                summarizationServiceProvider()
            }
            let meetingDate = context.startedAt

            let meetingTypeLibrary = meetingTypeLibraryStore.load()
            var effectiveType = context.meetingType
            var autodetectResolvedTypeID: String? = nil
            if context.meetingTypeSelection.selectionMode == .autodetect {
                let fallbackTypeID = MeetingType.general.rawValue
                let classifierCandidates = makeClassifierCandidates(library: meetingTypeLibrary)
                let resolvedTypeID = try await summarizationService.classify(
                    transcript: timelineText,
                    candidates: classifierCandidates,
                    fallbackTypeID: fallbackTypeID
                )

                autodetectResolvedTypeID = resolvedTypeID
                effectiveType = MeetingType(rawValue: resolvedTypeID) ?? .general
                logger.info("Autodetected meeting type ID: \(resolvedTypeID, privacy: .public)")
            } else {
                let selectedTypeID = context.meetingTypeSelection.selectedTypeId
                effectiveType = MeetingType(rawValue: selectedTypeID) ?? context.meetingType
            }

            let resolvedPromptBundle: ResolvedPromptBundle
            do {
                resolvedPromptBundle = try promptBundleResolver.resolvePromptBundle(
                    library: meetingTypeLibrary,
                    selection: context.meetingTypeSelection,
                    languageProcessing: context.languageProcessing,
                    outputLanguage: context.outputLanguage,
                    autodetectResolvedTypeID: autodetectResolvedTypeID
                )
            } catch ResolvedPromptBundleResolverError.selectedTypeUnavailable(let typeID) {
                logger.error("Prompt bundle resolution failed due to unavailable meeting type: \(typeID, privacy: .public)")
                throw MinuteError.invalidMeetingTypeSelection
            } catch {
                logger.error("Prompt bundle resolution failed unexpectedly: \(ErrorHandler.debugMessage(for: error), privacy: .private(mask: .hash))")
                throw error
            }
            let sectionVisibility = summarySectionVisibility(
                for: resolvedPromptBundle.typeId,
                in: meetingTypeLibrary
            )

            if let runtimeAwareSummarizationService = summarizationService as? any RuntimeAwareSummarizationServicing {
                let runtimePlan = try await runtimeAwareSummarizationService.makeRuntimePassPlan(
                    transcript: timelineText,
                    meetingDate: meetingDate,
                    meetingType: effectiveType,
                    languageProcessing: context.languageProcessing,
                    outputLanguage: context.outputLanguage,
                    resolvedPromptBundle: resolvedPromptBundle
                )
                chunkTexts = runtimePlan.chunks.map(\.transcript)
                passPlan = makePassPlan(runID: runID, chunks: runtimePlan.chunks)
                budgetEstimate = SummarizationTokenBudgetEstimate(
                    runID: runID,
                    modelID: summarizationModelID,
                    contextWindowTokens: runtimePlan.contextWindowTokens,
                    reservedOutputTokens: runtimePlan.reservedOutputTokens,
                    safetyMarginTokens: runtimePlan.safetyMarginTokens,
                    promptOverheadTokens: runtimePlan.promptOverheadTokens,
                    availableInputTokensPerPass: runtimePlan.availableInputTokensPerPass,
                    estimatedTotalInputTokens: runtimePlan.estimatedTotalInputTokens,
                    estimatedPassCount: max(1, runtimePlan.chunks.count)
                )
                passRecords = passPlan.chunks.map {
                    SummarizationPassRecord(passIndex: $0.passIndex, chunkID: $0.chunkID, status: .pending)
                }
                if completedPassCountFromCheckpoint > 0 {
                    passRecords = passRecords.map { record in
                        guard record.passIndex <= completedPassCountFromCheckpoint else { return record }
                        var updated = record
                        updated.status = .completed
                        return updated
                    }
                }
                let refinedPlanningState = SummarizationRunState(
                    runID: runID,
                    meetingID: meetingRunID,
                    status: .planning,
                    currentPassIndex: 0,
                    totalPassCount: max(1, passPlan.chunks.count),
                    tokenBudgetEstimate: budgetEstimate,
                    passPlan: passPlan,
                    outputPaths: existingRunState?.outputPaths,
                    lastValidCheckpoint: existingRunState?.lastValidCheckpoint,
                    passRecords: passRecords
                )
                await saveCheckpointState(refinedPlanningState, for: meetingRunID, operation: "runtime planning")
            }

            let totalPasses = max(1, passPlan.chunks.count)
            let firstPendingPassIndex = completedPassCountFromCheckpoint + 1
            let resumedFromPassIndex = firstPendingPassIndex > 1 ? firstPendingPassIndex : nil

            progress?(
                .summarizing(
                    fractionCompleted: 0.5,
                    preflightBudgetTokens: budgetEstimate.availableInputTokensPerPass,
                    estimatedPassCount: budgetEstimate.estimatedPassCount,
                    currentPassIndex: 0,
                    totalPassCount: totalPasses,
                    resumedFromPassIndex: resumedFromPassIndex
                )
            )

            let processedDateTime = MeetingNoteDateFormatter.format(dateProvider())
            var resolvedOutputPaths = resolvedOutputPaths(from: existingRunState?.outputPaths)
            var mergeState = existingRunState.flatMap { decodeMergeState(from: $0.lastValidCheckpoint, recordingDate: meetingDate) }
            var extraction = mergeState.map { SummarizationSummaryMerger.extraction(from: $0, recordingDate: meetingDate) }
            var currentSummaryJSON = extraction.flatMap { try? encodeExtractionCanonical($0) }
            var currentMergeStateJSON = mergeState.flatMap { try? encodeMergeStateCanonical($0) }
            var lastValidCheckpoint = existingRunState?.lastValidCheckpoint

            if firstPendingPassIndex <= totalPasses {
                for passIndex in firstPendingPassIndex...totalPasses {
                    try Task.checkCancellation()

                    guard passPlan.chunks.contains(where: { $0.passIndex == passIndex }) else {
                        throw MinuteError.llamaFailed(
                            exitCode: -1,
                            output: "Missing pass plan for pass \(passIndex)"
                        )
                    }

                    passRecords = passRecords.map { record in
                        guard record.passIndex == passIndex else { return record }
                        var updated = record
                        updated.status = .running
                        updated.startedAt = dateProvider()
                        return updated
                    }
                    let runningState = SummarizationRunState(
                        runID: runID,
                        meetingID: meetingRunID,
                        status: .running,
                        currentPassIndex: passIndex,
                        totalPassCount: totalPasses,
                        tokenBudgetEstimate: budgetEstimate,
                        passPlan: passPlan,
                        outputPaths: resolvedOutputPaths.map(makeOutputPaths),
                        lastValidCheckpoint: lastValidCheckpoint,
                        passRecords: passRecords
                    )
                    await saveCheckpointState(runningState, for: meetingRunID, operation: "running pass \(passIndex)")

                    let chunkIndex = max(0, min(chunkTexts.count - 1, passIndex - 1))
                    let chunk = chunkTexts[chunkIndex]
                    let rawJSON: String
                    if let runtimeAwareSummarizationService = summarizationService as? any RuntimeAwareSummarizationServicing {
                        rawJSON = try await runtimeAwareSummarizationService.summarizePass(
                            transcriptChunk: chunk,
                            previousSummaryJSON: currentMergeStateJSON,
                            passIndex: passIndex,
                            totalPasses: totalPasses,
                            meetingDate: meetingDate,
                            meetingType: effectiveType,
                            languageProcessing: context.languageProcessing,
                            outputLanguage: context.outputLanguage,
                            resolvedPromptBundle: resolvedPromptBundle
                        )
                    } else {
                        let passTranscript = makePassTranscript(
                            previousSummaryJSON: currentMergeStateJSON,
                            chunk: chunk,
                            passIndex: passIndex,
                            totalPasses: totalPasses
                        )
                        rawJSON = try await summarizationService.summarize(
                            transcript: passTranscript,
                            meetingDate: meetingDate,
                            meetingType: effectiveType,
                            languageProcessing: context.languageProcessing,
                            outputLanguage: context.outputLanguage,
                            resolvedPromptBundle: resolvedPromptBundle
                        )
                    }

                    let passDelta = try await decodeOrRepairPassDelta(
                        rawJSON: rawJSON,
                        meetingDate: meetingDate,
                        summarizationService: summarizationService
                    )
                    mergeState = SummarizationSummaryMerger.merge(
                        previousState: mergeState,
                        delta: passDelta,
                        meetingType: effectiveType,
                        recordingDate: meetingDate
                    )
                    guard let mergeState else {
                        throw MinuteError.llamaFailed(
                            exitCode: -1,
                            output: "Unable to merge pass delta"
                        )
                    }
                    extraction = SummarizationSummaryMerger.extraction(from: mergeState, recordingDate: meetingDate)
                    guard let extraction else {
                        throw MinuteError.llamaFailed(
                            exitCode: -1,
                            output: "Unable to materialize merged summary state"
                        )
                    }

                    currentSummaryJSON = try encodeExtractionCanonical(extraction)
                    currentMergeStateJSON = try encodeMergeStateCanonical(mergeState)
                    let checkpoint = SummarizationSummaryCheckpoint(
                        completedPassIndex: passIndex,
                        summaryJSON: currentSummaryJSON ?? rawJSON,
                        mergeStateJSON: currentMergeStateJSON,
                        sourceChunkIDs: passPlan.chunks.prefix(passIndex).map(\.chunkID)
                    )

                    passRecords = passRecords.map { record in
                        guard record.passIndex == passIndex else { return record }
                        var updated = record
                        updated.status = .completed
                        updated.finishedAt = dateProvider()
                        updated.errorCode = nil
                        updated.errorMessage = nil
                        return updated
                    }

                    resolvedOutputPaths = try reconcileOutputPaths(
                        context: context,
                        currentPaths: resolvedOutputPaths,
                        extraction: extraction
                    )
                    if let resolvedOutputPaths {
                        try writeSummaryNoteToVault(
                            context: context,
                            extraction: extraction,
                            noteDateTime: processedDateTime,
                            sectionVisibility: sectionVisibility,
                            resolvedPaths: resolvedOutputPaths
                        )
                    }

                    let passState = SummarizationRunState(
                        runID: runID,
                        meetingID: meetingRunID,
                        status: .running,
                        currentPassIndex: passIndex,
                        totalPassCount: totalPasses,
                        tokenBudgetEstimate: budgetEstimate,
                        passPlan: passPlan,
                        outputPaths: resolvedOutputPaths.map(makeOutputPaths),
                        lastValidCheckpoint: checkpoint,
                        passRecords: passRecords
                    )
                    await saveCheckpointState(passState, for: meetingRunID, operation: "completed pass \(passIndex)")
                    lastValidCheckpoint = checkpoint

                    let fraction = 0.5 + (0.34 * (Double(passIndex) / Double(totalPasses)))
                    progress?(
                        .summarizing(
                            fractionCompleted: min(0.84, fraction),
                            preflightBudgetTokens: budgetEstimate.availableInputTokensPerPass,
                            estimatedPassCount: budgetEstimate.estimatedPassCount,
                            currentPassIndex: passIndex,
                            totalPassCount: totalPasses,
                            resumedFromPassIndex: resumedFromPassIndex
                        )
                    )
                }
            }

            guard var extraction else {
                throw MinuteError.llamaFailed(
                    exitCode: -1,
                    output: "Missing final extraction after summarization passes"
                )
            }
            extraction.meetingType = effectiveType
            let completedCheckpoint = SummarizationSummaryCheckpoint(
                completedPassIndex: totalPasses,
                summaryJSON: currentSummaryJSON ?? "",
                mergeStateJSON: currentMergeStateJSON,
                sourceChunkIDs: passPlan.chunks.map(\.chunkID)
            )
            let completedState = SummarizationRunState(
                runID: runID,
                meetingID: meetingRunID,
                status: .completed,
                currentPassIndex: totalPasses,
                totalPassCount: totalPasses,
                tokenBudgetEstimate: budgetEstimate,
                passPlan: passPlan,
                outputPaths: resolvedOutputPaths.map(makeOutputPaths),
                lastValidCheckpoint: completedCheckpoint,
                passRecords: passRecords
            )
            await saveCheckpointState(completedState, for: meetingRunID, operation: "completion")

            try Task.checkCancellation()
            progress?(.writing(fractionCompleted: 0.85, extraction: extraction))

            let suggestionResult = await suggestKnownSpeakersFrontmatterIfEnabled(
                context: context,
                diarizationSegments: diarizationSegments,
                embeddingExportURL: embeddingExportURL
            )

            let participantFrontmatter = suggestionResult?.frontmatter

            let outputs = try writeOutputsToVault(
                context: context,
                extraction: extraction,
                transcription: transcription,
                attributedSegments: attributedSegments,
                originalAudioData: originalAudioData,
                participantFrontmatter: participantFrontmatter,
                sectionVisibility: sectionVisibility,
                resolvedPathsOverride: resolvedOutputPaths
            )

            if let embeddingsBySpeakerID = suggestionResult?.embeddingsBySpeakerID, !embeddingsBySpeakerID.isEmpty {
                // Persist in app-owned storage (never the vault) for later explicit enrollment.
                try await meetingSpeakerEmbeddingCache.upsert(
                    meetingKey: outputs.noteURL.path,
                    embeddingsBySpeakerID: embeddingsBySpeakerID,
                    embeddingModelVersion: SpeakerEmbeddingModelVersions.fluidAudioOfflineVbx256
                )
            }

            cleanupTemporaryArtifacts(for: context)
            await checkpointStore.clear(meetingID: meetingRunID)
            return outputs
        } catch is CancellationError {
            logger.info("Pipeline cancelled")
            if let existing = try? await checkpointStore.load(meetingID: meetingRunID) {
                var cancelledState = existing
                cancelledState.status = .cancelled
                cancelledState.passRecords = cancelledState.passRecords.map { record in
                    guard record.status == .running else { return record }
                    var updated = record
                    updated.status = .cancelled
                    updated.finishedAt = dateProvider()
                    updated.errorCode = nil
                    updated.errorMessage = nil
                    return updated
                }
                await saveCheckpointState(cancelledState, for: meetingRunID, operation: "cancellation")
            }
            throw CancellationError()
        } catch {
            logger.error("Pipeline failed: \(ErrorHandler.debugMessage(for: error), privacy: .private(mask: .hash))")
            if let existing = try? await checkpointStore.load(meetingID: meetingRunID) {
                var failedState = existing
                failedState.status = existing.lastValidCheckpoint == nil ? .failed : .pausedForRetry
                failedState.passRecords = failedState.passRecords.map { record in
                    if record.passIndex == existing.currentPassIndex,
                       record.status == .running || record.status == .pending {
                        var updated = record
                        updated.status = .failed
                        updated.finishedAt = dateProvider()
                        updated.errorCode = "pipeline_failure"
                        updated.errorMessage = ErrorHandler.userMessage(for: error, fallback: "Processing failed.")
                        return updated
                    }
                    return record
                }
                await saveCheckpointState(failedState, for: meetingRunID, operation: "failure")
            }
            // Keep capture audio on failures so retry can reuse the same context safely.
            cleanupTemporaryArtifacts(for: context, policy: .workingDirectoryOnly)
            throw error
        }
    }

    private func makeClassifierCandidates(library: MeetingTypeLibrary) -> [MeetingTypeClassifierCandidate] {
        var candidates: [MeetingTypeClassifierCandidate] = []
        candidates.reserveCapacity(library.activeDefinitions.count)

        for definition in library.activeDefinitions {
            if definition.typeId == MeetingType.autodetect.rawValue {
                continue
            }

            if definition.source == .custom && !definition.autodetectEligible {
                continue
            }

            let fallbackSignals = [definition.displayName]
            let profileSignals = definition.classifierProfile?.strongSignals ?? []
            let strongSignals = (profileSignals.isEmpty ? fallbackSignals : profileSignals)
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
            let label = (definition.classifierProfile?.label ?? definition.displayName)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            guard !label.isEmpty else { continue }

            candidates.append(
                MeetingTypeClassifierCandidate(
                    typeId: definition.typeId,
                    label: label,
                    strongSignals: strongSignals
                )
            )
        }

        if !candidates.contains(where: { $0.typeId == MeetingType.general.rawValue }) {
            candidates.append(
                MeetingTypeClassifierCandidate(
                    typeId: MeetingType.general.rawValue,
                    label: MeetingType.general.displayName,
                    strongSignals: ["general business discussion"]
                )
            )
        }

        return candidates
    }

    private func decodeOrRepairPassDelta(
        rawJSON: String,
        meetingDate: Date,
        summarizationService: any SummarizationServicing
    ) async throws -> SummarizationPassDelta {
        _ = meetingDate
        do {
            return try decodePassDeltaStrict(from: rawJSON)
        } catch {
            logger.info("Pass delta JSON invalid; attempting repair")

            let repaired = try await summarizationService.repairJSON(rawJSON)

            do {
                return try decodePassDeltaStrict(from: repaired)
            } catch {
                logger.error("Pass delta JSON still invalid after repair")
                throw MinuteError.jsonInvalid
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

    private func decodePassDeltaStrict(from rawOutput: String) throws -> SummarizationPassDelta {
        let trimmed = rawOutput.trimmingCharacters(in: .whitespacesAndNewlines)

        guard let extracted = JSONFirstObjectExtractor.extractFirstJSONObject(from: trimmed) else {
            throw MinuteError.jsonInvalid
        }

        do {
            return try JSONDecoder().decode(SummarizationPassDelta.self, from: Data(extracted.jsonObject.utf8))
        } catch {
            throw MinuteError.jsonInvalid
        }
    }

    private func decodeOrRepairExtraction(
        rawOutput: String,
        summarizationService: any SummarizationServicing
    ) async throws -> MeetingExtraction {
        do {
            return try decodeExtractionStrict(from: rawOutput)
        } catch {
            logger.info("Extraction JSON invalid during reprocessing; attempting repair")
            let repaired = try await summarizationService.repairJSON(rawOutput)
            do {
                return try decodeExtractionStrict(from: repaired)
            } catch {
                logger.error("Extraction JSON still invalid after repair during reprocessing")
                throw MinuteError.jsonInvalid
            }
        }
    }

    private func writeOutputsToVault(
        context: PipelineContext,
        extraction: MeetingExtraction,
        transcription: TranscriptionResult,
        attributedSegments: [AttributedTranscriptSegment],
        originalAudioData: Data?,
        participantFrontmatter: MeetingParticipantFrontmatter?,
        sectionVisibility: MeetingSummarySectionVisibility,
        resolvedPathsOverride: ResolvedOutputPaths? = nil
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
            let speakerDisplayNames = participantFrontmatter?.speakerMap ?? [:]
            let screenContextEntries = context.screenContextEvents.compactMap { $0.transcriptTimelineEntry() }
            let transcriptMarkdown = TranscriptMarkdownRenderer().render(
                title: extraction.title,
                dateISO: meetingDateISO,
                transcript: transcription.text,
                attributedSegments: attributedSegments,
                screenContextEntries: screenContextEntries,
                speakerDisplayNames: speakerDisplayNames
            )
            transcriptData = Data(transcriptMarkdown.utf8)
        } else {
            transcriptData = nil
        }

        return try vaultAccess.withVaultAccess { vaultRootURL in
            let resolvedPaths = resolvedPathsOverride ?? resolveOutputPaths(
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
                participantFrontmatter: participantFrontmatter,
                sectionVisibility: sectionVisibility
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

            // Audio
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
        transcriptRelativePath: String?,
        ignoringExistingPaths: Set<String> = []
    ) -> ResolvedOutputPaths {
        let fileManager = FileManager.default

        func normalizeRelativePath(_ relativePath: String) -> String {
            VaultPathNormalizer
                .normalizedRelativeComponents(relativePath)
                .joined(separator: "/")
        }

        let noteRelativePath = normalizeRelativePath(noteRelativePath)
        let audioRelativePath = audioRelativePath.map(normalizeRelativePath)
        let transcriptRelativePath = transcriptRelativePath.map(normalizeRelativePath)
        let ignoredPaths = Set(ignoringExistingPaths.map(normalizeRelativePath))

        func withSuffix(_ relativePath: String, suffix: String) -> String {
            let ns = relativePath as NSString
            let ext = ns.pathExtension
            let base = ns.deletingPathExtension
            return ext.isEmpty ? base + suffix : base + suffix + "." + ext
        }

        func exists(_ relativePath: String?) -> Bool {
            guard let relativePath else { return false }
            if ignoredPaths.contains(relativePath) {
                return false
            }
            return fileManager.fileExists(atPath: vaultRootURL.appendingPathComponent(relativePath).path)
        }

        // Fast path: no collision.
        if !exists(noteRelativePath),
           !exists(audioRelativePath),
           !exists(transcriptRelativePath) {
            return ResolvedOutputPaths(
                noteRelativePath: noteRelativePath,
                audioRelativePath: audioRelativePath,
                transcriptRelativePath: transcriptRelativePath
            )
        }

        // Collision: choose a stable, user-readable suffix.
        for index in 2...99 {
            let suffix = " (\(index))"
            let candidateNote = withSuffix(noteRelativePath, suffix: suffix)
            let candidateAudio = audioRelativePath.map { withSuffix($0, suffix: suffix) }
            let candidateTranscript = transcriptRelativePath.map { withSuffix($0, suffix: suffix) }

            if !exists(candidateNote), !exists(candidateAudio), !exists(candidateTranscript) {
                return ResolvedOutputPaths(
                    noteRelativePath: candidateNote,
                    audioRelativePath: candidateAudio,
                    transcriptRelativePath: candidateTranscript
                )
            }
        }

        // As a last resort, fall back to the original path (writer will overwrite or throw depending on implementation).
        return ResolvedOutputPaths(
            noteRelativePath: noteRelativePath,
            audioRelativePath: audioRelativePath,
            transcriptRelativePath: transcriptRelativePath
        )
    }

    private func reconcileOutputPaths(
        context: PipelineContext,
        currentPaths: ResolvedOutputPaths?,
        extraction: MeetingExtraction
    ) throws -> ResolvedOutputPaths {
        try vaultAccess.withVaultAccess { vaultRootURL in
            let contract = MeetingFileContract(folders: context.vaultFolders)
            let noteRelativePath = contract.noteRelativePath(date: context.startedAt, title: extraction.title)
            let audioRelativePath = context.saveAudio ? contract.audioRelativePath(date: context.startedAt, title: extraction.title) : nil
            let transcriptRelativePath = context.saveTranscript ? contract.transcriptRelativePath(date: context.startedAt, title: extraction.title) : nil
            let resolvedPaths = resolveOutputPaths(
                vaultRootURL: vaultRootURL,
                noteRelativePath: noteRelativePath,
                audioRelativePath: audioRelativePath,
                transcriptRelativePath: transcriptRelativePath,
                ignoringExistingPaths: Set(
                    [currentPaths?.noteRelativePath, currentPaths?.audioRelativePath, currentPaths?.transcriptRelativePath]
                        .compactMap { $0 }
                )
            )

            guard let currentPaths,
                  currentPaths.noteRelativePath != resolvedPaths.noteRelativePath else {
                return resolvedPaths
            }

            let currentNoteURL = vaultRootURL.appendingPathComponent(currentPaths.noteRelativePath)
            let resolvedNoteURL = vaultRootURL.appendingPathComponent(resolvedPaths.noteRelativePath)

            if FileManager.default.fileExists(atPath: currentNoteURL.path) {
                try vaultWriter.ensureDirectoryExists(resolvedNoteURL.deletingLastPathComponent())
                try FileManager.default.moveItem(at: currentNoteURL, to: resolvedNoteURL)
            }

            return resolvedPaths
        }
    }

    private func resolvedOutputPaths(from paths: SummarizationOutputPaths?) -> ResolvedOutputPaths? {
        guard let paths else { return nil }
        return ResolvedOutputPaths(
            noteRelativePath: paths.noteRelativePath,
            audioRelativePath: paths.audioRelativePath,
            transcriptRelativePath: paths.transcriptRelativePath
        )
    }

    private func makeOutputPaths(_ paths: ResolvedOutputPaths) -> SummarizationOutputPaths {
        SummarizationOutputPaths(
            noteRelativePath: paths.noteRelativePath,
            audioRelativePath: paths.audioRelativePath,
            transcriptRelativePath: paths.transcriptRelativePath
        )
    }

    private func writeSummaryNoteToVault(
        context: PipelineContext,
        extraction: MeetingExtraction,
        noteDateTime: String,
        sectionVisibility: MeetingSummarySectionVisibility,
        resolvedPaths: ResolvedOutputPaths
    ) throws {
        let markdown = MarkdownRenderer().render(
            extraction: extraction,
            noteDateTime: noteDateTime,
            audioDurationSeconds: context.audioDurationSeconds,
            audioRelativePath: resolvedPaths.audioRelativePath,
            transcriptRelativePath: resolvedPaths.transcriptRelativePath,
            participantFrontmatter: nil,
            sectionVisibility: sectionVisibility
        )
        let noteData = Data(markdown.utf8)
        try vaultAccess.withVaultAccess { vaultRootURL in
            let noteURL = vaultRootURL.appendingPathComponent(resolvedPaths.noteRelativePath)
            try vaultWriter.writeAtomically(data: noteData, to: noteURL)
        }
    }

    private func makePassTranscript(
        previousSummaryJSON: String?,
        chunk: String,
        passIndex: Int,
        totalPasses: Int
    ) -> String {
        let existingStateBlock: String
        if let previousSummaryJSON, !previousSummaryJSON.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            existingStateBlock = """
            Existing accepted state:
            \(previousSummaryJSON)

            """
        } else {
            existingStateBlock = ""
        }

        return """
        Process summarization pass \(passIndex) of \(totalPasses).
        Use the existing accepted state only to avoid duplicates.
        Return only net-new material from this chunk.

        Return one valid JSON object with exactly these fields:
        - title (string; empty string if unchanged)
        - date (YYYY-MM-DD; empty string if unchanged)
        - summary_points (array of short, high-signal new facts from this chunk only)
        - decisions (array of new decisions only)
        - action_items (array of objects with owner and task; new or materially refined items only)
        - open_questions (array of new open questions only)
        - key_points (array of new key points only)

        Rules:
        - Do not restate information already captured in the existing accepted state.
        - Do not rewrite the full meeting summary.
        - Use empty arrays when there is nothing new for a field.
        - Do not output markdown fences or prose outside JSON.

        \(existingStateBlock)Transcript chunk:
        \(chunk)
        """
    }

    private func decodeExtractionIfPossible(_ rawJSON: String, recordingDate: Date) -> MeetingExtraction? {
        do {
            let decoded = try decodeExtractionStrict(from: rawJSON)
            return MeetingExtractionValidation.validated(decoded, recordingDate: recordingDate)
        } catch {
            return nil
        }
    }

    private func encodeExtractionCanonical(_ extraction: MeetingExtraction) throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(extraction)
        guard let json = String(data: data, encoding: .utf8) else {
            throw MinuteError.jsonInvalid
        }
        return json
    }

    private func encodeMergeStateCanonical(_ state: SummarizationMergeState) throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(state)
        guard let json = String(data: data, encoding: .utf8) else {
            throw MinuteError.jsonInvalid
        }
        return json
    }

    private func decodeMergeState(
        from checkpoint: SummarizationSummaryCheckpoint?,
        recordingDate: Date
    ) -> SummarizationMergeState? {
        guard let checkpoint else { return nil }

        if let mergeStateJSON = checkpoint.mergeStateJSON,
           let data = mergeStateJSON.data(using: .utf8),
           let decoded = try? JSONDecoder().decode(SummarizationMergeState.self, from: data) {
            return decoded
        }

        guard let extraction = decodeExtractionIfPossible(checkpoint.summaryJSON, recordingDate: recordingDate) else {
            return nil
        }
        return SummarizationMergeState(extraction: extraction)
    }

    private func summarySectionVisibility(
        for typeID: String,
        in library: MeetingTypeLibrary
    ) -> MeetingSummarySectionVisibility {
        library.definition(for: typeID)?.promptComponents.summarySectionVisibility ?? .allEnabled
    }

    private func makeMeetingRunID(context: PipelineContext) -> String {
        let seed = context.audioTempURL.standardizedFileURL.path + "|" + "\(Int(context.startedAt.timeIntervalSince1970))"
        var hash: UInt64 = 5381
        for byte in seed.utf8 {
            hash = ((hash << 5) &+ hash) &+ UInt64(byte)
        }
        return "meeting-\(String(hash, radix: 16))"
    }

    private func makePassPlan(runID: String, chunks: [String]) -> SummarizationPassPlan {
        let runtimeChunks = chunks.map {
            SummarizationRuntimeChunk(
                transcript: $0,
                tokenCount: max(1, SummarizationPassPlanner.estimateTokens(in: $0))
            )
        }
        return makePassPlan(runID: runID, chunks: runtimeChunks)
    }

    private func makePassPlan(runID: String, chunks: [SummarizationRuntimeChunk]) -> SummarizationPassPlan {
        var tokenOffset = 0
        let plans = chunks.enumerated().map { index, chunk -> SummarizationTranscriptChunkPlan in
            let tokens = max(1, chunk.tokenCount)
            defer { tokenOffset += tokens }
            return SummarizationTranscriptChunkPlan(
                chunkID: "chunk-\(index + 1)-\(tokenOffset)-\(tokenOffset + tokens)",
                passIndex: index + 1,
                tokenStart: tokenOffset,
                tokenEnd: tokenOffset + tokens,
                tokenCount: tokens
            )
        }
        return SummarizationPassPlan(runID: runID, chunks: plans)
    }

    private func saveCheckpointState(
        _ state: SummarizationRunState,
        for meetingID: String,
        operation: String
    ) async {
        do {
            try await checkpointStore.save(state, for: meetingID)
        } catch {
            logger.error(
                "Failed to save summarization checkpoint during \(operation, privacy: .public) [meetingID=\(meetingID, privacy: .public)]: \(ErrorHandler.debugMessage(for: error), privacy: .private(mask: .hash))"
            )
        }
    }

    private func loadUTF8Contents(at url: URL) throws -> String {
        let data = try Data(contentsOf: url)
        if let content = String(data: data, encoding: .utf8) {
            return content
        }
        return String(decoding: data, as: UTF8.self)
    }

    private func loadReprocessInputs(noteURL: URL, transcriptURL: URL) throws -> ReprocessInputs {
        try vaultAccess.withVaultAccess { _ in
            ReprocessInputs(
                existingNoteMarkdown: try loadUTF8Contents(at: noteURL),
                transcriptMarkdown: try loadUTF8Contents(at: transcriptURL)
            )
        }
    }

    private func reprocessMeetingDate(noteURL: URL) -> Date? {
        let basename = noteURL.deletingPathExtension().lastPathComponent
        guard let separatorRange = basename.range(of: " - ") else {
            return nil
        }

        return parseMeetingTimestampPrefix(String(basename[..<separatorRange.lowerBound]))
    }

    private func parseMeetingTimestampPrefix(_ value: String, calendar: Calendar = .current) -> Date? {
        let parts = value.split(separator: " ")
        guard let datePart = parts.first else { return nil }

        let dateSegments = datePart.split(separator: "-")
        guard dateSegments.count == 3,
              let year = Int(dateSegments[0]),
              let month = Int(dateSegments[1]),
              let day = Int(dateSegments[2]) else {
            return nil
        }

        var hour = 0
        var minute = 0
        if parts.count > 1 {
            let rawTime = parts[1]
            let timeSegments = rawTime.split(separator: ":")
            let fallbackSegments = rawTime.split(separator: ".")
            let segments = timeSegments.count == 2 ? timeSegments : fallbackSegments
            if segments.count == 2,
               let parsedHour = Int(segments[0]),
               let parsedMinute = Int(segments[1]) {
                hour = parsedHour
                minute = parsedMinute
            }
        }

        var cal = calendar
        cal.timeZone = TimeZone(secondsFromGMT: 0) ?? calendar.timeZone

        var components = DateComponents()
        components.calendar = cal
        components.timeZone = cal.timeZone
        components.year = year
        components.month = month
        components.day = day
        components.hour = hour
        components.minute = minute

        return cal.date(from: components)
    }

    private func findAudioRelativePath(forNoteURL noteURL: URL, vaultRootURL: URL) -> String? {
        let basename = noteURL.deletingPathExtension().lastPathComponent
        let resourceKeys: Set<URLResourceKey> = [.isRegularFileKey]

        guard let enumerator = FileManager.default.enumerator(
            at: vaultRootURL,
            includingPropertiesForKeys: Array(resourceKeys),
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) else {
            return nil
        }

        for case let candidateURL as URL in enumerator {
            guard candidateURL.pathExtension.lowercased() == "wav" else { continue }
            guard candidateURL.deletingPathExtension().lastPathComponent == basename else { continue }
            return VaultPathNormalizer.relativePath(from: vaultRootURL, to: candidateURL)
        }

        return nil
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
    ) async -> KnownSpeakerSuggestionResult? {
        guard context.knownSpeakerSuggestionsEnabled else { return nil }
        guard let embeddingExportURL else { return nil }

        do {
            let entries = try OfflineDiarizerEmbeddingExport.load(from: embeddingExportURL)
            let aggregated = try OfflineDiarizerEmbeddingExport.aggregateByCluster(entries: entries)
            if aggregated.isEmpty { return nil }

            let meetingSpeakerOrder = SpeakerOrdering.orderedSpeakerIDs(from: diarizationSegments)
            let overlapByClusterSpeakerID = Self.overlapSecondsByClusterSpeakerID(
                entries: entries,
                diarizationSegments: diarizationSegments
            )

            // Best-effort mapping: infer which diarization `speakerId` each embedding `cluster` corresponds to.
            // This avoids incorrect assignments when clusters and speaker IDs do not sort-align.
            let clusterToSpeakerId = Self.bestSpeakerIDByCluster(overlapByClusterSpeakerID)
            let bestClusterBySpeakerID = Self.bestClusterBySpeakerID(
                overlapByClusterSpeakerID,
                clusterToSpeakerId: clusterToSpeakerId
            )

            var embeddingsBySpeakerID: [Int: [Float]] = [:]
            embeddingsBySpeakerID.reserveCapacity(aggregated.count)
            for item in aggregated {
                guard let speakerId = clusterToSpeakerId[item.speakerCluster] else {
                    // If we can’t map a cluster into the diarization speaker-id space, skip it.
                    // This avoids introducing 0-based cluster IDs into speaker-facing IDs.
                    continue
                }
                if let preferredCluster = bestClusterBySpeakerID[speakerId], preferredCluster != item.speakerCluster {
                    continue
                }
                embeddingsBySpeakerID[speakerId] = item.embedding
            }

            let profiles = try await speakerProfileStore.listProfiles()
            if profiles.isEmpty {
                return KnownSpeakerSuggestionResult(
                    frontmatter: nil,
                    embeddingsBySpeakerID: embeddingsBySpeakerID
                )
            }

            let matcher = SpeakerEmbeddingMatcher()

            var speakerMap: [Int: String] = [:]
            for item in aggregated {
                guard let speakerId = clusterToSpeakerId[item.speakerCluster] else {
                    continue
                }
                if let preferredCluster = bestClusterBySpeakerID[speakerId], preferredCluster != item.speakerCluster {
                    continue
                }
                if let match = try matcher.bestMatch(
                    embedding: item.embedding,
                    candidates: profiles,
                    embeddingModelVersion: SpeakerEmbeddingModelVersions.fluidAudioOfflineVbx256
                ) {
                    speakerMap[speakerId] = match.profile.name
                }
            }

            let participants = Self.participantsOrderedBySpeakerOrder(
                speakerOrder: meetingSpeakerOrder,
                speakerMap: speakerMap
            )
            let frontmatter: MeetingParticipantFrontmatter?
            if participants.isEmpty && speakerMap.isEmpty {
                frontmatter = nil
            } else {
                let speakerOrder = meetingSpeakerOrder
                frontmatter = MeetingParticipantFrontmatter(
                    participants: participants,
                    speakerMap: speakerMap,
                    speakerOrder: speakerOrder
                )
            }

            return KnownSpeakerSuggestionResult(frontmatter: frontmatter, embeddingsBySpeakerID: embeddingsBySpeakerID)
        } catch {
            // Suggestions are best-effort: never fail the pipeline.
            logger.error("Known-speaker suggestion step failed: \(ErrorHandler.debugMessage(for: error), privacy: .public)")
            return nil
        }
    }

    private struct KnownSpeakerSuggestionResult: Sendable {
        var frontmatter: MeetingParticipantFrontmatter?
        var embeddingsBySpeakerID: [Int: [Float]]
    }

    private static func overlapSecondsByClusterSpeakerID(
        entries: [OfflineDiarizerEmbeddingExport.Entry],
        diarizationSegments: [SpeakerSegment]
    ) -> [Int: [Int: Double]] {
        guard !entries.isEmpty, !diarizationSegments.isEmpty else { return [:] }

        var overlaps: [Int: [Int: Double]] = [:]

        for entry in entries {
            let start = entry.startTime
            let end = entry.endTime
            guard end > start else { continue }

            for seg in diarizationSegments {
                let overlapStart = max(start, seg.startSeconds)
                let overlapEnd = min(end, seg.endSeconds)
                let overlap = overlapEnd - overlapStart
                guard overlap > 0 else { continue }

                overlaps[entry.cluster, default: [:]][seg.speakerId, default: 0] += overlap
            }
        }

        return overlaps
    }

    private static func bestSpeakerIDByCluster(_ overlaps: [Int: [Int: Double]]) -> [Int: Int] {
        var result: [Int: Int] = [:]
        result.reserveCapacity(overlaps.count)

        for cluster in overlaps.keys.sorted() {
            guard let speakerOverlaps = overlaps[cluster], !speakerOverlaps.isEmpty else { continue }

            let best = speakerOverlaps
                .sorted { lhs, rhs in
                    if lhs.value != rhs.value { return lhs.value > rhs.value }
                    return lhs.key < rhs.key
                }
                .first

            if let best {
                result[cluster] = best.key
            }
        }

        return result
    }

    private static func bestClusterBySpeakerID(
        _ overlaps: [Int: [Int: Double]],
        clusterToSpeakerId: [Int: Int]
    ) -> [Int: Int] {
        // If multiple clusters map to the same speakerId, keep the cluster with the strongest overlap.
        var best: [Int: (cluster: Int, score: Double)] = [:]

        for (cluster, speakerId) in clusterToSpeakerId {
            let score = overlaps[cluster]?[speakerId] ?? 0

            if let existing = best[speakerId] {
                if score > existing.score || (score == existing.score && cluster < existing.cluster) {
                    best[speakerId] = (cluster: cluster, score: score)
                }
            } else {
                best[speakerId] = (cluster: cluster, score: score)
            }
        }

        return best.mapValues { $0.cluster }
    }

    private static func participantsOrderedBySpeakerOrder(
        speakerOrder: [Int],
        speakerMap: [Int: String]
    ) -> [String] {
        guard !speakerMap.isEmpty else { return [] }

        var result: [String] = []
        result.reserveCapacity(speakerMap.count)

        var seenLowercased: Set<String> = []

        for id in speakerOrder {
            guard let raw = speakerMap[id] else { continue }
            let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }
            let key = trimmed.lowercased()
            if seenLowercased.insert(key).inserted {
                result.append(trimmed)
            }
        }

        if result.count == speakerMap.count {
            return result
        }

        let remaining = speakerMap.values
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .filter { !seenLowercased.contains($0.lowercased()) }
            .sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }

        result.append(contentsOf: remaining)
        return result
    }

    private func attemptRecoverMissingContractAudioIfNeeded(context: PipelineContext) async {
        let fileManager = FileManager.default
        guard !fileManager.fileExists(atPath: context.audioTempURL.path) else { return }
        guard context.audioTempURL.lastPathComponent.lowercased() == "contract.wav" else { return }

        let sessionURL = context.audioTempURL.deletingLastPathComponent()
        let captureURL = sessionURL.appendingPathComponent("capture.caf")
        let systemURL = sessionURL.appendingPathComponent("system.caf")
        let hasCapture = fileManager.fileExists(atPath: captureURL.path)

        guard hasCapture else { return }

        let hasSystem = fileManager.fileExists(atPath: systemURL.path)
        logger.info("Audio input missing; attempting to rebuild contract WAV for \(sessionURL.lastPathComponent, privacy: .private(mask: .hash))")

        do {
            if hasSystem {
                try await AudioWavMixer.mixToContractWav(
                    micURL: captureURL,
                    systemURL: systemURL,
                    outputURL: context.audioTempURL
                )
            } else {
                try await AudioWavConverter.convertToContractWav(
                    inputURL: captureURL,
                    outputURL: context.audioTempURL
                )
            }
            try ContractWavVerifier.verifyContractWav(at: context.audioTempURL)
            logger.info("Recovered missing contract WAV for \(sessionURL.lastPathComponent, privacy: .private(mask: .hash))")
        } catch {
            logger.error("Failed to recover missing contract WAV: \(ErrorHandler.debugMessage(for: error), privacy: .private(mask: .hash))")
        }
    }

    private enum ArtifactCleanupPolicy {
        case all
        case workingDirectoryOnly
    }

    private func cleanupTemporaryArtifacts(
        for context: PipelineContext,
        policy: ArtifactCleanupPolicy = .all
    ) {
        let fileManager = FileManager.default
        let tempRootURL = fileManager.temporaryDirectory.standardizedFileURL
        let tempRootPath = tempRootURL.path.hasSuffix("/") ? tempRootURL.path : tempRootURL.path + "/"

        if policy == .all {
            let audioTempDir = context.audioTempURL.deletingLastPathComponent().standardizedFileURL.path
            if audioTempDir.hasPrefix(tempRootPath) {
                try? fileManager.removeItem(atPath: audioTempDir)
            }
        }

        let workingDir = context.workingDirectoryURL.standardizedFileURL.path
        if workingDir.hasPrefix(tempRootPath) {
            try? fileManager.removeItem(atPath: workingDir)
        }
    }
}
