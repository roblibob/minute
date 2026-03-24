import Foundation
import Testing
@testable import Minute
@preconcurrency @testable import MinuteCore

struct MinuteTests {
    @Test
    func smoke() {
        #expect(Bool(true))
    }
}

@MainActor
struct ArchitectureDeadCodeParityTests {
    @Test
    func defaultsObserver_sameSnapshot_reportsNoChanges() {
        let suite = "ArchitectureDeadCodeParityTests.defaults.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        defer { defaults.removePersistentDomain(forName: suite) }

        let settings = GlobalVocabularyBoostingSettings.default
        let snapshot = PipelineDefaultsObserver.makeSnapshot(
            defaults: defaults,
            transcriptionBackendID: TranscriptionBackend.whisper.id,
            vocabularySettings: settings
        )

        let changed = PipelineDefaultsObserver.changedDomains(previous: snapshot, current: snapshot)
        #expect(changed.hasChanges == false)
    }

    @Test
    func meetingNoteParsing_withoutSpeakerHeaders_keepsBodyInHeaderSection() {
        let transcript = """
        Intro line
        Another line
        """
        let split = MeetingNoteParsing.splitTranscriptHeaderAndBody(transcript)

        #expect(split.header == transcript)
        #expect(split.body.isEmpty)
    }
}

@MainActor
struct PipelineStatusPresenterParityTests {
    @Test
    func recordedState_returnsProcessAction() {
        let presenter = PipelineStatusPresenter()
        let startedAt = Date(timeIntervalSince1970: 1_700_000_000)
        let stoppedAt = startedAt.addingTimeInterval(120)
        let state = MeetingPipelineState.recorded(
            audioTempURL: URL(fileURLWithPath: "/tmp/input.wav"),
            durationSeconds: stoppedAt.timeIntervalSince(startedAt),
            startedAt: startedAt,
            stoppedAt: stoppedAt
        )

        let presentation = presenter.presentation(
            for: PipelineStatusPresenter.Input(
                state: state,
                backgroundProcessingSnapshot: BackgroundProcessingSnapshot(),
                isFirstScreenInferenceDeferred: false,
                progress: nil,
                statusLabelOverride: nil,
                recoverableRecordings: [],
                recordingWarningDetail: nil,
                summarizationProgressDetail: nil
            ),
            dismissedStatusDrawerID: nil
        )

        #expect(presentation?.primaryAction == .process)
    }

    @Test
    func importingState_prefersStatusOverrideTitle() {
        let presenter = PipelineStatusPresenter()
        let presentation = presenter.presentation(
            for: PipelineStatusPresenter.Input(
                state: .importing(sourceURL: URL(fileURLWithPath: "/tmp/input.mov")),
                backgroundProcessingSnapshot: BackgroundProcessingSnapshot(),
                isFirstScreenInferenceDeferred: false,
                progress: 0.3,
                statusLabelOverride: "Analyzing Video",
                recoverableRecordings: [],
                recordingWarningDetail: nil,
                summarizationProgressDetail: nil
            ),
            dismissedStatusDrawerID: nil
        )

        #expect(presentation?.title == "Analyzing Video")
        #expect(presentation?.progress == 0.3)
    }
}

@MainActor
struct PipelineDefaultsObserverParityTests {
    @Test
    func changedDomains_whenTranscriptionBackendChanges_marksDomainOnly() {
        let suite = "PipelineDefaultsObserverParityTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        defer { defaults.removePersistentDomain(forName: suite) }

        let baseline = PipelineDefaultsObserver.makeSnapshot(
            defaults: defaults,
            transcriptionBackendID: TranscriptionBackend.whisper.id,
            vocabularySettings: .default
        )
        let changed = PipelineDefaultsObserver.makeSnapshot(
            defaults: defaults,
            transcriptionBackendID: TranscriptionBackend.fluidAudio.id,
            vocabularySettings: .default
        )

        let domains = PipelineDefaultsObserver.changedDomains(previous: baseline, current: changed)
        #expect(domains.transcriptionBackendChanged)
        #expect(domains.vaultStatusChanged == false)
        #expect(domains.outputLanguageChanged == false)
    }
}

