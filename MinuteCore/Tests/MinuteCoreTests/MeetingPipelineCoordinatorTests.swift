import Foundation
import Testing
@testable import MinuteCore

struct MeetingPipelineCoordinatorTests {
    @Test
    func execute_writesOutputsAndReportsProgress() async throws {
        let vaultRootURL = try makeTemporaryVault()
        defer { try? FileManager.default.removeItem(at: vaultRootURL) }

        let context = try makePipelineContext(saveAudio: true, saveTranscript: true)
        let processedAt = Date(timeIntervalSince1970: 1_701_234_567)
        let coordinator = makeCoordinator(
            vaultRootURL: vaultRootURL,
            summarizationJSON: validExtractionJSON(title: "Weekly Sync", date: "2025-01-12"),
            repairJSON: validExtractionJSON(title: "Weekly Sync", date: "2025-01-12"),
            dateProvider: { processedAt }
        )

        let progressStore = ProgressStore()
        let result = try await coordinator.execute(
            context: context,
            progress: { update in
                progressStore.record(update)
            }
        )

        #expect(FileManager.default.fileExists(atPath: result.noteURL.path))
        #expect(result.audioURL != nil)
        if let audioURL = result.audioURL {
            #expect(FileManager.default.fileExists(atPath: audioURL.path))
        }

        let contract = MeetingFileContract(folders: context.vaultFolders)
        let transcriptRelativePath = contract.transcriptRelativePath(date: context.startedAt, title: "Weekly Sync")
        let transcriptURL = vaultRootURL.appendingPathComponent(transcriptRelativePath)
        #expect(FileManager.default.fileExists(atPath: transcriptURL.path))

        let noteContents = try String(contentsOf: result.noteURL)
        let expectedDate = MeetingNoteDateFormatter.format(processedAt)
        #expect(noteContents.contains("date: \(expectedDate)"))
        #expect(!noteContents.contains("date: 2025-01-12"))

        let snapshot = progressStore.snapshot()
        #expect(
            stages(snapshot.stages, containInOrder: [.downloadingModels, .transcribing, .summarizing, .writing])
        )
        #expect(snapshot.writingExtraction != nil)
    }

    @Test
    func execute_invalidJSON_failsWithoutWritingFallbackNote() async throws {
        let vaultRootURL = try makeTemporaryVault()
        defer { try? FileManager.default.removeItem(at: vaultRootURL) }

        let context = try makePipelineContext(saveAudio: false, saveTranscript: false)
        let checkpointStore = RecordingCheckpointStore()
        let coordinator = makeRecoveryCoordinator(
            vaultRootURL: vaultRootURL,
            transcriptionService: TestTranscriptionService(
                result: TranscriptionResult(
                    text: "invalid output transcript",
                    segments: [TranscriptSegment(startSeconds: 0, endSeconds: 1, text: "invalid output transcript")]
                )
            ),
            summarizationServiceProvider: {
                TestSummarizationService(summarizationJSON: "not json", repairJSON: "still not json")
            },
            checkpointStore: checkpointStore
        )

        do {
            _ = try await coordinator.execute(context: context)
            Issue.record("Expected invalid pass JSON failure")
        } catch {
            #expect(error is MinuteError)
        }

        let writtenPaths = try FileManager.default.subpathsOfDirectory(atPath: vaultRootURL.path)
        #expect(writtenPaths.isEmpty)
    }

    @Test
    func execute_usesTranscriptionOverride() async throws {
        let vaultRootURL = try makeTemporaryVault()
        defer { try? FileManager.default.removeItem(at: vaultRootURL) }

        let override = TranscriptionResult(
            text: "Live transcript",
            segments: [TranscriptSegment(startSeconds: 0, endSeconds: 1, text: "Live transcript")]
        )
        let context = try makePipelineContext(saveAudio: false, saveTranscript: true, transcriptionOverride: override)
        let coordinator = makeCoordinator(
            vaultRootURL: vaultRootURL,
            summarizationJSON: validExtractionJSON(title: "Weekly Sync", date: "2025-01-12"),
            repairJSON: validExtractionJSON(title: "Weekly Sync", date: "2025-01-12"),
            transcriptionService: FailingTranscriptionService()
        )

        _ = try await coordinator.execute(context: context)

        let contract = MeetingFileContract(folders: context.vaultFolders)
        let transcriptRelativePath = contract.transcriptRelativePath(date: context.startedAt, title: "Weekly Sync")
        let transcriptURL = vaultRootURL.appendingPathComponent(transcriptRelativePath)
        let transcriptContents = try String(contentsOf: transcriptURL)
        #expect(transcriptContents.contains("Live transcript"))
    }

    @Test
    func execute_sameMinuteSameTitle_createsUniqueOutputPaths() async throws {
        let vaultRootURL = try makeTemporaryVault()
        defer { try? FileManager.default.removeItem(at: vaultRootURL) }

        let processedAt = Date(timeIntervalSince1970: 1_701_234_567)
        let coordinator = makeCoordinator(
            vaultRootURL: vaultRootURL,
            summarizationJSON: validExtractionJSON(title: "Weekly Sync", date: "2025-01-12"),
            repairJSON: validExtractionJSON(title: "Weekly Sync", date: "2025-01-12"),
            dateProvider: { processedAt }
        )

        let contextA = try makePipelineContext(saveAudio: true, saveTranscript: true)
        let contextB = try makePipelineContext(saveAudio: true, saveTranscript: true)

        let resultA = try await coordinator.execute(context: contextA)
        let resultB = try await coordinator.execute(context: contextB)

        #expect(resultA.noteURL != resultB.noteURL)
        #expect(FileManager.default.fileExists(atPath: resultA.noteURL.path))
        #expect(FileManager.default.fileExists(atPath: resultB.noteURL.path))

        #expect(resultA.audioURL != nil)
        #expect(resultB.audioURL != nil)
        if let audioA = resultA.audioURL, let audioB = resultB.audioURL {
            #expect(audioA != audioB)
            #expect(FileManager.default.fileExists(atPath: audioA.path))
            #expect(FileManager.default.fileExists(atPath: audioB.path))
        }

        let contract = MeetingFileContract(folders: contextA.vaultFolders)
        let baseNoteRelativePath = contract.noteRelativePath(date: contextA.startedAt, title: "Weekly Sync")
        let baseAudioRelativePath = contract.audioRelativePath(date: contextA.startedAt, title: "Weekly Sync")
        let baseTranscriptRelativePath = contract.transcriptRelativePath(date: contextA.startedAt, title: "Weekly Sync")

        func withSuffix(_ relativePath: String, suffix: String) -> String {
            let ns = relativePath as NSString
            let ext = ns.pathExtension
            let base = ns.deletingPathExtension
            return ext.isEmpty ? base + suffix : base + suffix + "." + ext
        }

        let suffix = " (2)"
        let noteBRelativePath = withSuffix(baseNoteRelativePath, suffix: suffix)
        let audioBRelativePath = withSuffix(baseAudioRelativePath, suffix: suffix)
        let transcriptBRelativePath = withSuffix(baseTranscriptRelativePath, suffix: suffix)

        func canonicalFileURL(_ url: URL) -> URL {
            url.resolvingSymlinksInPath().standardizedFileURL
        }

        #expect(canonicalFileURL(resultA.noteURL) == canonicalFileURL(vaultRootURL.appendingPathComponent(baseNoteRelativePath)))
        #expect(canonicalFileURL(resultB.noteURL) == canonicalFileURL(vaultRootURL.appendingPathComponent(noteBRelativePath)))

        let transcriptAURL = vaultRootURL.appendingPathComponent(baseTranscriptRelativePath)
        let transcriptBURL = vaultRootURL.appendingPathComponent(transcriptBRelativePath)
        #expect(FileManager.default.fileExists(atPath: transcriptAURL.path))
        #expect(FileManager.default.fileExists(atPath: transcriptBURL.path))

        if let audioA = resultA.audioURL, let audioB = resultB.audioURL {
            #expect(canonicalFileURL(audioA) == canonicalFileURL(vaultRootURL.appendingPathComponent(baseAudioRelativePath)))
            #expect(canonicalFileURL(audioB) == canonicalFileURL(vaultRootURL.appendingPathComponent(audioBRelativePath)))
        }

        let noteBContents = try String(contentsOf: resultB.noteURL)
        #expect(noteBContents.contains(audioBRelativePath))
        #expect(noteBContents.contains(transcriptBRelativePath))
    }

    @Test
    func execute_runtimeAwareSummarizerRefinesPassPlanAndUsesSummarizePass() async throws {
        let vaultRootURL = try makeTemporaryVault()
        defer { try? FileManager.default.removeItem(at: vaultRootURL) }

        let context = try makePipelineContext(saveAudio: false, saveTranscript: false)
        let runtimeService = RuntimeAwareScriptedSummarizationService(
            plan: SummarizationRuntimePassPlan(
                contextWindowTokens: 8192,
                reservedOutputTokens: 512,
                safetyMarginTokens: 256,
                promptOverheadTokens: 640,
                availableInputTokensPerPass: 6784,
                estimatedTotalInputTokens: 1024,
                chunks: [
                    SummarizationRuntimeChunk(transcript: "refined chunk 1", tokenCount: 300),
                    SummarizationRuntimeChunk(transcript: "refined chunk 2", tokenCount: 280),
                    SummarizationRuntimeChunk(transcript: "refined chunk 3", tokenCount: 260),
                ]
            ),
            passOutputs: [
                validExtractionJSON(title: "Runtime Pass 1", date: "2025-01-12", summary: "First refined pass"),
                validExtractionJSON(title: "Runtime Pass 2", date: "2025-01-12", summary: "Second refined pass"),
                validExtractionJSON(title: "Runtime Pass 3", date: "2025-01-12", summary: "Third refined pass"),
            ]
        )
        let coordinator = makeRecoveryCoordinator(
            vaultRootURL: vaultRootURL,
            transcriptionService: TestTranscriptionService(
                result: TranscriptionResult(
                    text: "tiny transcript",
                    segments: [TranscriptSegment(startSeconds: 0, endSeconds: 1, text: "tiny transcript")]
                )
            ),
            summarizationServiceProvider: { runtimeService },
            checkpointStore: RecordingCheckpointStore()
        )

        _ = try await coordinator.execute(context: context)

        let summarizeCallCount = await runtimeService.summarizeCallCount()
        let passChunks = await runtimeService.recordedPassChunks()

        #expect(summarizeCallCount == 0)
        #expect(passChunks == ["refined chunk 1", "refined chunk 2", "refined chunk 3"])
    }

    @Test
    func execute_preflightUsesConfiguredContextWindow() async throws {
        let vaultRootURL = try makeTemporaryVault()
        defer { try? FileManager.default.removeItem(at: vaultRootURL) }

        let repeatedText = "Transcript " + String(repeating: "chunk ", count: 600)
        let context = try makePipelineContext(saveAudio: false, saveTranscript: false)
        let checkpointStore = RecordingCheckpointStore()
        let coordinator = makeRecoveryCoordinator(
            vaultRootURL: vaultRootURL,
            transcriptionService: TestTranscriptionService(
                result: TranscriptionResult(
                    text: repeatedText,
                    segments: [TranscriptSegment(startSeconds: 0, endSeconds: 1, text: repeatedText)]
                )
            ),
            summarizationServiceProvider: {
                TestSummarizationService(
                    summarizationJSON: validExtractionJSON(title: "Budgeted", date: "2025-01-12"),
                    repairJSON: validExtractionJSON(title: "Budgeted", date: "2025-01-12")
                )
            },
            checkpointStore: checkpointStore,
            summarizationModelID: "llama-test",
            summarizationPreflightConfiguration: SummarizationPreflightConfiguration(
                contextWindowTokens: 32_768,
                reservedOutputTokens: 1_024
            )
        )

        _ = try await coordinator.execute(context: context)

        let meetingID = makeMeetingRunID(for: context)
        let finalState = await checkpointStore.lastSavedState(meetingID: meetingID)

        #expect(finalState?.tokenBudgetEstimate?.contextWindowTokens == 32_768)
        #expect(finalState?.tokenBudgetEstimate?.availableInputTokensPerPass == 30_976)
        #expect(finalState?.tokenBudgetEstimate?.modelID == "llama-test")
        #expect(finalState?.tokenBudgetEstimate?.runID == finalState?.runID)
        #expect(finalState?.passPlan?.runID == finalState?.runID)
    }

    @Test
    func execute_recordsOllamaModelBindingWhenSelected() async throws {
        let vaultRootURL = try makeTemporaryVault()
        defer { try? FileManager.default.removeItem(at: vaultRootURL) }

        let suiteName = "MeetingPipelineCoordinatorTests.ollama.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let providerStore = InferenceProviderSelectionStore(defaults: defaults)
        providerStore.setSelectedProvider(.ollama, for: .summarization)
        providerStore.setSelectedOllamaModelTag("phi4-mini", for: .summarization)

        let runtimeFactory = InferenceRuntimeFactory(
            providerStore: providerStore,
            summarizationModelStore: SummarizationModelSelectionStore(defaults: defaults),
            summarizationContextWindowStore: SummarizationContextWindowSelectionStore(defaults: defaults),
            visionModelStore: VisionModelSelectionStore(defaults: defaults),
            ollamaSummarizationBuilder: { tag in
                #expect(tag == "phi4-mini")
                return TestSummarizationService(
                    summarizationJSON: validExtractionJSON(title: "Ollama", date: "2025-01-12"),
                    repairJSON: validExtractionJSON(title: "Ollama", date: "2025-01-12")
                )
            }
        )

        let checkpointStore = RecordingCheckpointStore()
        let context = try makePipelineContext(saveAudio: false, saveTranscript: false)
        let coordinator = makeRecoveryCoordinator(
            vaultRootURL: vaultRootURL,
            transcriptionService: TestTranscriptionService(
                result: TranscriptionResult(
                    text: "ollama transcript",
                    segments: [TranscriptSegment(startSeconds: 0, endSeconds: 1, text: "ollama transcript")]
                )
            ),
            summarizationServiceProvider: {
                try! runtimeFactory.makeSummarizationService()
            },
            checkpointStore: checkpointStore,
            summarizationModelID: try runtimeFactory.resolveBinding(for: .summarization).providerReference
        )

        _ = try await coordinator.execute(context: context)

        let meetingID = makeMeetingRunID(for: context)
        let finalState = await checkpointStore.lastSavedState(meetingID: meetingID)

        #expect(finalState?.tokenBudgetEstimate?.modelID == "phi4-mini")
    }

    @Test
    func execute_usesCapturedSummarizationBindingEvenIfCurrentSelectionChanges() async throws {
        let vaultRootURL = try makeTemporaryVault()
        defer { try? FileManager.default.removeItem(at: vaultRootURL) }

        let capturedBinding = InferenceTaskBinding(
            capabilityID: .summarization,
            providerID: .ollama,
            providerReference: "phi4-captured",
            supportsVisionInputs: false
        )
        let checkpointStore = RecordingCheckpointStore()
        let serviceFactory = SummarizationBindingServiceFactory()
        var context = try makePipelineContext(saveAudio: false, saveTranscript: false)
        context.summarizationBinding = capturedBinding

        let coordinator = makeRecoveryCoordinator(
            vaultRootURL: vaultRootURL,
            transcriptionService: TestTranscriptionService(
                result: TranscriptionResult(
                    text: "binding transcript",
                    segments: [TranscriptSegment(startSeconds: 0, endSeconds: 1, text: "binding transcript")]
                )
            ),
            summarizationServiceProvider: {
                serviceFactory.makeService(tag: "live-selection")
            },
            checkpointStore: checkpointStore,
            summarizationModelID: "live-selection",
            summarizationPreflightConfiguration: .default
        )

        let boundCoordinator = MeetingPipelineCoordinator(
            transcriptionService: TestTranscriptionService(
                result: TranscriptionResult(
                    text: "binding transcript",
                    segments: [TranscriptSegment(startSeconds: 0, endSeconds: 1, text: "binding transcript")]
                )
            ),
            diarizationService: TestDiarizationService(segments: []),
            summarizationServiceProvider: {
                serviceFactory.makeService(tag: "live-selection")
            },
            modelManager: TestModelManager(progressSteps: [0, 1]),
            checkpointStore: checkpointStore,
            vaultAccess: VaultAccess(bookmarkStore: TestBookmarkStore(bookmark: try? VaultAccess.makeBookmarkData(forVaultRootURL: vaultRootURL))),
            vaultWriter: TestVaultWriter(),
            summarizationServiceForBinding: { binding in
                serviceFactory.makeService(tag: binding.providerReference)
            },
            summarizationModelIDProvider: { "live-selection" },
            summarizationPreflightConfigurationForBinding: { _ in .default }
        )

        _ = try await boundCoordinator.execute(context: context)

        let meetingID = makeMeetingRunID(for: context)
        let finalState = await checkpointStore.lastSavedState(meetingID: meetingID)

        #expect(finalState?.tokenBudgetEstimate?.modelID == "phi4-captured")
        let tags = serviceFactory.recordedTags()
        #expect(tags == ["phi4-captured"])
    }

    @Test
    func execute_failedPassPreservesLastValidCheckpointAndSummaryDocument() async throws {
        let vaultRootURL = try makeTemporaryVault()
        defer { try? FileManager.default.removeItem(at: vaultRootURL) }

        let checkpointStore = RecordingCheckpointStore()
        let context = try makePipelineContext(saveAudio: false, saveTranscript: false)
        let summarizationService = ScriptedSummarizationService(
            steps: [
                .succeed(validExtractionJSON(title: "Weekly Sync", date: "2025-01-12", summary: "First pass summary")),
                .fail("synthetic-pass-failure"),
            ]
        )
        let coordinator = makeRecoveryCoordinator(
            vaultRootURL: vaultRootURL,
            transcriptionService: TestTranscriptionService(result: makeLongTranscriptionResult()),
            summarizationServiceProvider: { summarizationService },
            checkpointStore: checkpointStore,
            summarizationPreflightConfiguration: forcedMultiPassPreflightConfiguration()
        )

        do {
            _ = try await coordinator.execute(context: context)
            Issue.record("Expected synthetic summarization failure")
        } catch {
            // Expected failure path.
        }

        let meetingRunID = makeMeetingRunID(for: context)
        let loadedState = try await checkpointStore.load(meetingID: meetingRunID)
        let state = try #require(loadedState)
        let outputPaths = try #require(state.outputPaths)

        #expect(state.status == .pausedForRetry)
        #expect(state.lastValidCheckpoint?.completedPassIndex == 1)
        #expect(state.passRecords.first(where: { $0.passIndex == 2 })?.status == .failed)
        #expect(state.passRecords.contains(where: { $0.passIndex > 2 && $0.status == .pending }))

        let noteURL = vaultRootURL.appendingPathComponent(outputPaths.noteRelativePath)
        let noteContents = try String(contentsOf: noteURL)
        #expect(noteContents.contains("First pass summary"))
        #expect(!noteContents.contains("Second pass summary"))
    }

    @Test
    func execute_resumeAfterRestartContinuesFromLastCheckpointWithoutDuplicatingNotePath() async throws {
        let vaultRootURL = try makeTemporaryVault()
        defer { try? FileManager.default.removeItem(at: vaultRootURL) }

        let checkpointStore = RecordingCheckpointStore()
        let context = try makePipelineContext(saveAudio: false, saveTranscript: false)
        let twoPassTranscription = TestTranscriptionService(result: makeLongTranscriptionResult(segmentCount: 120))
        let initialService = ScriptedSummarizationService(
            steps: [
                .succeed(validExtractionJSON(title: "Weekly Sync", date: "2025-01-12", summary: "First pass summary")),
                .fail("synthetic-pass-failure"),
            ]
        )
        let initialCoordinator = makeRecoveryCoordinator(
            vaultRootURL: vaultRootURL,
            transcriptionService: twoPassTranscription,
            summarizationServiceProvider: { initialService },
            checkpointStore: checkpointStore,
            summarizationPreflightConfiguration: forcedMultiPassPreflightConfiguration()
        )

        do {
            _ = try await initialCoordinator.execute(context: context)
            Issue.record("Expected synthetic summarization failure")
        } catch {
            // Expected failure path.
        }

        let meetingRunID = makeMeetingRunID(for: context)
        let loadedPausedState = try await checkpointStore.load(meetingID: meetingRunID)
        let pausedState = try #require(loadedPausedState)
        let pausedOutputPaths = try #require(pausedState.outputPaths)

        let resumedService = ScriptedSummarizationService(
            steps: [
                .succeed(validExtractionJSON(title: "Weekly Sync", date: "2025-01-12", summary: "Second pass summary")),
            ]
        )
        let resumedCoordinator = makeRecoveryCoordinator(
            vaultRootURL: vaultRootURL,
            transcriptionService: twoPassTranscription,
            summarizationServiceProvider: { resumedService },
            checkpointStore: checkpointStore,
            summarizationPreflightConfiguration: forcedMultiPassPreflightConfiguration()
        )

        let result = try await resumedCoordinator.execute(context: context)
        let recordedTranscripts = await resumedService.recordedTranscripts()
        let noteContents = try String(contentsOf: result.noteURL)
        let remainingState = try await checkpointStore.load(meetingID: meetingRunID)

        #expect(canonicalFileURL(result.noteURL) == canonicalFileURL(vaultRootURL.appendingPathComponent(pausedOutputPaths.noteRelativePath)))
        #expect(recordedTranscripts.count >= 1)
        #expect(recordedTranscripts[0].contains("First pass summary"))
        #expect(noteContents.contains("First pass summary"))
        #expect(noteContents.contains("Second pass summary"))
        #expect(remainingState == nil)
    }

    @Test
    func execute_laterPassTitleRenamesProgressNotePath() async throws {
        let vaultRootURL = try makeTemporaryVault()
        defer { try? FileManager.default.removeItem(at: vaultRootURL) }

        let checkpointStore = RecordingCheckpointStore()
        let context = try makePipelineContext(saveAudio: false, saveTranscript: false)
        let summarizationService = ScriptedSummarizationService(
            steps: [
                .succeed(validExtractionJSON(title: "", date: "2025-01-12", summary: "First pass summary")),
                .succeed(validExtractionJSON(title: "Weekly Sync", date: "2025-01-12", summary: "Second pass summary")),
            ]
        )
        let coordinator = makeRecoveryCoordinator(
            vaultRootURL: vaultRootURL,
            transcriptionService: TestTranscriptionService(result: makeLongTranscriptionResult(segmentCount: 120)),
            summarizationServiceProvider: { summarizationService },
            checkpointStore: checkpointStore,
            summarizationPreflightConfiguration: forcedMultiPassPreflightConfiguration()
        )

        let result = try await coordinator.execute(context: context)
        let contract = MeetingFileContract(folders: context.vaultFolders)
        let untitledURL = vaultRootURL.appendingPathComponent(
            contract.noteRelativePath(date: context.startedAt, title: "Untitled")
        )
        let titledURL = vaultRootURL.appendingPathComponent(
            contract.noteRelativePath(date: context.startedAt, title: "Weekly Sync")
        )

        #expect(canonicalFileURL(result.noteURL) == canonicalFileURL(titledURL))
        #expect(FileManager.default.fileExists(atPath: titledURL.path))
        #expect(!FileManager.default.fileExists(atPath: untitledURL.path))

        let noteContents = try String(contentsOf: result.noteURL)
        #expect(noteContents.contains("First pass summary"))
        #expect(noteContents.contains("Second pass summary"))
    }

    @Test
    func execute_cancelDuringLaterPassPreservesLatestCheckpoint() async throws {
        let vaultRootURL = try makeTemporaryVault()
        defer { try? FileManager.default.removeItem(at: vaultRootURL) }

        let checkpointStore = RecordingCheckpointStore()
        let context = try makePipelineContext(saveAudio: false, saveTranscript: false)
        let twoPassTranscription = TestTranscriptionService(result: makeLongTranscriptionResult(segmentCount: 120))
        let summarizationService = ScriptedSummarizationService(
            steps: [
                .succeed(validExtractionJSON(title: "Weekly Sync", date: "2025-01-12", summary: "First pass summary")),
                .blockUntilCancelled,
            ]
        )
        let coordinator = makeRecoveryCoordinator(
            vaultRootURL: vaultRootURL,
            transcriptionService: twoPassTranscription,
            summarizationServiceProvider: { summarizationService },
            checkpointStore: checkpointStore,
            summarizationPreflightConfiguration: forcedMultiPassPreflightConfiguration()
        )

        let execution = Task {
            try await coordinator.execute(context: context)
        }

        try await summarizationService.waitUntilCallCount(2)
        execution.cancel()

        do {
            _ = try await execution.value
            Issue.record("Expected cancellation")
        } catch is CancellationError {
            // Expected cancellation path.
        } catch {
            Issue.record("Expected CancellationError, received: \(error)")
        }

        let meetingRunID = makeMeetingRunID(for: context)
        let loadedState = try await checkpointStore.load(meetingID: meetingRunID)
        let state = try #require(loadedState)

        #expect(state.status == .cancelled)
        #expect(state.lastValidCheckpoint?.completedPassIndex == 1)
        #expect(state.passRecords.first(where: { $0.passIndex == 2 })?.status == .cancelled)
    }

    @Test
    func execute_resumeTransitionsStatusFromPausedForRetryBackToRunning() async throws {
        let vaultRootURL = try makeTemporaryVault()
        defer { try? FileManager.default.removeItem(at: vaultRootURL) }

        let checkpointStore = RecordingCheckpointStore()
        let context = try makePipelineContext(saveAudio: false, saveTranscript: false)
        let twoPassTranscription = TestTranscriptionService(result: makeLongTranscriptionResult(segmentCount: 120))
        let failingService = ScriptedSummarizationService(
            steps: [
                .succeed(validExtractionJSON(title: "Weekly Sync", date: "2025-01-12", summary: "First pass summary")),
                .fail("synthetic-pass-failure"),
            ]
        )
        let failingCoordinator = makeRecoveryCoordinator(
            vaultRootURL: vaultRootURL,
            transcriptionService: twoPassTranscription,
            summarizationServiceProvider: { failingService },
            checkpointStore: checkpointStore,
            summarizationPreflightConfiguration: forcedMultiPassPreflightConfiguration()
        )

        do {
            _ = try await failingCoordinator.execute(context: context)
            Issue.record("Expected synthetic summarization failure")
        } catch {
            // Expected failure path.
        }

        let resumedService = ScriptedSummarizationService(
            steps: [
                .succeed(validExtractionJSON(title: "Weekly Sync", date: "2025-01-12", summary: "Second pass summary")),
            ]
        )
        let resumedCoordinator = makeRecoveryCoordinator(
            vaultRootURL: vaultRootURL,
            transcriptionService: twoPassTranscription,
            summarizationServiceProvider: { resumedService },
            checkpointStore: checkpointStore,
            summarizationPreflightConfiguration: forcedMultiPassPreflightConfiguration()
        )

        _ = try await resumedCoordinator.execute(context: context)

        let statuses = await checkpointStore.savedStatuses(meetingID: makeMeetingRunID(for: context))
        #expect(statusesContainInOrder(statuses, sequence: [.running, .pausedForRetry, .running]))
    }
}

