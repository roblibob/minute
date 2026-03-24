import AppKit
import CoreGraphics
import QuartzCore
@preconcurrency import AVFoundation
import Combine
import Foundation
import MinuteCore
import MinuteLlama
import MinuteOllama
import MinuteWhisper
import os
import UniformTypeIdentifiers

final class ActiveVisionBindingStore: @unchecked Sendable {
    private let lock = NSLock()
    nonisolated(unsafe) private var binding: InferenceTaskBinding?

    nonisolated init() {}

    nonisolated func set(_ binding: InferenceTaskBinding?) {
        lock.lock()
        self.binding = binding
        lock.unlock()
    }

    nonisolated func currentBinding() -> InferenceTaskBinding? {
        lock.lock()
        defer { lock.unlock() }
        return binding
    }
}

private func makeLiveScreenContextInferencerProvider(
    runtimeFactory: InferenceRuntimeFactory,
    activeVisionBindingStore: ActiveVisionBindingStore
) -> @Sendable () -> any ScreenContextInferencing {
    {
        let binding = activeVisionBindingStore.currentBinding()
        do {
            if let binding {
                return try runtimeFactory.makeScreenContextInferencer(binding: binding)
            }
            return try runtimeFactory.makeScreenContextInferencer()
        } catch let minuteError as MinuteError {
            return ErrorScreenContextInferenceService(error: minuteError)
        } catch {
            return ErrorScreenContextInferenceService(
                error: .llamaMTMDFailed(exitCode: -1, output: ErrorHandler.debugMessage(for: error))
            )
        }
    }
}

@MainActor
final class MeetingPipelineViewModel: ObservableObject {
    struct RecordingPermissions: Sendable {
        var requestMicrophonePermission: @Sendable () async throws -> Bool
        var requestScreenRecordingPermission: @Sendable () async throws -> Bool

        nonisolated static func live() -> RecordingPermissions {
            RecordingPermissions(
                requestMicrophonePermission: {
                    // Gate on microphone permission.
                    let status = AVCaptureDevice.authorizationStatus(for: .audio)
                    switch status {
                    case .authorized:
                        return true

                    case .notDetermined:
                        let granted = await AVCaptureDevice.requestAccess(for: .audio)
                        if !granted { throw MinuteError.permissionDenied }
                        return granted

                    case .denied, .restricted:
                        throw MinuteError.permissionDenied

                    @unknown default:
                        throw MinuteError.permissionDenied
                    }
                },
                requestScreenRecordingPermission: {
                    let granted = await ScreenRecordingPermission.refresh()
                    if !granted {
                        throw MinuteError.screenRecordingPermissionDenied
                    }
                    return granted
                }
            )
        }