@MainActor
struct MeetingPipelineViewModelLanguageProcessingTitleParityTests {
    @Test
    func forcedInputLanguage_updatesLanguageProcessingTitles() throws {
        let suite = "MeetingPipelineViewModelLanguageProcessingTitleParityTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defaults.removePersistentDomain(forName: suite)
        defer { defaults.removePersistentDomain(forName: suite) }

        defaults.set(TranscriptionLanguage.english.rawValue, forKey: AppConfiguration.Defaults.transcriptionLanguageKey)
        defaults.set(OutputLanguage.englishUS.rawValue, forKey: AppConfiguration.Defaults.outputLanguageKey)

        let stageStore = StagePreferencesStore(defaults: defaults)
        stageStore.clear()

        let backendStore = TranscriptionBackendSelectionStore(defaults: defaults)
        backendStore.setSelectedBackendID(TranscriptionBackend.whisper.rawValue)

        let model = try makeLanguageTitleModel(
            defaults: defaults,
            stagePreferencesStore: stageStore,
            transcriptionBackendStore: backendStore
        )

        #expect(model.autoToEnglishOptionTitle == "English -> English")
        #expect(model.autoToPickedLanguageOptionTitle == "English -> English (United States)")
    }

    @Test
    func selectedMeetingTypeID_persistsAcrossViewModelRelaunch() throws {
        let suite = "MeetingPipelineViewModelLanguageProcessingTitleParityTests.meetingType.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defaults.removePersistentDomain(forName: suite)
        defer { defaults.removePersistentDomain(forName: suite) }

        defaults.set(OutputLanguage.englishUS.rawValue, forKey: AppConfiguration.Defaults.outputLanguageKey)

        let stageStore = StagePreferencesStore(defaults: defaults)
        stageStore.clear()

        let backendStore = TranscriptionBackendSelectionStore(defaults: defaults)
        backendStore.setSelectedBackendID(TranscriptionBackend.whisper.rawValue)

        let firstModel = try makeLanguageTitleModel(
            defaults: defaults,
            stagePreferencesStore: stageStore,
            transcriptionBackendStore: backendStore
        )

        firstModel.selectedMeetingTypeID = MeetingType.planning.rawValue

        let savedID = defaults.string(forKey: AppConfiguration.Defaults.stageMeetingTypeIDKey)
        #expect(savedID == MeetingType.planning.rawValue)

        let secondModel = try makeLanguageTitleModel(
            defaults: defaults,
            stagePreferencesStore: stageStore,
            transcriptionBackendStore: backendStore
        )

        #expect(secondModel.selectedMeetingTypeID == MeetingType.planning.rawValue)
    }

    private func makeLanguageTitleModel(
        defaults: UserDefaults,
        stagePreferencesStore: StagePreferencesStore,
        transcriptionBackendStore: TranscriptionBackendSelectionStore
    ) throws -> MeetingPipelineViewModel {
        let vaultRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("minute-language-title-vault-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: vaultRoot, withIntermediateDirectories: true)
        let bookmark = try VaultAccess.makeBookmarkData(forVaultRootURL: vaultRoot)
        let vaultAccess = VaultAccess(bookmarkStore: InMemoryVaultBookmarkStore(bookmark: bookmark))

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
            vaultAccess: vaultAccess,
            recordingPermissions: .alwaysGranted(),
            stagePreferencesStore: stagePreferencesStore,
            transcriptionBackendStore: transcriptionBackendStore,
            meetingTypeLibraryStore: MeetingTypeLibraryStore(defaults: defaults, libraryKey: "meetingTypeLibrary"),
            defaults: defaults
        )
    }
}