private final class ProgressStore: @unchecked Sendable {
    private let lock = NSLock()
    private var stages: [PipelineStage] = []
    private var writingExtraction: MeetingExtraction?

    func record(_ update: PipelineProgress) {
        lock.lock()
        stages.append(update.stage)
        if update.stage == .writing {
            writingExtraction = update.extraction
        }
        lock.unlock()
    }

    func snapshot() -> (stages: [PipelineStage], writingExtraction: MeetingExtraction?) {
        lock.lock()
        defer { lock.unlock() }
        return (stages, writingExtraction)
    }
}

private struct TestModelManager: ModelManaging {
    var progressSteps: [Double]

    func ensureModelsPresent(progress: (@Sendable (ModelDownloadProgress) -> Void)?) async throws {
        for step in progressSteps {
            progress?(ModelDownloadProgress(fractionCompleted: step, label: "test"))
        }
    }

    func validateModels() async throws -> ModelValidationResult {
        ModelValidationResult(missingModelIDs: [], invalidModelIDs: [])
    }

    func removeModels(withIDs ids: [String]) async throws {
        _ = ids
    }
}

private struct TestTranscriptionService: TranscriptionServicing {
    var result: TranscriptionResult

    func transcribe(wavURL: URL) async throws -> TranscriptionResult {
        _ = wavURL
        return result
    }
}