        nonisolated static func alwaysGranted() -> RecordingPermissions {
            RecordingPermissions(
                requestMicrophonePermission: { true },
                requestScreenRecordingPermission: { true }
            )
        }
    }

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
        case stopping
    }

    @Published private(set) var state: MeetingPipelineState = .idle
    @Published private(set) var captureState: CaptureState = .ready
    @Published private(set) var progress: Double? = nil
    @Published private(set) var statusLabelOverride: String? = nil
    @Published private(set) var summarizationProgressDetail: String? = nil
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
    @Published private(set) var silenceStatus: SilenceStatusSnapshot = SilenceStatusSnapshot()
    @Published private(set) var activeSilenceAlert: RecordingAlert? = nil
    @Published private(set) var activeScreenContextAlert: RecordingAlert? = nil
    @Published private(set) var recordingSessionEvents: [RecordingSessionEvent] = []
    @Published private(set) var transcriptionBackend: TranscriptionBackend = .whisper
    @Published private(set) var sessionVocabularyMode: VocabularyBoostingSessionMode = .default
    @Published private(set) var sessionCustomVocabularyInput: String = ""
    @Published private(set) var sessionVocabularyWarningMessage: String? = nil
    @Published private(set) var vocabularyBoostingEnabledInSettings: Bool = false
    @Published private(set) var globalVocabularyTerms: [String] = []
    @Published private(set) var meetingTypeOptions: [MeetingTypeDefinition] = MeetingTypeLibrary.default.activeDefinitions
    @Published private(set) var transcriptionInputLanguage: TranscriptionLanguage = .defaultSelection
    @Published var selectedMeetingTypeID: String = AppConfiguration.Defaults.defaultStageMeetingTypeID
    @Published var meetingType: MeetingType = .autodetect
    @Published var languageProcessing: LanguageProcessingProfile = .autoToEnglish
    @Published var outputLanguage: OutputLanguage = .defaultSelection

    var transcriptionInputLanguageTitle: String {
        switch transcriptionInputLanguage {
        case .auto:
            return "Auto"
        default:
            return transcriptionInputLanguage.displayName
        }
    }

    var autoToEnglishOptionTitle: String {
        "\(transcriptionInputLanguageTitle) -> English"
    }

    var autoToPickedLanguageOptionTitle: String {
        "\(transcriptionInputLanguageTitle) -> \(outputLanguage.displayName)"
    }

    var selectedLanguageProcessingTitle: String {
        switch languageProcessing {
        case .autoToEnglish:
            return autoToEnglishOptionTitle
        case .autoPreserve:
            return autoToPickedLanguageOptionTitle
        }
    }

    var selectedMeetingTypeDisplayName: String {
        meetingTypeOptions.first(where: { $0.typeId == selectedMeetingTypeID })?.displayName
            ?? "Unavailable (select meeting type)"
    }

    var selectedMeetingTypeStatusText: String {
        guard let definition = meetingTypeOptions.first(where: { $0.typeId == selectedMeetingTypeID }) else {
            return "Unavailable"
        }
        switch definition.source {
        case .custom:
            return "Custom"
        case .builtIn:
            if MeetingTypeLibrary.default.definition(for: definition.typeId)?.promptComponents != definition.promptComponents {
                return "Built-in (Overridden)"
            }
            return "Built-in (Default)"
        }
    }

    var selectedMeetingTypeWarningMessage: String? {
        guard !isSelectedMeetingTypeAvailable else { return nil }
        return "Selected meeting type is no longer available. Choose another type before processing."
    }

    var currentStatusLabel: String {
        statusLabelOverride ?? state.statusLabel
    }

    var isSelectedMeetingTypeAvailable: Bool {
        meetingTypeOptions.contains(where: { $0.typeId == selectedMeetingTypeID })
    }

    func meetingTypeMenuLabel(for definition: MeetingTypeDefinition) -> String {
        let suffix: String
        switch definition.source {
        case .custom:
            suffix = "Custom"
        case .builtIn:
            let isOverridden = MeetingTypeLibrary.default.definition(for: definition.typeId)?.promptComponents != definition.promptComponents
            suffix = isOverridden ? "Edited" : ""
        }
        guard !suffix.isEmpty else { return definition.displayName }
        return "\(definition.displayName) (\(suffix))"
    }

    var selectedLanguageProcessingDetailText: String {
        switch languageProcessing {
        case .autoToEnglish:
            return "Detect transcript language and write outputs in English."
        case .autoPreserve:
            return "Detect transcript language and write outputs in \(outputLanguage.displayName)."
        }
    }

    var activeSilenceWarningMessage: String? {
        activeSilenceAlert?.message
    }

    var activeSilenceWarningSecondsRemaining: Int? {
        activeSilenceAlert?.expiresAt.map { max(Int(ceil($0.timeIntervalSinceNow)), 0) }
    }

    var activeScreenContextAlertMessage: String? {
        activeScreenContextAlert?.message
    }

    var activeScreenContextWarningSecondsRemaining: Int? {
        activeScreenContextAlert?.expiresAt.map { max(Int(ceil($0.timeIntervalSinceNow)), 0) }
    }

    var isFluidAudioBackendSelected: Bool {
        transcriptionBackend == .fluidAudio
    }

    var sessionVocabularyHintText: String {
        "Use for names, acronyms, product terms. Settings terms are included automatically."
    }

    var showsSessionVocabularyPopoverButton: Bool {
        isFluidAudioBackendSelected && vocabularyBoostingEnabledInSettings
    }

    var sessionVocabularyListLabel: String {
        sessionVocabularyMode == .custom ? "Custom" : "Default"
    }

    private let audioService: any AudioServicing
    private let mediaImportService: any MediaImporting
    private let recoveryService: any RecordingRecoveryServicing
    private let pipelineCoordinator: MeetingPipelineCoordinator
    private let processingBusyGate: ProcessingBusyGate
    private let processingOrchestrator: MeetingProcessingOrchestrator
    private let screenContextCaptureService: ScreenContextCaptureService
    private let screenContextVideoExtractor: ScreenContextVideoFrameExtractor
    private let screenContextSettingsStore: ScreenContextSettingsStore
    private let recordingPermissions: RecordingPermissions
    private let stagePreferencesStore: StagePreferencesStore
    private let silenceDetectionPolicy: SilenceDetectionPolicy
    private let recordingAlertNotifier: any RecordingAlertNotifying
    private let transcriptionBackendStore: TranscriptionBackendSelectionStore
    private let meetingTypeLibraryStore: MeetingTypeLibraryStore
    private let vocabularySettingsStore: any VocabularyBoostingSettingsStoring
    private let sessionVocabularyResolver: any SessionVocabularyResolving
    private let modelValidationProvider: @Sendable () async throws -> ModelValidationResult
    private let visionAvailabilityProvider: @Sendable () async throws -> CapabilityAvailabilityState
    private let resolveSummarizationBinding: @Sendable () throws -> InferenceTaskBinding
    private let resolveVisionBinding: @Sendable () throws -> InferenceTaskBinding
    private let activeVisionBindingStore: ActiveVisionBindingStore

    private let vaultAccess: VaultAccess

    private let logger = Logger(subsystem: "roblibob.Minute", category: "pipeline")
    private let defaults: UserDefaults

    private var defaultsObserver: AnyCancellable?
    private var observedDefaultsSnapshot: PipelineDefaultsObserver.Snapshot?
    private var cancellables: Set<AnyCancellable> = []
    private var processingTask: Task<Void, Never>?
    private var backgroundProcessingObserverTask: Task<Void, Never>?
    private var isPreparingPipelineContext = false
    private var lastAudioLevelUpdate: CFTimeInterval = 0
    private var screenContextEvents: [ScreenContextEvent] = []
    @Published private var screenCaptureSelection: ScreenContextWindowSelection?
    private var screenCaptureBaseProcessedCount = 0
    private var screenCaptureBaseSkippedCount = 0

    private let audioLevelBucketCount = 24
    private let audioLevelUpdateInterval: CFTimeInterval = 1.0 / 24.0
    private var screenContextFrameIntervalSeconds: TimeInterval {
        screenContextSettingsStore.captureIntervalSeconds
    }
    private var silenceController: (any SilenceAutoStopControlling)?
    private var screenContextAutoStopTask: Task<Void, Never>?
    private var sessionVocabularyReadiness = VocabularyReadinessStatus.unsupported(backend: .whisper)
	
    init(
        audioService: some AudioServicing,
        mediaImportService: some MediaImporting,
        recoveryService: some RecordingRecoveryServicing,
        pipelineCoordinator: MeetingPipelineCoordinator,
        screenContextCaptureService: ScreenContextCaptureService,
        screenContextVideoExtractor: ScreenContextVideoFrameExtractor,
        screenContextSettingsStore: ScreenContextSettingsStore,
        vaultAccess: VaultAccess,
        recordingPermissions: RecordingPermissions = .live(),
        stagePreferencesStore: StagePreferencesStore = StagePreferencesStore(),
        silenceDetectionPolicy: SilenceDetectionPolicy = .default,
        recordingAlertNotifier: (any RecordingAlertNotifying)? = nil,
        transcriptionBackendStore: TranscriptionBackendSelectionStore = TranscriptionBackendSelectionStore(),
        meetingTypeLibraryStore: MeetingTypeLibraryStore = MeetingTypeLibraryStore(),
        vocabularySettingsStore: (any VocabularyBoostingSettingsStoring) = VocabularyBoostingSettingsStore(),
        sessionVocabularyResolver: (any SessionVocabularyResolving) = SessionVocabularyResolver(),
        modelValidationProvider: (@Sendable () async throws -> ModelValidationResult)? = nil,
        visionAvailabilityProvider: (@Sendable () async throws -> CapabilityAvailabilityState)? = nil,
        resolveSummarizationBinding: (@Sendable () throws -> InferenceTaskBinding)? = nil,
        resolveVisionBinding: (@Sendable () throws -> InferenceTaskBinding)? = nil,
        activeVisionBindingStore: ActiveVisionBindingStore? = nil,
        defaults: UserDefaults = .standard
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
        self.recordingPermissions = recordingPermissions
        self.stagePreferencesStore = stagePreferencesStore
        self.silenceDetectionPolicy = silenceDetectionPolicy
        self.recordingAlertNotifier = recordingAlertNotifier ?? RecordingAlertNotificationCoordinator()
        self.transcriptionBackendStore = transcriptionBackendStore
        self.meetingTypeLibraryStore = meetingTypeLibraryStore
        self.vocabularySettingsStore = vocabularySettingsStore
        self.sessionVocabularyResolver = sessionVocabularyResolver
        self.modelValidationProvider = modelValidationProvider ?? { ModelValidationResult(missingModelIDs: [], invalidModelIDs: []) }
        self.visionAvailabilityProvider = visionAvailabilityProvider ?? {
            CapabilityAvailabilityState(
                capabilityID: .vision,
                providerID: .builtIn,
                isReady: true,
                status: .ready
            )
        }
        self.resolveSummarizationBinding = resolveSummarizationBinding ?? {
            InferenceTaskBinding(
                capabilityID: .summarization,
                providerID: .builtIn,
                providerReference: SummarizationModelCatalog.defaultModel.id,
                supportsVisionInputs: false
            )
        }
        self.resolveVisionBinding = resolveVisionBinding ?? {
            InferenceTaskBinding(
                capabilityID: .vision,
                providerID: .builtIn,
                providerReference: SummarizationModelCatalog.defaultModel.id,
                supportsVisionInputs: true
            )
        }
        self.activeVisionBindingStore = activeVisionBindingStore ?? ActiveVisionBindingStore()
        self.vaultAccess = vaultAccess
        self.defaults = defaults
        self.screenCaptureEnabled = screenContextSettingsStore.isEnabled

        refreshMeetingTypeOptions()
        loadStagePreferences()

        refreshVaultStatus()
        refreshTranscriptionInputLanguageSetting()
        refreshOutputLanguageSetting()
        refreshTranscriptionBackendSetting()
        refreshVocabularySettings()
        refreshMicrophonePermission()
        refreshScreenRecordingPermission()
        observedDefaultsSnapshot = makeObservedDefaultsSnapshot()

        defaultsObserver = NotificationCenter.default.publisher(
            for: UserDefaults.didChangeNotification,
            object: defaults
        )
            .receive(on: RunLoop.main)
            .debounce(for: .milliseconds(200), scheduler: RunLoop.main)
            .sink { [weak self] _ in
                self?.handleDefaultsDidChange()
            }

        startStagePreferencesObservation()
        startRecordingAlertActionObservation()

        refreshRecoverableRecordings()

        startBackgroundProcessingObservation()
    }

    private func loadStagePreferences() {
        refreshMeetingTypeOptions()
        let preferences = stagePreferencesStore.load()
        let savedTypeID = preferences.meetingTypeID.trimmingCharacters(in: .whitespacesAndNewlines)
        selectedMeetingTypeID = savedTypeID.isEmpty
            ? AppConfiguration.Defaults.defaultStageMeetingTypeID
            : savedTypeID
        meetingType = MeetingType(rawValue: selectedMeetingTypeID) ?? .general
        languageProcessing = preferences.languageProcessing
        microphoneCaptureEnabled = preferences.microphoneEnabled
        systemAudioCaptureEnabled = preferences.systemAudioEnabled

        Task { [weak self] in
            await self?.applyAudioCaptureToggles()
        }
    }

    private func saveStagePreferences(
        meetingTypeID: String? = nil,
        languageProcessing: LanguageProcessingProfile? = nil,
        microphoneEnabled: Bool? = nil,
        systemAudioEnabled: Bool? = nil
    ) {
        stagePreferencesStore.save(
            StagePreferences(
                meetingTypeID: meetingTypeID ?? selectedMeetingTypeID,
                languageProcessing: languageProcessing ?? self.languageProcessing,
                microphoneEnabled: microphoneEnabled ?? microphoneCaptureEnabled,
                systemAudioEnabled: systemAudioEnabled ?? systemAudioCaptureEnabled
            )
        )
    }

    private func refreshMeetingTypeOptions() {
        let loadedLibrary = meetingTypeLibraryStore.load()
        meetingTypeOptions = loadedLibrary.activeDefinitions
        if selectedMeetingTypeID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            selectedMeetingTypeID = loadedLibrary.defaultTypeId
        }
    }

    private func startStagePreferencesObservation() {
        $selectedMeetingTypeID
            .removeDuplicates()
            .dropFirst()
            .sink { [weak self] meetingTypeID in
                guard let self else { return }
                self.meetingType = MeetingType(rawValue: meetingTypeID) ?? .general
                self.saveStagePreferences(meetingTypeID: meetingTypeID)
            }
            .store(in: &cancellables)

        $meetingType
            .map(\.rawValue)
            .removeDuplicates()
            .dropFirst()
            .sink { [weak self] meetingTypeRaw in
                guard let self else { return }
                if self.selectedMeetingTypeID != meetingTypeRaw {
                    self.selectedMeetingTypeID = meetingTypeRaw
                }
            }
            .store(in: &cancellables)

        $languageProcessing
            .removeDuplicates()
            .dropFirst()
            .sink { [weak self] languageProcessing in
                self?.saveStagePreferences(languageProcessing: languageProcessing)
            }
            .store(in: &cancellables)

        $microphoneCaptureEnabled
            .removeDuplicates()
            .dropFirst()
            .sink { [weak self] microphoneEnabled in
                self?.saveStagePreferences(microphoneEnabled: microphoneEnabled)
            }
            .store(in: &cancellables)

        $systemAudioCaptureEnabled
            .removeDuplicates()
            .dropFirst()
            .sink { [weak self] systemAudioEnabled in
                self?.saveStagePreferences(systemAudioEnabled: systemAudioEnabled)
            }
            .store(in: &cancellables)
    }

    private func startRecordingAlertActionObservation() {
        NotificationCenter.default.publisher(for: .minuteRecordingAlertKeepRecording)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.keepRecordingFromWarning()
            }
            .store(in: &cancellables)
    }

    deinit {
        processingTask?.cancel()
        backgroundProcessingObserverTask?.cancel()
        screenContextAutoStopTask?.cancel()
        let captureService = screenContextCaptureService
        let silenceController = silenceController
        Task { [captureService] in
            await captureService.cancelCapture()
        }
        Task { [silenceController] in
            await silenceController?.stop()
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
        let defaults = UserDefaults.standard
        let providerStore = InferenceProviderSelectionStore(defaults: defaults)
        let ollamaEndpointStore = OllamaEndpointSettingsStore(defaults: defaults)
        let selectionStore = SummarizationModelSelectionStore(defaults: defaults)
        let contextWindowStore = SummarizationContextWindowSelectionStore(defaults: defaults)
        let visionModelStore = VisionModelSelectionStore(defaults: defaults)
        let hardwareProfile = SummarizationHardwareProfile.current()
        let transcriptionSelectionStore = TranscriptionModelSelectionStore(defaults: defaults)
        let transcriptionBackendStore = TranscriptionBackendSelectionStore(defaults: defaults)
        let fluidAudioModelStore = FluidAudioASRModelSelectionStore(defaults: defaults)
        let ollamaModelDiscovererProvider: @Sendable () -> (any OllamaModelDiscovering)? = {
            guard let baseURL = ollamaEndpointStore.selectedBaseURL() else {
                return nil
            }
            return OllamaModelDiscoveryService(client: OllamaAPIClient(baseURL: baseURL))
        }
        let runtimeFactory = InferenceRuntimeFactory(
            providerStore: providerStore,
            summarizationModelStore: selectionStore,
            summarizationContextWindowStore: contextWindowStore,
            visionModelStore: visionModelStore,
            hardwareProfileProvider: { hardwareProfile },
            builtInSummarizationBuilder: { store, contextStore, profile in
                LlamaLibrarySummarizationService.liveDefault(
                    selectionStore: store,
                    contextWindowStore: contextStore,
                    hardwareProfile: profile
                )
            },
            ollamaSummarizationBuilder: { tag in
                guard let baseURL = ollamaEndpointStore.selectedBaseURL() else {
                    return ErrorSummarizationService(
                        error: .llamaFailed(exitCode: -1, output: "Invalid Ollama base URL")
                    )
                }
                return OllamaSummarizationService(
                    modelTag: tag,
                    client: OllamaAPIClient(baseURL: baseURL)
                )
            },
            builtInVisionBuilder: { store in
                let model = store.selectedModel()
                guard let mmprojURL = model.mmprojDestinationURL else {
                    return ErrorScreenContextInferenceService(error: .mmprojMissing)
                }
                return LlamaMTMDScreenInferenceService(
                    configuration: LlamaMTMDScreenInferenceConfiguration(
                        modelURL: model.destinationURL,
                        mmprojURL: mmprojURL
                    )
                )
            },
            ollamaVisionBuilder: { tag in
                guard let baseURL = ollamaEndpointStore.selectedBaseURL() else {
                    return ErrorScreenContextInferenceService(
                        error: .llamaMTMDFailed(exitCode: -1, output: "Invalid Ollama base URL")
                    )
                }
                return OllamaVisionInferenceService(
                    modelTag: tag,
                    client: OllamaAPIClient(baseURL: baseURL)
                )
            },
            ollamaModelDiscoverer: ollamaModelDiscovererProvider()
        )
        let activeVisionBindingStore = ActiveVisionBindingStore()
        let liveScreenContextInferencerProvider = makeLiveScreenContextInferencerProvider(
            runtimeFactory: runtimeFactory,
            activeVisionBindingStore: activeVisionBindingStore
        )
        let summarizationServiceProvider: @Sendable () -> any SummarizationServicing = {
            do {
                return try runtimeFactory.makeSummarizationService()
            } catch let minuteError as MinuteError {
                return ErrorSummarizationService(error: minuteError)
            } catch {
                return ErrorSummarizationService(
                    error: .llamaFailed(exitCode: -1, output: ErrorHandler.debugMessage(for: error))
                )
            }
        }
        let transcriptionService: any TranscriptionServicing
        switch transcriptionBackendStore.selectedBackend() {
        case .whisper:
            transcriptionService = ResilientWhisperTranscriptionService.liveDefault()
        case .fluidAudio:
            transcriptionService = FluidAudioTranscriptionService.liveDefault(selectionStore: fluidAudioModelStore)
        }
        let bookmarkStore = UserDefaultsVaultBookmarkStore(key: AppConfiguration.Defaults.vaultRootBookmarkKey)
        let vaultAccess = VaultAccess(bookmarkStore: bookmarkStore)
        let modelManager = DefaultModelManager(
            providerStore: providerStore,
            selectionStore: selectionStore,
            visionModelStore: visionModelStore,
            transcriptionSelectionStore: transcriptionSelectionStore,
            transcriptionBackendStore: transcriptionBackendStore,
            fluidAudioModelStore: fluidAudioModelStore
        )
        let coordinator = MeetingPipelineCoordinator(
            transcriptionService: transcriptionService,
            diarizationService: FluidAudioOfflineDiarizationService.meetingDefault(),
            summarizationServiceProvider: summarizationServiceProvider,
            audioLoudnessNormalizer: AudioLoudnessNormalizer(),
            modelManager: modelManager,
            vaultAccess: vaultAccess,
            vaultWriter: DefaultVaultWriter(),
            summarizationServiceForBinding: { binding in
                do {
                    return try runtimeFactory.makeSummarizationService(binding: binding)
                } catch let minuteError as MinuteError {
                    return ErrorSummarizationService(error: minuteError)
                } catch {
                    return ErrorSummarizationService(
                        error: .llamaFailed(exitCode: -1, output: ErrorHandler.debugMessage(for: error))
                    )
                }
            },
            summarizationModelIDProvider: {
                do {
                    return try runtimeFactory.resolveBinding(for: .summarization).providerReference
                } catch {
                    return selectionStore.selectedModel().id
                }
            },
            summarizationPreflightConfigurationForBinding: { binding in
                runtimeFactory.preflightConfiguration(for: binding)
            },
            summarizationPreflightConfigurationProvider: {
                let provider = providerStore.selectedProvider(for: .summarization)
                switch provider {
                case .builtIn:
                    return SummarizationPreflightConfiguration(
                        contextWindowTokens: contextWindowStore.requestedContextTokens(
                            hardwareProfile: hardwareProfile
                        ),
                        reservedOutputTokens: 1_024
                    )
                case .ollama:
                    return .default
                }
            }
        )

        return MeetingPipelineViewModel(
            audioService: DefaultAudioService(),
            mediaImportService: DefaultMediaImportService(),
            recoveryService: DefaultRecordingRecoveryService(),
            pipelineCoordinator: coordinator,
            screenContextCaptureService: ScreenContextCaptureService(
                inferencerProvider: liveScreenContextInferencerProvider
            ),
            screenContextVideoExtractor: ScreenContextVideoFrameExtractor(
                inferencerProvider: liveScreenContextInferencerProvider
            ),
            screenContextSettingsStore: ScreenContextSettingsStore(),
            vaultAccess: vaultAccess,
            transcriptionBackendStore: transcriptionBackendStore,
            vocabularySettingsStore: VocabularyBoostingSettingsStore(),
            sessionVocabularyResolver: SessionVocabularyResolver(),
            modelValidationProvider: {
                try await modelManager.validateModels()
            },
            visionAvailabilityProvider: {
                if let ollamaModelDiscoverer = ollamaModelDiscovererProvider(),
                   providerStore.selectedProvider(for: .vision) == .ollama,
                   let tag = providerStore.selectedOllamaModelTag(for: .vision)?
                    .trimmingCharacters(in: .whitespacesAndNewlines),
                   !tag.isEmpty {
                    return try await ollamaModelDiscoverer.validateModelTag(tag, for: .vision)
                }
                return try await runtimeFactory.availability(for: .vision)
            },
            resolveSummarizationBinding: {
                try runtimeFactory.resolveBinding(for: .summarization)
            },
            resolveVisionBinding: {
                try runtimeFactory.resolveBinding(for: .vision)
            },
            activeVisionBindingStore: activeVisionBindingStore
        )
    }

    func refreshVaultStatus() {
        let hasBookmark = defaults.data(forKey: AppConfiguration.Defaults.vaultRootBookmarkKey) != nil
        let storedPath = defaults.string(forKey: AppConfiguration.Defaults.vaultRootPathDisplayKey)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let displayText: String
        if hasBookmark {
            if let storedPath, !storedPath.isEmpty {
                displayText = storedPath
            } else {
                displayText = "Vault selected"
            }
        } else {
            displayText = "Not selected"
        }
        let updatedStatus = VaultStatus(displayText: displayText, isConfigured: hasBookmark)
        guard vaultStatus != updatedStatus else { return }
        vaultStatus = updatedStatus
    }

    func refreshOutputLanguageSetting() {
        let rawValue = defaults.string(forKey: AppConfiguration.Defaults.outputLanguageKey)
        outputLanguage = OutputLanguage.resolved(from: rawValue)
    }

    func refreshTranscriptionInputLanguageSetting() {
        let rawValue = defaults.string(forKey: AppConfiguration.Defaults.transcriptionLanguageKey)
        transcriptionInputLanguage = TranscriptionLanguage.resolved(from: rawValue)
    }

    func refreshTranscriptionBackendSetting() {
        transcriptionBackend = transcriptionBackendStore.selectedBackend()
        if transcriptionBackend != .fluidAudio {
            sessionVocabularyWarningMessage = nil
            sessionVocabularyReadiness = .unsupported(backend: transcriptionBackend)
        }
        syncSessionVocabularyModeWithCurrentInput()
    }

    func refreshVocabularySettings() {
        let settings = vocabularySettingsStore.load()
        vocabularyBoostingEnabledInSettings = settings.enabled
        globalVocabularyTerms = settings.terms
        syncSessionVocabularyModeWithCurrentInput(using: settings)
    }

    private func handleDefaultsDidChange() {
        let snapshot = makeObservedDefaultsSnapshot()
        let changed = PipelineDefaultsObserver.changedDomains(previous: observedDefaultsSnapshot, current: snapshot)
        guard changed.hasChanges else { return }
        observedDefaultsSnapshot = snapshot

        if changed.requiresFullRefresh || changed.vaultStatusChanged {
            refreshVaultStatus()
        }
        if changed.requiresFullRefresh || changed.outputLanguageChanged {
            refreshOutputLanguageSetting()
        }
        if changed.requiresFullRefresh || changed.transcriptionLanguageChanged {
            refreshTranscriptionInputLanguageSetting()
        }
        if changed.requiresFullRefresh || changed.transcriptionBackendChanged {
            refreshTranscriptionBackendSetting()
        }
        if changed.requiresFullRefresh || changed.vocabularySettingsChanged {
            refreshVocabularySettings()
        }
    }

    private func makeObservedDefaultsSnapshot() -> PipelineDefaultsObserver.Snapshot {
        PipelineDefaultsObserver.makeSnapshot(
            defaults: defaults,
            transcriptionBackendID: transcriptionBackendStore.selectedBackendID(),
            vocabularySettings: vocabularySettingsStore.load()
        )
    }

    func setSessionVocabularyMode(_ mode: VocabularyBoostingSessionMode) {
        if mode == .custom {
            sessionVocabularyMode = .custom
            return
        }

        sessionCustomVocabularyInput = ""
        syncSessionVocabularyModeWithCurrentInput()
        if mode == .off {
            sessionVocabularyWarningMessage = nil
        }
    }

    func setSessionCustomVocabularyInput(_ input: String) {
        sessionCustomVocabularyInput = input
        syncSessionVocabularyModeWithCurrentInput()
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
        case .cancelRecording:
            cancelSessionIfAllowed()
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

        processingTask = Task(priority: .utility) { [weak self] in
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

    var currentScreenCaptureSelection: ScreenContextWindowSelection? {
        screenCaptureSelection
    }

    var screenCaptureSelectionDisplayText: String? {
        guard let selection = screenCaptureSelection else { return nil }
        let title = selection.windowTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        if title.isEmpty {
            return selection.applicationName
        }
        return "\(selection.applicationName) — \(title)"
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

    func setScreenCaptureSelection(_ selection: ScreenContextWindowSelection?) {
        guard let selection else {
            clearScreenCaptureSelection()
            return
        }
        setScreenCaptureSelection(selection)
    }

    func clearScreenCaptureSelection() {
        screenCaptureSelection = nil
        latestScreenCaptureImage = nil

        guard screenCaptureEnabled else { return }
        screenCaptureEnabled = false
        Task { [weak self] in
            await self?.stopScreenContextCaptureAndAppend()
        }
    }

    // MARK: - Actions

    private func startRecordingIfAllowed(selection: ScreenContextWindowSelection?) {
        guard captureState == .ready else { return }
        guard state.canStartRecording else { return }
        guard !state.canCancelProcessing else { return }

        let resolvedSelection: ScreenContextWindowSelection? = {
            if let selection { return selection }
            guard screenCaptureEnabled else { return nil }
            return screenCaptureSelection
        }()
        let shouldCaptureScreen = (resolvedSelection != nil)

        if screenCaptureEnabled, resolvedSelection == nil {
            screenCaptureEnabled = false
        }

        Task {
            do {
                let requestedVisionAvailability = shouldCaptureScreen
                    ? ((try? await visionAvailabilityProvider()) ?? CapabilityAvailabilityState(
                        capabilityID: .vision,
                        providerID: .ollama,
                        isReady: false,
                        status: .daemonUnavailable,
                        message: "Ollama is unavailable. Start the local daemon and refresh."
                    ))
                    : CapabilityAvailabilityState(
                        capabilityID: .vision,
                        providerID: .builtIn,
                        isReady: true,
                        status: .ready
                    )
                sessionVocabularyReadiness = await resolveSessionVocabularyReadiness()
                let globalSettings = vocabularySettingsStore.load()
                let vocabularyResolution = sessionVocabularyResolver.resolve(
                    globalSettings: globalSettings,
                    sessionMode: sessionVocabularyMode,
                    sessionCustomInput: sessionCustomVocabularyInput,
                    readiness: sessionVocabularyReadiness
                )
                sessionVocabularyWarningMessage = vocabularyResolution.warningMessage

                microphonePermissionGranted = try await recordingPermissions.requestMicrophonePermission()
                if shouldCaptureScreen {
                    screenRecordingPermissionGranted = try await recordingPermissions.requestScreenRecordingPermission()
                }

                let shouldStartScreenCapture = shouldCaptureScreen && requestedVisionAvailability.isReady

                if let resolvedSelection, shouldStartScreenCapture {
                    screenCaptureSelection = resolvedSelection
                    screenCaptureEnabled = true
                    activeVisionBindingStore.set(try resolveVisionBinding())
                } else {
                    activeVisionBindingStore.set(nil)
                    if shouldCaptureScreen && !requestedVisionAvailability.isReady {
                        screenCaptureEnabled = false
                    }
                }

                latestScreenCaptureImage = nil
                screenContextEvents = []
                screenInferenceStatus = nil
                screenCaptureBaseProcessedCount = 0
                screenCaptureBaseSkippedCount = 0
                recordingSessionEvents = []
                screenContextAutoStopTask?.cancel()
                screenContextAutoStopTask = nil
                activeSilenceAlert = nil
                activeScreenContextAlert = nil
                silenceStatus = SilenceStatusSnapshot()
                await recordingAlertNotifier.clearSilenceStopWarning()
                await recordingAlertNotifier.clearSharedWindowClosedWarning()

                let session = RecordingSession()
                await applyAudioCaptureToggles()
                try await audioService.startRecording()
                await startScreenContextCaptureIfNeeded(
                    selection: shouldStartScreenCapture ? resolvedSelection : nil,
                    offsetSeconds: 0
                )
                await startAudioLevelMonitoring()
                resetAudioLevelSamples()
                state = .recording(session: session)
                captureState = .recording
                await startSilenceMonitoring(for: session)
                if shouldCaptureScreen && !requestedVisionAvailability.isReady {
                    await presentScreenContextConfigurationAlert(
                        sessionID: session.id,
                        message: requestedVisionAvailability.message ?? "Screen context is unavailable for the selected vision configuration."
                    )
                }
            } catch let minuteError as MinuteError {
                await stopAudioLevelMonitoring()
                await screenContextCaptureService.cancelCapture()
                await stopSilenceMonitoring()
                activeVisionBindingStore.set(nil)
                screenInferenceStatus = nil
                screenContextEvents = []
                screenCaptureSelection = nil
                screenCaptureBaseProcessedCount = 0
                screenCaptureBaseSkippedCount = 0
                await clearActiveRecordingWarnings()
                silenceStatus = SilenceStatusSnapshot()
                state = .failed(error: minuteError, debugOutput: minuteError.debugSummary)
                captureState = .ready
            } catch {
                await stopAudioLevelMonitoring()
                await screenContextCaptureService.cancelCapture()
                await stopSilenceMonitoring()
                activeVisionBindingStore.set(nil)
                screenInferenceStatus = nil
                screenContextEvents = []
                screenCaptureSelection = nil
                screenCaptureBaseProcessedCount = 0
                screenCaptureBaseSkippedCount = 0
                await clearActiveRecordingWarnings()
                silenceStatus = SilenceStatusSnapshot()
                state = .failed(error: .audioExportFailed, debugOutput: ErrorHandler.debugMessage(for: error))
                captureState = .ready
            }
        }
    }

    private func cancelSessionIfAllowed() {
        guard case .recording(let session) = state else { return }
        guard captureState == .recording else { return }

        Task {
            await stopAudioLevelMonitoring()
            await stopSilenceMonitoring()
            resetAudioLevelSamples()
            await screenContextCaptureService.cancelCapture()
            activeVisionBindingStore.set(nil)
            screenInferenceStatus = nil
            screenContextEvents = []
            screenCaptureSelection = nil
            latestScreenCaptureImage = nil
            screenCaptureBaseProcessedCount = 0
            screenCaptureBaseSkippedCount = 0
            appendRecordingSessionEvent(.recordingCanceled, sessionID: session.id)
            await clearActiveRecordingWarnings()
            silenceStatus = SilenceStatusSnapshot()

            await audioService.cancelRecording()

            progress = nil
            state = .idle
            captureState = .ready
            resetSessionVocabularyOverride()
        }
    }

    private enum StopRecordingTrigger {
        case manual
        case silenceAutoStop
        case screenContextAutoStop
    }

    private func stopRecordingIfAllowed(trigger: StopRecordingTrigger = .manual) {
        guard case .recording(let session) = state else { return }
        guard captureState == .recording else { return }

        let stoppedAt = Date()
        captureState = .stopping

        Task {
            do {
                if trigger == .manual {
                    appendRecordingSessionEvent(.manualStop, sessionID: session.id)
                }
                let result = try await audioService.stopRecording()
                await stopSilenceMonitoring()
                _ = await stopScreenContextCaptureAndAppend()
                activeVisionBindingStore.set(nil)
                await stopAudioLevelMonitoring()
                resetAudioLevelSamples()
                await clearActiveRecordingWarnings()
                silenceStatus = SilenceStatusSnapshot()

                let context = try await makePipelineContext(
                    audioTempURL: result.wavURL,
                    audioDurationSeconds: result.duration,
                    startedAt: session.startedAt,
                    stoppedAt: stoppedAt,
                    screenContextEvents: screenContextEvents
                )

                let accepted = await processingOrchestrator.enqueue(meetingID: session.id, context: context)

                screenCaptureSelection = nil
                screenContextEvents = []

                if accepted {
                    state = .idle
                    resetSessionVocabularyOverride()
                } else {
                    state = .recorded(
                        audioTempURL: result.wavURL,
                        durationSeconds: result.duration,
                        startedAt: session.startedAt,
                        stoppedAt: stoppedAt
                    )
                }
                captureState = .ready
            } catch let minuteError as MinuteError {
                await stopAudioLevelMonitoring()
                await screenContextCaptureService.cancelCapture()
                await stopSilenceMonitoring()
                activeVisionBindingStore.set(nil)
                screenInferenceStatus = nil
                screenContextEvents = []
                screenCaptureSelection = nil
                screenCaptureBaseProcessedCount = 0
                screenCaptureBaseSkippedCount = 0
                await clearActiveRecordingWarnings()
                silenceStatus = SilenceStatusSnapshot()
                state = .failed(error: minuteError, debugOutput: minuteError.debugSummary)
                captureState = .ready
            } catch {
                await stopAudioLevelMonitoring()
                await screenContextCaptureService.cancelCapture()
                await stopSilenceMonitoring()
                activeVisionBindingStore.set(nil)
                screenInferenceStatus = nil
                screenContextEvents = []
                screenCaptureSelection = nil
                screenCaptureBaseProcessedCount = 0
                screenCaptureBaseSkippedCount = 0
                await clearActiveRecordingWarnings()
                silenceStatus = SilenceStatusSnapshot()
                state = .failed(error: .audioExportFailed, debugOutput: ErrorHandler.debugMessage(for: error))
                captureState = .ready
            }
        }
    }

    private func importFileIfAllowed(_ url: URL) {
        guard state.canImportMedia else { return }

        processingTask?.cancel()
        let isVideoImport = isVideoImportURL(url)
        progress = 0.05
        statusLabelOverride = isVideoImport ? "Converting Video to Audio" : "Importing Audio"
        summarizationProgressDetail = nil
        screenContextEvents = []
        screenInferenceStatus = nil
        screenCaptureBaseProcessedCount = 0
        screenCaptureBaseSkippedCount = 0
        state = .importing(sourceURL: url)

        processingTask = Task(priority: .utility) { [weak self] in
            guard let self else { return }
            do {
                let result = try await mediaImportService.importMedia(from: url)
                if screenContextSettingsStore.isVideoImportEnabled, isVideoImport {
                    let visionAvailability = (try? await visionAvailabilityProvider()) ?? CapabilityAvailabilityState(
                        capabilityID: .vision,
                        providerID: .ollama,
                        isReady: false,
                        status: .daemonUnavailable,
                        message: "Ollama is unavailable. Start the local daemon and refresh."
                    )
                    progress = 0.3
                    statusLabelOverride = "Analyzing Video"
                    if visionAvailability.isReady {
                        activeVisionBindingStore.set(try resolveVisionBinding())
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
                            logger.info("Screen context extraction returned nil for imported video \(url.lastPathComponent, privacy: .private(mask: .hash))")
                            screenInferenceStatus = nil
                        }
                    } else {
                        logger.info("Skipping video screen context: \(visionAvailability.message ?? "vision configuration unavailable", privacy: .private(mask: .hash))")
                        screenInferenceStatus = nil
                    }
                    activeVisionBindingStore.set(nil)
                }
                try Task.checkCancellation()
                let startedAt = result.suggestedStartDate
                let stoppedAt = startedAt.addingTimeInterval(result.duration)
                progress = nil
                statusLabelOverride = nil
                state = .recorded(
                    audioTempURL: result.wavURL,
                    durationSeconds: result.duration,
                    startedAt: startedAt,
                    stoppedAt: stoppedAt
                )
            } catch is CancellationError {
                activeVisionBindingStore.set(nil)
                progress = nil
                statusLabelOverride = nil
                screenInferenceStatus = nil
                screenContextEvents = []
                screenCaptureBaseProcessedCount = 0
                screenCaptureBaseSkippedCount = 0
                state = .idle
            } catch let minuteError as MinuteError {
                activeVisionBindingStore.set(nil)
                progress = nil
                statusLabelOverride = nil
                screenInferenceStatus = nil
                screenContextEvents = []
                screenCaptureBaseProcessedCount = 0
                screenCaptureBaseSkippedCount = 0
                state = .failed(error: minuteError, debugOutput: minuteError.debugSummary)
            } catch {
                activeVisionBindingStore.set(nil)
                progress = nil
                statusLabelOverride = nil
                screenInferenceStatus = nil
                screenContextEvents = []
                screenCaptureBaseProcessedCount = 0
                screenCaptureBaseSkippedCount = 0
                state = .failed(error: .audioExportFailed, debugOutput: ErrorHandler.debugMessage(for: error))
            }
        }
    }

    private func processIfAllowed() {
        guard !isPreparingPipelineContext else { return }
        guard case .recorded(let audioTempURL, let durationSeconds, let startedAt, let stoppedAt) = state else { return }

        isPreparingPipelineContext = true

        Task { [weak self] in
            guard let self else { return }
            defer { self.isPreparingPipelineContext = false }

            // Snapshot vault configuration.
            let context: PipelineContext
            do {
                context = try await makePipelineContext(
                    audioTempURL: audioTempURL,
                    audioDurationSeconds: durationSeconds,
                    startedAt: startedAt,
                    stoppedAt: stoppedAt,
                    screenContextEvents: screenContextEvents
                )
            } catch let minuteError as MinuteError {
                state = .failed(error: minuteError, debugOutput: minuteError.debugSummary)
                return
            } catch {
                state = .failed(error: .vaultUnavailable, debugOutput: ErrorHandler.debugMessage(for: error))
                return
            }

            // One active task at a time.
            processingTask?.cancel()
            progress = 0
            state = .processing(stage: .downloadingModels, context: context)

            processingTask = Task(priority: .utility) { [weak self] in
                guard let self else { return }
                await self.runPipeline(context: context)
            }
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
        activeVisionBindingStore.set(nil)
        screenContextAutoStopTask?.cancel()
        screenContextAutoStopTask = nil
        activeSilenceAlert = nil
        activeScreenContextAlert = nil
        silenceStatus = SilenceStatusSnapshot()
        selectedMeetingTypeID = AppConfiguration.Defaults.defaultStageMeetingTypeID
        meetingType = .autodetect
        resetSessionVocabularyOverride()
        Task { @MainActor [recordingAlertNotifier] in
            await recordingAlertNotifier.clearSilenceStopWarning()
            await recordingAlertNotifier.clearSharedWindowClosedWarning()
        }
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

    private func startSilenceMonitoring(for session: RecordingSession) async {
        let controller = SilenceAutoStopController(
            policy: silenceDetectionPolicy,
            onEvent: { [weak self] event in
                Task { @MainActor [weak self] in
                    await self?.handleSilenceEvent(event)
                }
            }
        )
        silenceController = controller
        await controller.start(sessionID: session.id, startedAt: session.startedAt)
    }

    private func stopSilenceMonitoring() async {
        guard let silenceController else { return }
        await silenceController.stop()
        self.silenceController = nil
    }

    private func clearScreenContextAutoStopWarning(logKeepSelection: Bool = false) async {
        screenContextAutoStopTask?.cancel()
        screenContextAutoStopTask = nil

        let alertToClear = activeScreenContextAlert

        if logKeepSelection, let alert = alertToClear {
            appendRecordingSessionEvent(
                .keepRecordingSelected,
                metadata: ["source": "screen_window_closed"],
                sessionID: alert.sessionID
            )
        }

        activeScreenContextAlert = nil
        switch alertToClear?.type {
        case .screenContextConfigurationFailure:
            await recordingAlertNotifier.clearScreenContextConfigurationFailure()
        case .screenWindowClosed, .screenWindowClosedStopWarning:
            await recordingAlertNotifier.clearSharedWindowClosedWarning()
        case nil, .silenceStopWarning:
            break
        }
    }

    private func clearActiveRecordingWarnings() async {
        activeSilenceAlert = nil
        await recordingAlertNotifier.clearSilenceStopWarning()
        await clearScreenContextAutoStopWarning()
    }

    private func presentScreenContextConfigurationAlert(sessionID: UUID, message: String) async {
        let alert = RecordingAlert(
            type: .screenContextConfigurationFailure,
            sessionID: sessionID,
            message: message,
            actions: [.acknowledge]
        )
        activeScreenContextAlert = alert
        appendRecordingSessionEvent(.screenContextConfigurationNotified, sessionID: sessionID)
        _ = await recordingAlertNotifier.notifyScreenContextConfigurationFailure(alert: alert)
    }

    private func beginScreenContextAutoStopWarning(session: RecordingSession, windowTitle: String) {
        guard activeScreenContextAlert == nil else { return }

        let warningSeconds = Int(silenceDetectionPolicy.warningCountdownSeconds)
        let now = Date()
        let expiresAt = now.addingTimeInterval(silenceDetectionPolicy.warningCountdownSeconds)
        let alert = RecordingAlert(
            type: .screenWindowClosedStopWarning,
            sessionID: session.id,
            message: "Shared window closed: \(windowTitle). Recording will stop in \(warningSeconds) seconds unless you keep recording.",
            issuedAt: now,
            expiresAt: expiresAt,
            actions: [.keepRecording]
        )

        activeScreenContextAlert = alert
        appendRecordingSessionEvent(
            .screenWindowClosedNotified,
            metadata: [
                "window_title": windowTitle,
                "countdown_seconds": "\(warningSeconds)",
                "stop_pending": "true"
            ],
            sessionID: session.id
        )

        screenContextAutoStopTask?.cancel()
        let countdownNanoseconds = UInt64(max(silenceDetectionPolicy.warningCountdownSeconds, 0) * 1_000_000_000)
        screenContextAutoStopTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: countdownNanoseconds)
            guard !Task.isCancelled else { return }
            await self?.triggerScreenContextAutoStopIfNeeded(alertID: alert.id, sessionID: session.id)
        }

        Task { @MainActor [recordingAlertNotifier] in
            _ = await recordingAlertNotifier.notifySharedWindowClosed(alert: alert)
        }
    }

    private func triggerScreenContextAutoStopIfNeeded(alertID: UUID, sessionID: UUID) async {
        guard case .recording(let currentSession) = state, currentSession.id == sessionID else { return }
        guard activeScreenContextAlert?.id == alertID else { return }

        appendRecordingSessionEvent(
            .autoStopExecuted,
            metadata: ["source": "screen_window_closed"],
            sessionID: sessionID
        )

        await clearScreenContextAutoStopWarning()
        stopRecordingIfAllowed(trigger: .screenContextAutoStop)
    }

    private func handleSilenceEvent(_ event: SilenceAutoStopEvent) async {
        switch event {
        case .statusChanged(let snapshot):
            silenceStatus = snapshot
        case .warningStarted(let alert):
            activeSilenceAlert = alert
            appendRecordingSessionEvent(
                .silenceWarningIssued,
                metadata: ["countdown_seconds": "\(Int(silenceDetectionPolicy.warningCountdownSeconds))"],
                sessionID: alert.sessionID
            )
            _ = await recordingAlertNotifier.notifySilenceStopWarning(alert: alert)
        case .warningCanceledBySpeech:
            if let sessionID = silenceStatus.sessionID {
                appendRecordingSessionEvent(.warningCanceledBySpeech, sessionID: sessionID)
            }
            activeSilenceAlert = nil
            await recordingAlertNotifier.clearSilenceStopWarning()
        case .warningCanceledByUser:
            if let sessionID = silenceStatus.sessionID {
                appendRecordingSessionEvent(
                    .keepRecordingSelected,
                    metadata: ["source": "silence"],
                    sessionID: sessionID
                )
            }
            activeSilenceAlert = nil
            await recordingAlertNotifier.clearSilenceStopWarning()
        case .autoStopTriggered:
            if let sessionID = silenceStatus.sessionID {
                appendRecordingSessionEvent(
                    .autoStopExecuted,
                    metadata: ["source": "silence"],
                    sessionID: sessionID
                )
            }
            activeSilenceAlert = nil
            await recordingAlertNotifier.clearSilenceStopWarning()
            stopRecordingIfAllowed(trigger: .silenceAutoStop)
        }
    }

    private func appendRecordingSessionEvent(
        _ eventType: RecordingSessionEventType,
        metadata: [String: String] = [:],
        sessionID: UUID? = nil
    ) {
        let resolvedSessionID = sessionID ?? currentRecordingSessionID ?? silenceStatus.sessionID
        guard let resolvedSessionID else { return }

        recordingSessionEvents.append(
            RecordingSessionEvent(
                sessionID: resolvedSessionID,
                eventType: eventType,
                metadata: metadata
            )
        )
    }

    private var currentRecordingSessionID: UUID? {
        if case .recording(let session) = state {
            return session.id
        }
        return silenceStatus.sessionID
    }

    func keepRecordingFromWarning() {
        Task { [silenceController] in
            await silenceController?.keepRecording()
        }
        Task { @MainActor [weak self] in
            await self?.clearScreenContextAutoStopWarning(logKeepSelection: true)
        }
    }

    func acknowledgeActiveScreenContextAlert() {
        guard let alertID = activeScreenContextAlert?.id else { return }
        _ = acknowledgeAlert(alertID: alertID)
    }

    @discardableResult
    func acknowledgeAlert(alertID: UUID) -> Bool {
        if activeScreenContextAlert?.id == alertID {
            activeScreenContextAlert?.status = .resolved
            screenContextAutoStopTask?.cancel()
            screenContextAutoStopTask = nil
            activeScreenContextAlert = nil
            Task { @MainActor [recordingAlertNotifier] in
                await recordingAlertNotifier.clearSharedWindowClosedWarning()
            }
            return true
        }
        return false
    }

    func currentSilenceStatusSnapshot() -> SilenceStatusSnapshot {
        silenceStatus
    }

    func sessionEvents(for sessionID: UUID) -> [RecordingSessionEvent] {
        recordingSessionEvents.filter { $0.sessionID == sessionID }
    }

    private func handleScreenContextLifecycleEvent(_ event: ScreenContextLifecycleEvent) {
        guard case .recording(let session) = state else { return }
        guard event.type == .sharedWindowClosed else { return }
        beginScreenContextAutoStopWarning(session: session, windowTitle: event.windowTitle)
    }

    func _testHandleScreenContextLifecycleEvent(_ event: ScreenContextLifecycleEvent) {
        handleScreenContextLifecycleEvent(event)
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
                },
                lifecycleEventHandler: { [weak self] lifecycleEvent in
                    Task { @MainActor [weak self] in
                        self?.handleScreenContextLifecycleEvent(lifecycleEvent)
                    }
                }
            )
        } catch {
            logger.error("Screen context capture failed: \(ErrorHandler.debugMessage(for: error), privacy: .private(mask: .hash))")
        }
    }

    private func startScreenContextCapture(
        selection: ScreenContextWindowSelection,
        offsetSeconds: TimeInterval
    ) async {
        _ = await stopScreenContextCaptureAndAppend()
        await clearScreenContextAutoStopWarning()
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
            let snapshots = await orchestrator.snapshots()

            for await snapshot in snapshots {
                if Task.isCancelled {
                    break
                }

                if case let .completed(noteURL, _) = snapshot.lastOutcome {
                    lastCompletedNoteURL = noteURL
                }

                await MainActor.run {
                    if self.backgroundProcessingSnapshot != snapshot {
                        self.backgroundProcessingSnapshot = snapshot
                    }
                    if self.lastBackgroundProcessedNoteURL != lastCompletedNoteURL {
                        self.lastBackgroundProcessedNoteURL = lastCompletedNoteURL
                    }
                    if snapshot.activeMeetingID != nil {
                        self.summarizationProgressDetail = self.makeSummarizationProgressDetail(snapshot.activeSummarizationStatus)
                    } else if case .idle = self.state {
                        self.summarizationProgressDetail = nil
                    }
                }
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
            logger.error("Video screen context failed: \(ErrorHandler.debugMessage(for: error), privacy: .private(mask: .hash))")
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
            statusLabelOverride = nil
            summarizationProgressDetail = nil
            state = .done(noteURL: outputs.noteURL, audioURL: outputs.audioURL)
        } catch is CancellationError {
            progress = nil
            statusLabelOverride = nil
            summarizationProgressDetail = nil

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
            statusLabelOverride = nil
            summarizationProgressDetail = nil
            state = .failed(error: minuteError, debugOutput: minuteError.debugSummary)
        } catch {
            progress = nil
            statusLabelOverride = nil
            summarizationProgressDetail = nil
            state = .failed(error: .vaultWriteFailed, debugOutput: ErrorHandler.debugMessage(for: error))
        }
    }

    private func applyPipelineProgress(_ update: PipelineProgress, context: PipelineContext) {
        progress = min(max(update.fractionCompleted, 0), 1)
        statusLabelOverride = nil

        switch update.stage {
        case .downloadingModels:
            summarizationProgressDetail = nil
            state = .processing(stage: .downloadingModels, context: context)
        case .normalizingAudioLevels:
            summarizationProgressDetail = nil
            state = .processing(stage: .normalizingAudioLevels, context: context)
        case .transcribing:
            summarizationProgressDetail = nil
            state = .processing(stage: .transcribing, context: context)
        case .summarizing:
            summarizationProgressDetail = makeSummarizationProgressDetail(update)
            state = .processing(stage: .summarizing, context: context)
        case .writing:
            summarizationProgressDetail = nil
            guard let extraction = update.extraction else { return }
            state = .writing(context: context, extraction: extraction)
        }
    }

    private func makeSummarizationProgressDetail(_ update: PipelineProgress) -> String? {
        makeSummarizationProgressDetail(
            estimatedPassCount: update.estimatedPassCount,
            currentPassIndex: update.currentPassIndex,
            totalPassCount: update.totalPassCount,
            resumedFromPassIndex: update.resumedFromPassIndex
        )
    }

    private func makeSummarizationProgressDetail(_ status: ActiveSummarizationStatus?) -> String? {
        guard let status else { return nil }
        return makeSummarizationProgressDetail(
            estimatedPassCount: status.estimatedPassCount,
            currentPassIndex: status.currentPassIndex,
            totalPassCount: status.totalPassCount,
            resumedFromPassIndex: status.resumedFromPassIndex
        )
    }

    private func makeSummarizationProgressDetail(
        estimatedPassCount: Int?,
        currentPassIndex: Int?,
        totalPassCount: Int?,
        resumedFromPassIndex: Int?
    ) -> String? {
        Self.formatSummarizationProgressDetail(
            estimatedPassCount: estimatedPassCount,
            currentPassIndex: currentPassIndex,
            totalPassCount: totalPassCount,
            resumedFromPassIndex: resumedFromPassIndex
        )
    }

    static func formatSummarizationProgressDetail(
        estimatedPassCount: Int?,
        currentPassIndex: Int?,
        totalPassCount: Int?,
        resumedFromPassIndex: Int?
    ) -> String? {
        var segments: [String] = []
        if let resumedFromPassIndex, resumedFromPassIndex > 1 {
            segments.append("Resuming from pass \(resumedFromPassIndex)")
        }
        if let estimate = estimatedPassCount, estimate > 1 {
            segments.append("Estimated passes: \(estimate)")
        }
        if let current = currentPassIndex,
           let total = totalPassCount,
           total > 0,
           current > 0 {
            segments.append("Pass \(current) of \(total)")
        }
        guard !segments.isEmpty else { return nil }
        return segments.joined(separator: " • ")
    }

    private func makePipelineContext(
        audioTempURL: URL,
        audioDurationSeconds: TimeInterval,
        startedAt: Date,
        stoppedAt: Date,
        screenContextEvents: [ScreenContextEvent]
    ) async throws -> PipelineContext {
        refreshMeetingTypeOptions()
        let configuration = AppConfiguration()

        // Validate vault selection.
        do {
            _ = try await vaultAccess.resolveVaultRootURL(timeout: .seconds(2))
        } catch {
            throw MinuteError.vaultUnavailable
        }

        let workingDirectoryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("minute-work-\(UUID().uuidString)", isDirectory: true)

        let effectiveOutputLanguage: OutputLanguage
        switch languageProcessing {
        case .autoToEnglish:
            effectiveOutputLanguage = .englishUS
        case .autoPreserve:
            effectiveOutputLanguage = outputLanguage
        }

        let globalVocabularySettings = vocabularySettingsStore.load()
        syncSessionVocabularyModeWithCurrentInput(using: globalVocabularySettings)
        let vocabularyResolution = sessionVocabularyResolver.resolve(
            globalSettings: globalVocabularySettings,
            sessionMode: sessionVocabularyMode,
            sessionCustomInput: sessionCustomVocabularyInput,
            readiness: sessionVocabularyReadiness
        )
        sessionVocabularyMode = vocabularyResolution.effectiveMode
        if vocabularyResolution.warningMessage != nil {
            sessionVocabularyWarningMessage = vocabularyResolution.warningMessage
        }

        let availableTypeIDs = Set(meetingTypeOptions.map(\.typeId))
        let resolvedTypeID = selectedMeetingTypeID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard availableTypeIDs.contains(resolvedTypeID) else {
            throw MinuteError.invalidMeetingTypeSelection
        }
        let selectionMode: MeetingTypeSelectionMode = resolvedTypeID == MeetingType.autodetect.rawValue
            ? .autodetect
            : .manual
        let fallbackMeetingType = MeetingType(rawValue: resolvedTypeID) ?? .general

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
            transcriptionVocabulary: vocabularyResolution.transcriptionVocabulary,
            summarizationBinding: try resolveSummarizationBinding(),
            meetingTypeSelection: MeetingTypeSelection(
                selectionMode: selectionMode,
                selectedTypeId: resolvedTypeID
            ),
            meetingType: fallbackMeetingType,
            languageProcessing: languageProcessing,
            outputLanguage: effectiveOutputLanguage,
            knownSpeakerSuggestionsEnabled: configuration.knownSpeakerSuggestionsEnabled
        )
    }

    private func resolveSessionVocabularyReadiness() async -> VocabularyReadinessStatus {
        let backend = transcriptionBackendStore.selectedBackend()
        guard backend == .fluidAudio else {
            return .unsupported(backend: backend)
        }

        do {
            let validation = try await modelValidationProvider()
            let vocabularyModelIDs = (validation.missingModelIDs + validation.invalidModelIDs).filter {
                $0.hasSuffix("-ctc-vocab")
            }
            if !vocabularyModelIDs.isEmpty {
                return .missingModels(
                    backend: backend,
                    message: "Vocabulary models missing. Recording will continue without boosting."
                )
            }
            return .ready(backend: backend)
        } catch {
            return .missingModels(
                backend: backend,
                message: "Vocabulary model status unavailable. Recording will continue without boosting."
            )
        }
    }

    private func resetSessionVocabularyOverride() {
        sessionCustomVocabularyInput = ""
        sessionVocabularyWarningMessage = nil
        sessionVocabularyReadiness = .unsupported(backend: transcriptionBackend)
        syncSessionVocabularyModeWithCurrentInput()
    }

    private func syncSessionVocabularyModeWithCurrentInput(
        using settings: GlobalVocabularyBoostingSettings? = nil
    ) {
        let resolvedSettings = settings ?? vocabularySettingsStore.load()
        let hasCustomTerms = !VocabularyTermEntry.parseFromEditorInput(
            sessionCustomVocabularyInput,
            source: .sessionCustom
        ).isEmpty

        guard transcriptionBackend == .fluidAudio, resolvedSettings.enabled else {
            sessionVocabularyMode = .off
            return
        }

        sessionVocabularyMode = hasCustomTerms ? .custom : .default
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
        // Keep quiet microphone signal visible without affecting silence auto-stop logic.
        let visualTarget = min(max(powf(clamped, 0.55), 0), 1)
        let previous = Float(audioLevelSamples.last ?? 0)
        let smoothing: Float = visualTarget > previous ? 0.55 : 0.22
        let smoothed = previous + (visualTarget - previous) * smoothing
        audioLevelSamples.removeFirst()
        audioLevelSamples.append(CGFloat(smoothed))

        if case .recording = state {
            let silenceController = silenceController
            Task {
                await silenceController?.ingest(level: clamped, at: Date())
            }
        }
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



    // MARK: - Workspace continuity

    func workspaceContinuitySnapshot() -> WorkspaceContinuitySnapshot {
        WorkspaceContinuitySnapshot(
            isRecordingActive: captureState == .recording,
            pipelineStage: currentStatusLabel,
            activeSessionID: currentSessionID,
            unsavedWorkPresent: hasActiveSessionContext
        )
    }

    func workspaceDidBecomeVisible() {
        refreshVaultStatus()
    }

    private var currentSessionID: String? {
        switch state {
        case .recording(let session):
            return session.id.uuidString
        default:
            return nil
        }
    }

    private var hasActiveSessionContext: Bool {
        switch state {
        case .recording, .recorded, .processing, .writing:
            return true
        case .done, .failed, .idle, .importing:
            return false
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

final class ResilientWhisperTranscriptionService: TranscriptionServicing, @unchecked Sendable {
    private static let xpcOptInEnvironmentKey = "MINUTE_ENABLE_WHISPER_XPC"

    private let primary: any TranscriptionServicing
    private let fallback: any TranscriptionServicing
    private let stateLock = NSLock()
    private var primaryDisabled: Bool
    private let logger = Logger(subsystem: "roblibob.Minute", category: "whisper-resilience")

    init(
        primary: any TranscriptionServicing,
        fallback: any TranscriptionServicing,
        primaryEnabled: Bool = true
    ) {
        self.primary = primary
        self.fallback = fallback
        self.primaryDisabled = !primaryEnabled
    }

    static func liveDefault() -> ResilientWhisperTranscriptionService {
        let inProcess = WhisperLibraryTranscriptionService.liveDefault()
#if DEBUG
        let xpcOptInEnabled = ProcessInfo.processInfo.environment[Self.xpcOptInEnvironmentKey] == "1"
        if xpcOptInEnabled {
            return ResilientWhisperTranscriptionService(
                primary: WhisperXPCTranscriptionService.liveDefault(),
                fallback: inProcess,
                primaryEnabled: true
            )
        }
#endif
        return ResilientWhisperTranscriptionService(primary: inProcess, fallback: inProcess, primaryEnabled: false)
    }

    func transcribe(wavURL: URL) async throws -> TranscriptionResult {
        if isPrimaryDisabled() {
            return try await fallback.transcribe(wavURL: wavURL)
        }

        do {
            return try await primary.transcribe(wavURL: wavURL)
        } catch {
            guard shouldFallbackToInProcessWhisper(for: error) else {
                throw error
            }

            disablePrimary()
            logger.error("Whisper XPC failed; retrying in-process whisper. reason=\(ErrorHandler.debugMessage(for: error), privacy: .public)")
            return try await fallback.transcribe(wavURL: wavURL)
        }
    }

    private func isPrimaryDisabled() -> Bool {
        stateLock.lock()
        defer { stateLock.unlock() }
        return primaryDisabled
    }

    private func disablePrimary() {
        stateLock.lock()
        if primaryDisabled {
            stateLock.unlock()
            return
        }
        primaryDisabled = true
        stateLock.unlock()
    }

    private func shouldFallbackToInProcessWhisper(for error: Error) -> Bool {
        if let minuteError = error as? MinuteError {
            switch minuteError {
            case .whisperMissing:
                return true
            case .whisperFailed(let exitCode, let output):
                guard exitCode == -1 else { return false }
                let normalized = output.lowercased()
                if normalized.isEmpty {
                    return true
                }
                if normalized.contains("code=257")
                    || normalized.contains("code=260")
                    || normalized.contains("operation not permitted")
                    || normalized.contains("no such file or directory")
                    || normalized.contains("don’t have permission")
                    || normalized.contains("don't have permission")
                    || normalized.contains("permission to view it")
                    || normalized.contains("nscocoaerrordomain")
                    || normalized.contains("nsposixerrordomain")
                    || normalized.contains("xpc")
                    || normalized.contains("inherited sandbox")
                    || normalized.contains("unable to obtain a task name port right") {
                    return true
                }
                return true
            default:
                break
            }
        }

        let nsError = error as NSError
        if nsError.domain == NSCocoaErrorDomain && nsError.code == NSFileReadNoPermissionError {
            return true
        }

        if nsError.domain == NSPOSIXErrorDomain && nsError.code == 1 {
            return true
        }

        if nsError.domain == NSPOSIXErrorDomain && nsError.code == 2 {
            return true
        }

        if nsError.domain == "NSXPCConnectionErrorDomain" {
            return true
        }

        return false
    }
}