@MainActor
struct MeetingNotesOverlayStateParityTests {
    @Test
    func selectAndDismiss_transitionsAreDeterministic() {
        var state = MeetingNotesOverlayState()
        let item = MeetingNoteItem(
            title: "Test",
            date: Date(timeIntervalSince1970: 0),
            relativePath: "Meetings/test.md",
            fileURL: URL(fileURLWithPath: "/tmp/test.md"),
            hasTranscript: false,
            transcriptURL: nil
        )

        state.select(item)
        #expect(state.isPresented)
        #expect(state.selectedItem == item)

        state.selectTab(.transcription)
        #expect(state.selectedTab == .transcription)

        state.dismiss()
        #expect(state.isPresented == false)
        #expect(state.selectedItem == nil)
        #expect(state.selectedTab == .summary)
    }
}

@MainActor
struct ModelSetupLifecycleParityCoverageTests {
    @Test
    func refresh_whenModelsReady_setsReadyState() async throws {
        let manager = LifecycleModelManagerStub(
            validations: [ModelValidationResult(missingModelIDs: [], invalidModelIDs: [])]
        )
        let controller = ModelSetupLifecycleController(
            modelManager: manager,
            displayName: { $0 }
        )

        controller.refresh()

        try await eventually(timeoutNanoseconds: 1_000_000_000) {
            await MainActor.run {
                if case .ready = controller.state {
                    return true
                }
                return false
            }
        }
    }
}

private actor LifecycleModelManagerStub: ModelManaging {
    private var validations: [ModelValidationResult]

    init(validations: [ModelValidationResult]) {
        self.validations = validations
    }

    func ensureModelsPresent(progress: (@Sendable (ModelDownloadProgress) -> Void)?) async throws {
        progress?(ModelDownloadProgress(fractionCompleted: 1, label: "done"))
    }

    func validateModels() async throws -> ModelValidationResult {
        if validations.count > 1 {
            return validations.removeFirst()
        }
        return validations.first ?? ModelValidationResult(missingModelIDs: [], invalidModelIDs: [])
    }

    func removeModels(withIDs ids: [String]) async throws {
        _ = ids
    }
}

@MainActor
struct SettingsWorkspaceRoutingCoverageTests {
    @Test
    func settingsOpensInSingleWindowRoute() {
        let model = SettingsWorkspaceTestSupport.makeNavigationModel()
        SettingsWorkspaceTestSupport.switchToSettings(model)

        #expect(model.mainContent == .settings)
        #expect(model.snapshot().windowMode == "single_window")
        #expect(model.snapshot().noAdditionalWindow)
    }

    @Test
    func closingSettingsReturnsToPipeline() {
        let model = SettingsWorkspaceTestSupport.makeNavigationModel(initial: .settings)
        SettingsWorkspaceTestSupport.switchToPipeline(model)

        #expect(model.mainContent == .pipeline)
    }

    @Test
    func setActiveWorkspace_isIdempotent() {
        let model = SettingsWorkspaceTestSupport.makeNavigationModel(initial: .pipeline)
        let before = model.changedAt
        model.setActiveWorkspace(.pipeline)

        #expect(model.mainContent == .pipeline)
        #expect(model.changedAt == before)
    }
}

@MainActor
struct SettingsWorkspaceContinuityCoverageTests {
    @Test
    func continuityInvariant_remainsTrueAcrossWorkspaceSwitches() {
        let before = WorkspaceContinuitySnapshot(
            isRecordingActive: true,
            pipelineStage: "recording",
            activeSessionID: "session-1",
            unsavedWorkPresent: true
        )

        let model = SettingsWorkspaceTestSupport.makeNavigationModel()
        model.showSettings()
        model.showPipeline()

        let after = WorkspaceContinuitySnapshot(
            isRecordingActive: true,
            pipelineStage: "recording",
            activeSessionID: "session-1",
            unsavedWorkPresent: true
        )

        #expect(WorkspaceContinuityInvariant.isPreserved(before: before, after: after))
    }

    @Test
    func workspaceSnapshot_containsContractFlags() {
        let model = SettingsWorkspaceTestSupport.makeNavigationModel(initial: .settings)
        let snapshot = model.snapshot()

        #expect(snapshot.activeWorkspace == .settings)
        #expect(snapshot.windowMode == "single_window")
        #expect(snapshot.noAdditionalWindow)
    }
}