private struct FailingTranscriptionService: TranscriptionServicing {
    func transcribe(wavURL: URL) async throws -> TranscriptionResult {
        _ = wavURL
        throw MinuteError.whisperFailed(exitCode: -1, output: "should not be called")
    }
}

private struct TestDiarizationService: DiarizationServicing {
    var segments: [SpeakerSegment]

    func diarize(wavURL: URL, embeddingExportURL: URL?) async throws -> [SpeakerSegment] {
        _ = wavURL
        _ = embeddingExportURL
        return segments
    }
}

private struct TestSummarizationService: SummarizationServicing {
    var summarizationJSON: String
    var repairJSON: String

    func summarize(
        transcript: String,
        meetingDate: Date,
        meetingType: MeetingType,
        languageProcessing: LanguageProcessingProfile,
        outputLanguage: OutputLanguage
    ) async throws -> String {
        _ = transcript
        _ = meetingDate
        _ = meetingType
        _ = languageProcessing
        _ = outputLanguage
        return summarizationJSON
    }

    func classify(transcript: String) async throws -> MeetingType {
        return .general
    }

    func repairJSON(_ invalidJSON: String) async throws -> String {
        _ = invalidJSON
        return repairJSON
    }
}

private struct TestVaultWriter: VaultWriting {
    func writeAtomically(data: Data, to destinationURL: URL) throws {
        try ensureDirectoryExists(destinationURL.deletingLastPathComponent())
        try data.write(to: destinationURL, options: [.atomic])
    }