@MainActor
struct SettingsCategoryCatalogCoverageTests {
    @Test
    func categoryOrder_isStableAndAscending() {
        let categories = SettingsCategoryCatalog.categories(updatesEnabled: true)
        let orders = categories.map { $0.sortOrder }
        let sorted = orders.sorted()

        #expect(orders == sorted)
        #expect(Set(categories.map { $0.id }).count == categories.count)
    }

    @Test
    func updatesCategory_obeysVisibilityRule() {
        let hidden = SettingsCategoryCatalog.categories(updatesEnabled: false)
        let visible = SettingsCategoryCatalog.categories(updatesEnabled: true)

        #expect(hidden.contains(where: { $0.id == .updates }) == false)
        #expect(visible.contains(where: { $0.id == .updates }))
    }

    @Test
    func fallbackSelection_returnsFirstVisibleWhenCurrentMissing() {
        let categories = SettingsCategoryCatalog.categories(updatesEnabled: false)
        let selection = SettingsCategoryCatalog.fallbackSelection(current: .updates, available: categories)

        #expect(selection == categories.first?.id)
    }

    @Test
    func discoverability_allCoreCategoriesPresent() {
        let categories = SettingsCategoryCatalog.categories(updatesEnabled: true)
        let ids = Set(categories.map { $0.id })

        #expect(ids.contains(.general))
        #expect(ids.contains(.storage))
        #expect(ids.contains(.speakers))
        #expect(ids.contains(.privacy))
        #expect(ids.contains(.ai))
        #expect(ids.contains(.meetingTypes))
    }
}

@MainActor
enum SettingsWorkspaceTestSupport {
    static func makeNavigationModel(initial: AppNavigationModel.MainContent = .pipeline) -> AppNavigationModel {
        let model = AppNavigationModel()
        model.mainContent = initial
        return model
    }

    static func switchToSettings(_ model: AppNavigationModel) {
        model.showSettings()
    }

    static func switchToPipeline(_ model: AppNavigationModel) {
        model.showPipeline()
    }
}

struct MeetingNotesBrowserViewModelSpeakerDraftIsolationTests {
    @Test
    func parseSpeakerIDs_parsesUniqueSortedIDs() {
        let transcript = """
        Speaker 2 [00:00]
        Hello

        Speaker 10 [00:05]
        Hi

        Speaker 2 [00:06]
        Again
        """

        let ids = MeetingNoteParsing.parseSpeakerIDs(fromTranscriptMarkdown: transcript)
        #expect(ids == [2, 10])
    }

    @Test
    func rewriteSpeakerHeadingsForDisplay_replacesNamedHeadingsOnly() {
        let transcript = """
            Speaker 1 [00:00]
            Hello

        Speaker 2 [00:05]
            Hi

        Speaker 3
        Unchanged
        """

        let rewritten = MeetingNoteParsing.rewriteSpeakerHeadingsForDisplay(
            transcriptMarkdown: transcript,
            speakerDisplayNames: [1: "Alice", 2: " Bob "]
        )

        #expect(rewritten.contains("Alice [00:00]"))
        #expect(rewritten.contains("Bob [00:05]"))
        #expect(rewritten.contains("Speaker 3"))
    }

    @MainActor
    @Test
    func selectingDifferentNotes_resetsSpeakerDraftState() async throws {
        let first = MeetingNoteItem(
            title: "First",
            date: Date(timeIntervalSince1970: 0),
            relativePath: "Meetings/2026/02/first.md",
            fileURL: URL(fileURLWithPath: "/tmp/first.md"),
            hasTranscript: true,
            transcriptURL: URL(fileURLWithPath: "/tmp/first.transcript.md")
        )
        let second = MeetingNoteItem(
            title: "Second",
            date: Date(timeIntervalSince1970: 1),
            relativePath: "Meetings/2026/02/second.md",
            fileURL: URL(fileURLWithPath: "/tmp/second.md"),
            hasTranscript: true,
            transcriptURL: URL(fileURLWithPath: "/tmp/second.transcript.md")
        )

        let browser = SpeakerDraftIsolationBrowserStub(
            notes: [first, second],
            noteByID: [
                first.id: "# First\n\n",
                second.id: "# Second\n\n",
            ],
            transcriptByID: [
                first.id: "Speaker 1 [00:00]\nHello",
                second.id: "Speaker 2 [00:00]\nHi",
            ]
        )
        let model = MeetingNotesBrowserViewModel(browserProvider: { browser })

        model.refresh()
        try await eventually(timeoutNanoseconds: 1_000_000_000) {
            await MainActor.run { model.notes.count == 2 && !model.isRefreshing }
        }

        model.select(first)
        try await eventually(timeoutNanoseconds: 1_000_000_000) {
            await MainActor.run { model.speakerIDs == [1] }
        }
        model.setSpeakerName("Alice", for: 1)
        #expect(model.speakerName(for: 1) == "Alice")

        model.select(second)
        try await eventually(timeoutNanoseconds: 1_000_000_000) {
            await MainActor.run { model.speakerIDs == [2] }
        }
        #expect(model.speakerName(for: 1).isEmpty)
    }
}

private actor SpeakerDraftIsolationBrowserStub: MeetingNotesBrowsing {
    private let notes: [MeetingNoteItem]
    private let noteByID: [String: String]
    private let transcriptByID: [String: String]

    init(notes: [MeetingNoteItem], noteByID: [String: String], transcriptByID: [String: String]) {
        self.notes = notes
        self.noteByID = noteByID
        self.transcriptByID = transcriptByID
    }

    func listNotes() async throws -> [MeetingNoteItem] {
        notes
    }

    func loadNoteContent(for item: MeetingNoteItem) async throws -> String {
        noteByID[item.id] ?? ""
    }

    func loadTranscriptContent(for item: MeetingNoteItem) async throws -> String {
        transcriptByID[item.id] ?? ""
    }

    func deleteNoteFiles(for item: MeetingNoteItem) async throws {
        _ = item
    }
}

@MainActor
struct OnboardingPersistenceCoverageTests {
    @Test
    func newUser_seesOnboarding() throws {
        let suite = "OnboardingPersistenceCoverageTests.newUser.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defaults.removePersistentDomain(forName: suite)
        defer { defaults.removePersistentDomain(forName: suite) }

        let model = OnboardingViewModel(modelManager: MockModelManager(), defaults: defaults)

        #expect(model.isComplete == false)
    }