    func ensureDirectoryExists(_ url: URL) throws {
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    }
}

private final class SummarizationBindingServiceFactory: @unchecked Sendable {
    private var tags: [String] = []
    private let lock = NSLock()

    func makeService(tag: String) -> any SummarizationServicing {
        lock.lock()
        tags.append(tag)
        lock.unlock()
        return TestSummarizationService(
            summarizationJSON: validExtractionJSON(title: tag, date: "2025-01-12"),
            repairJSON: validExtractionJSON(title: tag, date: "2025-01-12")
        )
    }

    func recordedTags() -> [String] {
        lock.lock()
        defer { lock.unlock() }
        return tags
    }
}

private final class TestBookmarkStore: VaultBookmarkStoring {
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

private func makeCoordinator(
    vaultRootURL: URL,
    summarizationJSON: String,
    repairJSON: String,
    transcriptionService: some TranscriptionServicing = TestTranscriptionService(result: TranscriptionResult(
        text: "Hello world",
        segments: [TranscriptSegment(startSeconds: 0, endSeconds: 1, text: "Hello world")]
    )),
    summarizationModelID: String = SummarizationModelCatalog.defaultModel.id,
    dateProvider: @escaping @Sendable () -> Date = Date.init
) -> MeetingPipelineCoordinator {
    let bookmark = try? VaultAccess.makeBookmarkData(forVaultRootURL: vaultRootURL)
    let store = TestBookmarkStore(bookmark: bookmark)
    let access = VaultAccess(bookmarkStore: store)

    return MeetingPipelineCoordinator(
        transcriptionService: transcriptionService,
        diarizationService: TestDiarizationService(segments: []),
        summarizationServiceProvider: {
            TestSummarizationService(summarizationJSON: summarizationJSON, repairJSON: repairJSON)
        },
        modelManager: TestModelManager(progressSteps: [0, 1]),
        vaultAccess: access,
        vaultWriter: TestVaultWriter(),
        summarizationModelIDProvider: { summarizationModelID },
        dateProvider: dateProvider
    )
}

private func makeTemporaryVault() throws -> URL {
    let url = FileManager.default.temporaryDirectory
        .appendingPathComponent("minute-vault-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    return url
}

private func makePipelineContext(
    saveAudio: Bool,
    saveTranscript: Bool,
    transcriptionOverride: TranscriptionResult? = nil
) throws -> PipelineContext {
    let audioTempURL = try makeTemporaryAudioFile()
    let startedAt = Date(timeIntervalSince1970: 1_700_000_000)
    let stoppedAt = startedAt.addingTimeInterval(60)
    let workingDirectoryURL = FileManager.default.temporaryDirectory
        .appendingPathComponent("minute-work-\(UUID().uuidString)", isDirectory: true)

    return PipelineContext(
        vaultFolders: MeetingFileContract.VaultFolders(),
        audioTempURL: audioTempURL,
        audioDurationSeconds: 60,
        startedAt: startedAt,
        stoppedAt: stoppedAt,
        workingDirectoryURL: workingDirectoryURL,
        saveAudio: saveAudio,
        saveTranscript: saveTranscript,
        screenContextEvents: [],
        transcriptionOverride: transcriptionOverride
    )
}

private func makeTemporaryAudioFile() throws -> URL {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent("minute-audio-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    let fileURL = directory.appendingPathComponent("audio.wav")
    try Data([0x00, 0x01]).write(to: fileURL, options: [.atomic])
    return fileURL
}

private func validExtractionJSON(title: String, date: String, summary: String = "Summary") -> String {
    return #"""
    {
      "title": "\#(title)",
      "date": "\#(date)",
      "summary": "\#(summary)",
      "decisions": [],
      "action_items": [],
      "open_questions": [],
      "key_points": []
    }
    """#
}

private func stages(_ stages: [PipelineStage], containInOrder expected: [PipelineStage]) -> Bool {
    var index = stages.startIndex
    for stage in expected {
        guard let found = stages[index...].firstIndex(of: stage) else {
            return false
        }
        index = stages.index(after: found)
    }
    return true
}

private func makeRecoveryCoordinator(
    vaultRootURL: URL,
    transcriptionService: some TranscriptionServicing,
    summarizationServiceProvider: @escaping @Sendable () -> any SummarizationServicing,
    checkpointStore: any SummarizationCheckpointStoring,
    summarizationModelID: String = SummarizationModelCatalog.defaultModel.id,
    summarizationPreflightConfiguration: SummarizationPreflightConfiguration = .default,
    dateProvider: @escaping @Sendable () -> Date = Date.init
) -> MeetingPipelineCoordinator {
    let bookmark = try? VaultAccess.makeBookmarkData(forVaultRootURL: vaultRootURL)
    let store = TestBookmarkStore(bookmark: bookmark)
    let access = VaultAccess(bookmarkStore: store)

    return MeetingPipelineCoordinator(
        transcriptionService: transcriptionService,
        diarizationService: TestDiarizationService(segments: []),
        summarizationServiceProvider: summarizationServiceProvider,
        modelManager: TestModelManager(progressSteps: [0, 1]),
        checkpointStore: checkpointStore,
        vaultAccess: access,
        vaultWriter: TestVaultWriter(),
        summarizationModelIDProvider: { summarizationModelID },
        summarizationPreflightConfigurationProvider: { summarizationPreflightConfiguration },
        dateProvider: dateProvider
    )
}

private func makeLongTranscriptionResult(segmentCount: Int = 220) -> TranscriptionResult {
    let segments = (0..<segmentCount).map { index in
        TranscriptSegment(
            startSeconds: TimeInterval(index) * 2,
            endSeconds: TimeInterval(index) * 2 + 1.5,
            text: "Segment \(index) repeated transcript content for deterministic multi-pass recovery validation."
        )
    }
    let text = segments.map(\.text).joined(separator: "\n")
    return TranscriptionResult(text: text, segments: segments)
}

private func makeMeetingRunID(for context: PipelineContext) -> String {
    let seed = context.audioTempURL.standardizedFileURL.path + "|" + "\(Int(context.startedAt.timeIntervalSince1970))"
    var hash: UInt64 = 5381
    for byte in seed.utf8 {
        hash = ((hash << 5) &+ hash) &+ UInt64(byte)
    }
    return "meeting-\(String(hash, radix: 16))"
}

private func statusesContainInOrder(
    _ statuses: [SummarizationRunStatus],
    sequence expected: [SummarizationRunStatus]
) -> Bool {
    var index = statuses.startIndex
    for status in expected {
        guard let found = statuses[index...].firstIndex(of: status) else {
            return false
        }
        index = statuses.index(after: found)
    }
    return true
}

private func canonicalFileURL(_ url: URL) -> URL {
    url.resolvingSymlinksInPath().standardizedFileURL
}

private func forcedMultiPassPreflightConfiguration() -> SummarizationPreflightConfiguration {
    SummarizationPreflightConfiguration(
        contextWindowTokens: 1_024,
        reservedOutputTokens: 256,
        safetyMarginTokens: 128,
        promptOverheadTokens: 256
    )
}

private actor RecordingCheckpointStore: SummarizationCheckpointStoring {
    private var states: [String: SummarizationRunState] = [:]
    private var saved: [String: [SummarizationRunState]] = [:]

    func load(meetingID: String) async throws -> SummarizationRunState? {
        states[meetingID]
    }

    func save(_ state: SummarizationRunState, for meetingID: String) async throws {
        states[meetingID] = state
        saved[meetingID, default: []].append(state)
    }

    func clear(meetingID: String) async {
        states.removeValue(forKey: meetingID)
    }

    func savedStatuses(meetingID: String) -> [SummarizationRunStatus] {
        saved[meetingID, default: []].map(\.status)
    }

    func lastSavedState(meetingID: String) -> SummarizationRunState? {
        saved[meetingID]?.last
    }
}

private actor ScriptedSummarizationService: SummarizationServicing {
    enum Step: Sendable {
        case succeed(String)
        case fail(String)
        case blockUntilCancelled
    }

    enum WaitError: Error {
        case timeout
    }

    private let steps: [Step]
    private var transcripts: [String] = []

    init(steps: [Step]) {
        self.steps = steps
    }

    func summarize(
        transcript: String,
        meetingDate: Date,
        meetingType: MeetingType,
        languageProcessing: LanguageProcessingProfile,
        outputLanguage: OutputLanguage
    ) async throws -> String {
        _ = meetingDate
        _ = meetingType
        _ = languageProcessing
        _ = outputLanguage

        transcripts.append(transcript)
        let index = transcripts.count - 1
        let step = steps[min(index, max(steps.count - 1, 0))]

        switch step {
        case .succeed(let json):
            return json
        case .fail(let message):
            throw MinuteError.llamaFailed(exitCode: -1, output: message)
        case .blockUntilCancelled:
            while true {
                try Task.checkCancellation()
                await Task.yield()
            }
        }
    }

    func classify(transcript: String) async throws -> MeetingType {
        _ = transcript
        return .general
    }

    func repairJSON(_ invalidJSON: String) async throws -> String {
        invalidJSON
    }

    func waitUntilCallCount(_ expected: Int) async throws {
        let deadline = Date().addingTimeInterval(1)

        while transcripts.count < expected {
            if Date() > deadline {
                throw WaitError.timeout
            }
            await Task.yield()
        }
    }

    func recordedTranscripts() -> [String] {
        transcripts
    }
}

private actor RuntimeAwareScriptedSummarizationService: RuntimeAwareSummarizationServicing {
    private let plan: SummarizationRuntimePassPlan
    private let passOutputs: [String]
    private var summarizeCalls = 0
    private var passChunks: [String] = []

    init(plan: SummarizationRuntimePassPlan, passOutputs: [String]) {
        self.plan = plan
        self.passOutputs = passOutputs
    }

    func summarize(
        transcript: String,
        meetingDate: Date,
        meetingType: MeetingType,
        languageProcessing: LanguageProcessingProfile,
        outputLanguage: OutputLanguage
    ) async throws -> String {
        _ = transcript
        _ = meetingDate
        _ = meetingType
        _ = languageProcessing
        _ = outputLanguage
        summarizeCalls += 1
        return passOutputs.first ?? validExtractionJSON(title: "Fallback", date: "2025-01-12")
    }

    func summarize(
        transcript: String,
        meetingDate: Date,
        meetingType: MeetingType,
        languageProcessing: LanguageProcessingProfile,
        outputLanguage: OutputLanguage,
        resolvedPromptBundle: ResolvedPromptBundle?
    ) async throws -> String {
        _ = resolvedPromptBundle
        return try await summarize(
            transcript: transcript,
            meetingDate: meetingDate,
            meetingType: meetingType,
            languageProcessing: languageProcessing,
            outputLanguage: outputLanguage
        )
    }

    func makeRuntimePassPlan(
        transcript: String,
        meetingDate: Date,
        meetingType: MeetingType,
        languageProcessing: LanguageProcessingProfile,
        outputLanguage: OutputLanguage,
        resolvedPromptBundle: ResolvedPromptBundle?
    ) async throws -> SummarizationRuntimePassPlan {
        _ = transcript
        _ = meetingDate
        _ = meetingType
        _ = languageProcessing
        _ = outputLanguage
        _ = resolvedPromptBundle
        return plan
    }

    func summarizePass(
        transcriptChunk: String,
        previousSummaryJSON: String?,
        passIndex: Int,
        totalPasses: Int,
        meetingDate: Date,
        meetingType: MeetingType,
        languageProcessing: LanguageProcessingProfile,
        outputLanguage: OutputLanguage,
        resolvedPromptBundle: ResolvedPromptBundle?
    ) async throws -> String {
        _ = previousSummaryJSON
        _ = passIndex
        _ = totalPasses
        _ = meetingDate
        _ = meetingType
        _ = languageProcessing
        _ = outputLanguage
        _ = resolvedPromptBundle
        passChunks.append(transcriptChunk)
        return passOutputs[min(passChunks.count - 1, max(passOutputs.count - 1, 0))]
    }

    func classify(transcript: String) async throws -> MeetingType {
        _ = transcript
        return .general
    }

    func repairJSON(_ invalidJSON: String) async throws -> String {
        invalidJSON
    }

    func summarizeCallCount() -> Int {
        summarizeCalls
    }

    func recordedPassChunks() -> [String] {
        passChunks
    }
}