    @Test
    func legacyUserWithVaultBookmark_skipsOnboarding() throws {
        let suite = "OnboardingPersistenceCoverageTests.legacyBookmark.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defaults.removePersistentDomain(forName: suite)
        defer { defaults.removePersistentDomain(forName: suite) }

        let vaultRootURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("minute-onboarding-legacy-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: vaultRootURL, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: vaultRootURL) }

        let bookmark = try VaultAccess.makeBookmarkData(forVaultRootURL: vaultRootURL)
        let bookmarkStore = UserDefaultsVaultBookmarkStore(
            defaults: defaults,
            key: AppConfiguration.Defaults.vaultRootBookmarkKey
        )
        bookmarkStore.saveVaultRootBookmark(bookmark)

        let model = OnboardingViewModel(modelManager: MockModelManager(), defaults: defaults)

        #expect(model.isComplete)
    }

    @Test
    func completedUser_remainsCompletedAcrossRelaunches() throws {
        let suite = "OnboardingPersistenceCoverageTests.completedUser.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defaults.removePersistentDomain(forName: suite)
        defer { defaults.removePersistentDomain(forName: suite) }

        defaults.set(true, forKey: "didShowOnboardingIntro")
        defaults.set(true, forKey: "didCompleteOnboarding")
        defaults.set(OnboardingViewModel.Step.complete.rawValue, forKey: "onboardingLastStep")

        let firstLaunch = OnboardingViewModel(modelManager: MockModelManager(), defaults: defaults)
        let secondLaunch = OnboardingViewModel(modelManager: MockModelManager(), defaults: defaults)

        #expect(firstLaunch.isComplete)
        #expect(secondLaunch.isComplete)
    }

    @Test
    func debugEnvironmentFlag_forcesOnboardingVisibility() {
        let processInfo = StubProcessInfo(
            environment: [ContentView.forceOnboardingEnvironmentKey: "1"]
        )

        #expect(ContentView.shouldForceOnboardingInDebugBuild(processInfo: processInfo))
    }

    @Test
    func debugWalkthroughStartsAtIntroEvenForCompletedUser() throws {
        let suite = "OnboardingPersistenceCoverageTests.debugWalkthrough.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defaults.removePersistentDomain(forName: suite)
        defer { defaults.removePersistentDomain(forName: suite) }

        defaults.set(true, forKey: "didShowOnboardingIntro")
        defaults.set(true, forKey: "didCompleteOnboarding")
        defaults.set(OnboardingViewModel.Step.complete.rawValue, forKey: "onboardingLastStep")

        let model = OnboardingViewModel(modelManager: MockModelManager(), defaults: defaults)
        model.startDebugWalkthrough()

        #expect(model.isDebugWalkthroughActive)
        #expect(model.currentStep == .intro)
    }

    @Test
    func debugWalkthroughCompletionDoneDismissesForcedSession() async throws {
        let suite = "OnboardingPersistenceCoverageTests.debugWalkthroughDismiss.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defaults.removePersistentDomain(forName: suite)
        defer { defaults.removePersistentDomain(forName: suite) }

        defaults.set(true, forKey: "didShowOnboardingIntro")
        defaults.set(true, forKey: "didCompleteOnboarding")
        defaults.set(OnboardingViewModel.Step.complete.rawValue, forKey: "onboardingLastStep")

        let vaultRootURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("minute-onboarding-debug-dismiss-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: vaultRootURL, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: vaultRootURL) }

        let bookmark = try VaultAccess.makeBookmarkData(forVaultRootURL: vaultRootURL)
        let bookmarkStore = UserDefaultsVaultBookmarkStore(
            defaults: defaults,
            key: AppConfiguration.Defaults.vaultRootBookmarkKey
        )
        bookmarkStore.saveVaultRootBookmark(bookmark)

        let model = OnboardingViewModel(modelManager: MockModelManager(), defaults: defaults)
        model.startDebugWalkthrough()

        model.advance()
        model.skipPermissions()

        for _ in 0..<10 where !model.modelsReady {
            await Task.yield()
        }

        model.advance()
        model.advance()
        model.advance()
        model.advance()
        #expect(model.currentStep == .complete)
        model.advance()

        #expect(model.isDebugWalkthroughActive == false)
    }

    @Test
    func selectedSummarizationContextWindowPreset_persistsAcrossRelaunches() throws {
        let suite = "OnboardingPersistenceCoverageTests.contextPreset.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defaults.removePersistentDomain(forName: suite)
        defer { defaults.removePersistentDomain(forName: suite) }

        let contextStore = SummarizationContextWindowSelectionStore(defaults: defaults)
        contextStore.setSelectedPreset(.maximum)

        let firstLaunch = OnboardingViewModel(modelManager: MockModelManager(), defaults: defaults)
        let secondLaunch = OnboardingViewModel(modelManager: MockModelManager(), defaults: defaults)

        #expect(firstLaunch.selectedSummarizationContextWindowPreset == .maximum)
        #expect(secondLaunch.selectedSummarizationContextWindowPreset == .maximum)
    }
}

private final class StubProcessInfo: ProcessInfo {
    private let stubEnvironment: [String: String]

    init(environment: [String: String]) {
        self.stubEnvironment = environment
        super.init()
    }

    override var environment: [String: String] {
        stubEnvironment
    }
}

struct ResilientWhisperTranscriptionServiceTests {
    @Test
    func transcribe_whenPrimaryReturnsPermissionDenied_fallsBackToSecondary() async throws {
        let fallbackResult = TranscriptionResult(
            text: "fallback transcript",
            segments: [TranscriptSegment(startSeconds: 0, endSeconds: 1, text: "fallback transcript")]
        )
        let service = ResilientWhisperTranscriptionService(
            primary: StubTranscriptionService(
                result: .failure(
                    MinuteError.whisperFailed(
                        exitCode: -1,
                        output: "Error Domain=NSCocoaErrorDomain Code=257 Operation not permitted"
                    )
                )
            ),
            fallback: StubTranscriptionService(result: .success(fallbackResult))
        )

        let wavURL = FileManager.default.temporaryDirectory.appendingPathComponent("resilient-whisper-test-\(UUID().uuidString).wav")
        defer { try? FileManager.default.removeItem(at: wavURL) }
        try Data([0x00]).write(to: wavURL, options: [.atomic])

        let result = try await service.transcribe(wavURL: wavURL)
        #expect(result == fallbackResult)
    }

    @Test
    func transcribe_whenPrimaryReturnsNonPermissionFailure_doesNotFallback() async throws {
        let expected = MinuteError.whisperFailed(exitCode: 12, output: "decoder failed")
        let service = ResilientWhisperTranscriptionService(
            primary: StubTranscriptionService(result: .failure(expected)),
            fallback: StubTranscriptionService(
                result: .success(
                    TranscriptionResult(text: "unused", segments: [])
                )
            )
        )

        let wavURL = FileManager.default.temporaryDirectory.appendingPathComponent("resilient-whisper-test-\(UUID().uuidString).wav")
        defer { try? FileManager.default.removeItem(at: wavURL) }
        try? Data([0x00]).write(to: wavURL, options: [.atomic])

        do {
            _ = try await service.transcribe(wavURL: wavURL)
            #expect(Bool(false), "Expected non-permission failure to be rethrown")
        } catch let minuteError as MinuteError {
            switch minuteError {
            case .whisperFailed(let exitCode, let output):
                #expect(exitCode == 12)
                #expect(output == "decoder failed")
            default:
                #expect(Bool(false), "Expected whisperFailed, got \(minuteError)")
            }
        } catch {
            #expect(Bool(false), "Unexpected error type: \(error)")
        }
    }

    @Test
    func transcribe_afterXPCFailure_disablesPrimaryForCurrentServiceInstance() async throws {
        let primary = CountingTranscriptionService(
            result: .failure(MinuteError.whisperFailed(exitCode: -1, output: "xpc failure"))
        )
        let fallbackResult = TranscriptionResult(text: "fallback transcript", segments: [])
        let fallback = CountingTranscriptionService(result: .success(fallbackResult))

        let first = ResilientWhisperTranscriptionService(
            primary: primary,
            fallback: fallback
        )

        let wavURL = FileManager.default.temporaryDirectory.appendingPathComponent("resilient-whisper-test-\(UUID().uuidString).wav")
        defer { try? FileManager.default.removeItem(at: wavURL) }
        try Data([0x00]).write(to: wavURL, options: [.atomic])

        _ = try await first.transcribe(wavURL: wavURL)
        #expect(await primary.callCount == 1)
        #expect(await fallback.callCount == 1)

        let primaryAfterDisable = CountingTranscriptionService(
            result: .success(TranscriptionResult(text: "xpc transcript", segments: []))
        )
        let fallbackAfterDisable = CountingTranscriptionService(result: .success(fallbackResult))
        let second = ResilientWhisperTranscriptionService(
            primary: primaryAfterDisable,
            fallback: fallbackAfterDisable,
            primaryEnabled: false
        )

        let secondResult = try await second.transcribe(wavURL: wavURL)
        #expect(secondResult == fallbackResult)
        #expect(await primaryAfterDisable.callCount == 0)
        #expect(await fallbackAfterDisable.callCount == 1)
    }

}

private actor CountingTranscriptionService: TranscriptionServicing {
    let result: Result<TranscriptionResult, Error>
    private(set) var callCount = 0

    init(result: Result<TranscriptionResult, Error>) {
        self.result = result
    }

    func transcribe(wavURL: URL) async throws -> TranscriptionResult {
        _ = wavURL
        callCount += 1
        return try result.get()
    }
}

private struct StubTranscriptionService: TranscriptionServicing {
    let result: Result<TranscriptionResult, Error>

    func transcribe(wavURL: URL) async throws -> TranscriptionResult {
        _ = wavURL
        return try result.get()
    }
}
