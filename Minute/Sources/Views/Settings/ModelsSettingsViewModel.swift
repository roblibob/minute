import Combine
import Foundation
import MinuteCore
import MinuteLMStudio
import MinuteOllama

@MainActor
final class ModelsSettingsViewModel: ObservableObject {
    typealias State = ModelSetupLifecycleController.State

    @Published private(set) var state: State = .checking
    @Published private(set) var summarizationAvailabilityState = CapabilityAvailabilityState(
        capabilityID: .summarization,
        providerID: .builtIn,
        isReady: true,
        status: .ready
    )
    @Published private(set) var visionAvailabilityState = CapabilityAvailabilityState(
        capabilityID: .vision,
        providerID: .builtIn,
        isReady: true,
        status: .ready
    )
    @Published private(set) var ollamaDiscoverySnapshot: OllamaDiscoverySnapshot? = nil
    @Published private(set) var lmStudioDiscoverySnapshot: LMStudioDiscoverySnapshot? = nil
    @Published private(set) var isRefreshingAvailability = false
    @Published var selectedSummarizationProviderID: String {
        didSet {
            guard oldValue != selectedSummarizationProviderID else { return }
            let provider = InferenceProvider(rawValue: selectedSummarizationProviderID) ?? .builtIn
            inferenceProviderStore.setSelectedProvider(provider, for: .summarization)
            refresh()
        }
    }
    @Published var selectedSummarizationModelID: String {
        didSet {
            guard oldValue != selectedSummarizationModelID else { return }
            summarizationModelStore.setSelectedModelID(selectedSummarizationModelID)
            refresh()
        }
    }
    @Published var selectedSummarizationOllamaModelTag: String {
        didSet {
            guard oldValue != selectedSummarizationOllamaModelTag else { return }
            inferenceProviderStore.setSelectedOllamaModelTag(selectedSummarizationOllamaModelTag, for: .summarization)
            refreshAvailability()
        }
    }
    @Published var selectedSummarizationLMStudioModelIdentifier: String {
        didSet {
            guard oldValue != selectedSummarizationLMStudioModelIdentifier else { return }
            inferenceProviderStore.setSelectedLMStudioModelIdentifier(
                selectedSummarizationLMStudioModelIdentifier,
                for: .summarization
            )
            refreshAvailability()
        }
    }
    @Published var selectedOllamaBaseURLString: String {
        didSet {
            guard oldValue != selectedOllamaBaseURLString else { return }
            connectionStore.setSelectedBaseURLString(selectedOllamaBaseURLString, for: .ollama)
            refreshAvailability()
        }
    }
    @Published var selectedLMStudioBaseURLString: String {
        didSet {
            guard oldValue != selectedLMStudioBaseURLString else { return }
            connectionStore.setSelectedBaseURLString(selectedLMStudioBaseURLString, for: .lmStudio)
            refreshAvailability()
        }
    }
    @Published var selectedSummarizationContextWindowPreset: SummarizationContextWindowPreset {
        didSet {
            guard oldValue != selectedSummarizationContextWindowPreset else { return }
            summarizationContextWindowStore.setSelectedPreset(selectedSummarizationContextWindowPreset)
        }
    }
    @Published var selectedVisionProviderID: String {
        didSet {
            guard oldValue != selectedVisionProviderID else { return }
            let provider = InferenceProvider(rawValue: selectedVisionProviderID) ?? .builtIn
            inferenceProviderStore.setSelectedProvider(provider, for: .vision)
            refresh()
        }
    }
    @Published var selectedVisionModelID: String {
        didSet {
            guard oldValue != selectedVisionModelID else { return }
            visionModelStore.setSelectedModelID(selectedVisionModelID)
            refresh()
        }
    }
    @Published var selectedVisionOllamaModelTag: String {
        didSet {
            guard oldValue != selectedVisionOllamaModelTag else { return }
            inferenceProviderStore.setSelectedOllamaModelTag(selectedVisionOllamaModelTag, for: .vision)
            refreshAvailability()
        }
    }
    @Published var selectedVisionLMStudioModelIdentifier: String {
        didSet {
            guard oldValue != selectedVisionLMStudioModelIdentifier else { return }
            inferenceProviderStore.setSelectedLMStudioModelIdentifier(
                selectedVisionLMStudioModelIdentifier,
                for: .vision
            )
            refreshAvailability()
        }
    }
    @Published var selectedTranscriptionBackendID: String {
        didSet {
            guard oldValue != selectedTranscriptionBackendID else { return }
            transcriptionBackendStore.setSelectedBackendID(selectedTranscriptionBackendID)
            refresh()
        }
    }
    @Published var selectedTranscriptionModelID: String {
        didSet {
            guard oldValue != selectedTranscriptionModelID else { return }
            transcriptionModelStore.setSelectedModelID(selectedTranscriptionModelID)
            refresh()
        }
    }
    @Published var selectedFluidAudioModelID: String {
        didSet {
            guard oldValue != selectedFluidAudioModelID else { return }
            fluidAudioModelStore.setSelectedModelID(selectedFluidAudioModelID)
            refresh()
        }
    }
    @Published var vocabularyBoostingEnabled: Bool {
        didSet {
            guard oldValue != vocabularyBoostingEnabled else { return }
            persistVocabularySettings()
        }
    }
    @Published var vocabularyBoostingTermsInput: String {
        didSet {
            guard oldValue != vocabularyBoostingTermsInput else { return }
            persistVocabularySettings()
        }
    }
    @Published var vocabularyBoostingStrength: VocabularyBoostingStrength {
        didSet {
            guard oldValue != vocabularyBoostingStrength else { return }
            persistVocabularySettings()
        }
    }
    @Published var selectedTranscriptionLanguage: TranscriptionLanguage {
        didSet {
            guard oldValue != selectedTranscriptionLanguage else { return }
            transcriptionLanguageStore.setSelectedLanguage(selectedTranscriptionLanguage)
        }
    }

    private let vocabularySettingsStore: any VocabularyBoostingSettingsStoring
    private let inferenceProviderStore: InferenceProviderSelectionStore
    private let connectionStore: ProviderConnectionSettingsStore
    private let summarizationModelStore: SummarizationModelSelectionStore
    private let summarizationContextWindowStore: SummarizationContextWindowSelectionStore
    private let visionModelStore: VisionModelSelectionStore
    private let transcriptionModelStore: TranscriptionModelSelectionStore
    private let transcriptionBackendStore: TranscriptionBackendSelectionStore
    private let fluidAudioModelStore: FluidAudioASRModelSelectionStore
    private let transcriptionLanguageStore: TranscriptionLanguageSelectionStore
    private let modelLifecycleController: ModelSetupLifecycleController
    private let availabilityProvider: any CapabilityAvailabilityProviding
    private let usesCustomAvailabilityProvider: Bool
    private let providedOllamaModelDiscoverer: (any OllamaModelDiscovering)?
    private let providedLMStudioModelDiscoverer: (any LMStudioModelDiscovering)?
    private var cancellables: Set<AnyCancellable> = []
    private var isRestoringVocabularySettings = false
    private var lastModelValidation = ModelValidationResult(missingModelIDs: [], invalidModelIDs: [])
    private var availabilityTask: Task<Void, Never>?

    init(
        modelManager: (any ModelManaging)? = nil,
        inferenceProviderStore: InferenceProviderSelectionStore = InferenceProviderSelectionStore(),
        connectionStore: ProviderConnectionSettingsStore = ProviderConnectionSettingsStore(),
        summarizationModelStore: SummarizationModelSelectionStore = SummarizationModelSelectionStore(),
        summarizationContextWindowStore: SummarizationContextWindowSelectionStore = SummarizationContextWindowSelectionStore(),
        visionModelStore: VisionModelSelectionStore = VisionModelSelectionStore(),
        transcriptionModelStore: TranscriptionModelSelectionStore = TranscriptionModelSelectionStore(),
        transcriptionBackendStore: TranscriptionBackendSelectionStore = TranscriptionBackendSelectionStore(),
        fluidAudioModelStore: FluidAudioASRModelSelectionStore = FluidAudioASRModelSelectionStore(),
        transcriptionLanguageStore: TranscriptionLanguageSelectionStore = TranscriptionLanguageSelectionStore(),
        availabilityProvider: (any CapabilityAvailabilityProviding)? = nil,
        ollamaModelDiscoverer: (any OllamaModelDiscovering)? = nil,
        lmStudioModelDiscoverer: (any LMStudioModelDiscovering)? = nil,
        vocabularySettingsStore: (any VocabularyBoostingSettingsStoring)? = nil
    ) {
        self.inferenceProviderStore = inferenceProviderStore
        self.connectionStore = connectionStore
        self.summarizationModelStore = summarizationModelStore
        self.summarizationContextWindowStore = summarizationContextWindowStore
        self.visionModelStore = visionModelStore
        self.transcriptionModelStore = transcriptionModelStore
        self.transcriptionBackendStore = transcriptionBackendStore
        self.fluidAudioModelStore = fluidAudioModelStore
        self.transcriptionLanguageStore = transcriptionLanguageStore
        self.vocabularySettingsStore = vocabularySettingsStore ?? VocabularyBoostingSettingsStore()
        let resolvedModelManager = modelManager ?? DefaultModelManager(
            providerStore: inferenceProviderStore,
            selectionStore: summarizationModelStore,
            visionModelStore: visionModelStore,
            transcriptionSelectionStore: transcriptionModelStore,
            transcriptionBackendStore: transcriptionBackendStore,
            fluidAudioModelStore: fluidAudioModelStore
        )
        self.providedOllamaModelDiscoverer = ollamaModelDiscoverer
        self.providedLMStudioModelDiscoverer = lmStudioModelDiscoverer
        self.usesCustomAvailabilityProvider = availabilityProvider != nil
        self.availabilityProvider = availabilityProvider ?? InferenceRuntimeFactory(
            providerStore: inferenceProviderStore,
            connectionStore: connectionStore,
            summarizationModelStore: summarizationModelStore,
            summarizationContextWindowStore: summarizationContextWindowStore,
            visionModelStore: visionModelStore
        )
        self.modelLifecycleController = ModelSetupLifecycleController(
            modelManager: resolvedModelManager,
            displayName: Self.displayName(for:)
        )
        let selectedSummarizationProvider = inferenceProviderStore.selectedProvider(for: .summarization)
        self.selectedSummarizationProviderID = selectedSummarizationProvider.rawValue
        let selectedModel = summarizationModelStore.selectedModel()
        self.selectedSummarizationModelID = selectedModel.id
        if summarizationModelStore.selectedModelID() != selectedModel.id {
            summarizationModelStore.setSelectedModelID(selectedModel.id)
        }
        self.selectedSummarizationOllamaModelTag = inferenceProviderStore.selectedOllamaModelTag(for: .summarization) ?? ""
        self.selectedSummarizationLMStudioModelIdentifier = inferenceProviderStore.selectedLMStudioModelIdentifier(for: .summarization) ?? ""
        self.selectedOllamaBaseURLString = connectionStore.selectedBaseURLString(for: .ollama)
        self.selectedLMStudioBaseURLString = connectionStore.selectedBaseURLString(for: .lmStudio)
        self.selectedSummarizationContextWindowPreset = summarizationContextWindowStore.selectedPreset()
        let selectedVisionProvider = inferenceProviderStore.selectedProvider(for: .vision)
        self.selectedVisionProviderID = selectedVisionProvider.rawValue
        let selectedVisionModel = visionModelStore.selectedModel()
        self.selectedVisionModelID = selectedVisionModel.id
        if visionModelStore.selectedModelID() != selectedVisionModel.id {
            visionModelStore.setSelectedModelID(selectedVisionModel.id)
        }
        self.selectedVisionOllamaModelTag = inferenceProviderStore.selectedOllamaModelTag(for: .vision) ?? ""
        self.selectedVisionLMStudioModelIdentifier = inferenceProviderStore.selectedLMStudioModelIdentifier(for: .vision) ?? ""
        let selectedBackend = transcriptionBackendStore.selectedBackend()
        self.selectedTranscriptionBackendID = selectedBackend.id
        if transcriptionBackendStore.selectedBackendID() != selectedBackend.id {
            transcriptionBackendStore.setSelectedBackendID(selectedBackend.id)
        }
        let selectedTranscription = transcriptionModelStore.selectedModel()
        self.selectedTranscriptionModelID = selectedTranscription.id
        if transcriptionModelStore.selectedModelID() != selectedTranscription.id {
            transcriptionModelStore.setSelectedModelID(selectedTranscription.id)
        }
        let selectedFluidModel = fluidAudioModelStore.selectedModel()
        self.selectedFluidAudioModelID = selectedFluidModel.id
        if fluidAudioModelStore.selectedModelID() != selectedFluidModel.id {
            fluidAudioModelStore.setSelectedModelID(selectedFluidModel.id)
        }
        self.selectedTranscriptionLanguage = transcriptionLanguageStore.selectedLanguage()
        let vocabularySettings = self.vocabularySettingsStore.load()
        self.vocabularyBoostingEnabled = vocabularySettings.enabled
        self.vocabularyBoostingTermsInput = vocabularySettings.editorInput
        self.vocabularyBoostingStrength = vocabularySettings.strength
        modelLifecycleController.$state
            .receive(on: RunLoop.main)
            .sink { [weak self] state in
                self?.state = state
            }
            .store(in: &cancellables)
        modelLifecycleController.$lastValidation
            .receive(on: RunLoop.main)
            .sink { [weak self] validation in
                self?.lastModelValidation = validation
            }
            .store(in: &cancellables)
        refresh()
    }

    func refresh() {
        modelLifecycleController.refresh()
        refreshAvailability()
    }

    func startDownload() {
        modelLifecycleController.startDownload()
    }

    func refreshAvailability() {
        availabilityTask?.cancel()
        let usesOllamaForSummarization = selectedSummarizationProviderID == InferenceProvider.ollama.rawValue
        let usesOllamaForVision = selectedVisionProviderID == InferenceProvider.ollama.rawValue
        let usesLMStudioForSummarization = selectedSummarizationProviderID == InferenceProvider.lmStudio.rawValue
        let usesLMStudioForVision = selectedVisionProviderID == InferenceProvider.lmStudio.rawValue
        let shouldDiscoverOllama = usesOllamaForSummarization || usesOllamaForVision
        let shouldDiscoverLMStudio = usesLMStudioForSummarization || usesLMStudioForVision
        availabilityTask = Task { [weak self] in
            guard let self else { return }
            await MainActor.run {
                self.isRefreshingAvailability = true
            }

            async let summarization = self.availabilityState(for: .summarization)
            async let vision = self.availabilityState(for: .vision)

            let snapshot: OllamaDiscoverySnapshot?
            if shouldDiscoverOllama {
                snapshot = try? await self.discoverOllamaModels()
            } else {
                snapshot = nil
            }
            let lmStudioSnapshot: LMStudioDiscoverySnapshot?
            if shouldDiscoverLMStudio {
                lmStudioSnapshot = try? await self.discoverLMStudioModels()
            } else {
                lmStudioSnapshot = nil
            }

            do {
                let summarizationState = try await summarization
                let visionState = try await vision
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    self.summarizationAvailabilityState = summarizationState
                    self.visionAvailabilityState = visionState
                    self.ollamaDiscoverySnapshot = snapshot
                    self.lmStudioDiscoverySnapshot = lmStudioSnapshot
                    self.isRefreshingAvailability = false
                }
            } catch {
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    self.isRefreshingAvailability = false
                    if usesOllamaForSummarization {
                        self.summarizationAvailabilityState = Self.unavailableState(for: .summarization, provider: .ollama)
                    }
                    if usesOllamaForVision {
                        self.visionAvailabilityState = Self.unavailableState(for: .vision, provider: .ollama)
                    }
                    if usesLMStudioForSummarization {
                        self.summarizationAvailabilityState = Self.unavailableState(for: .summarization, provider: .lmStudio)
                    }
                    if usesLMStudioForVision {
                        self.visionAvailabilityState = Self.unavailableState(for: .vision, provider: .lmStudio)
                    }
                    self.ollamaDiscoverySnapshot = snapshot
                    self.lmStudioDiscoverySnapshot = lmStudioSnapshot
                }
            }
        }
    }

    var summarizationModels: [SummarizationModel] {
        SummarizationModelCatalog.all
    }

    var inferenceProviders: [InferenceProvider] {
        InferenceProvider.allCases
    }

    var ollamaDiscoveredModelTags: [String] {
        ollamaDiscoverySnapshot?.models.map(\.tag) ?? []
    }

    var lmStudioDiscoveredModelIdentifiers: [String] {
        lmStudioDiscoverySnapshot?.models.map(\.identifier) ?? []
    }

    var showsOllamaEndpointConfiguration: Bool {
        selectedSummarizationProviderID == InferenceProvider.ollama.rawValue
            || selectedVisionProviderID == InferenceProvider.ollama.rawValue
    }

    var showsLMStudioEndpointConfiguration: Bool {
        selectedSummarizationProviderID == InferenceProvider.lmStudio.rawValue
            || selectedVisionProviderID == InferenceProvider.lmStudio.rawValue
    }

    var isBuiltInSummarizationProviderSelected: Bool {
        selectedSummarizationProviderID == InferenceProvider.builtIn.rawValue
    }

    var visionModels: [SummarizationModel] {
        SummarizationModelCatalog.all.filter { $0.mmprojDestinationURL != nil }
    }

    var isBuiltInVisionProviderSelected: Bool {
        selectedVisionProviderID == InferenceProvider.builtIn.rawValue
    }

    var summarizationContextWindowPresets: [SummarizationContextWindowPreset] {
        SummarizationContextWindowPreset.allCases
    }

    var recommendedSummarizationContextWindowPreset: SummarizationContextWindowPreset {
        summarizationContextWindowStore.recommendedPreset()
    }

    var transcriptionBackends: [TranscriptionBackend] {
        TranscriptionBackend.allCases
    }

    var transcriptionModels: [TranscriptionModel] {
        TranscriptionModelCatalog.all
    }

    var fluidAudioModels: [FluidAudioASRModel] {
        FluidAudioASRModelCatalog.all
    }

    var isFluidAudioSelected: Bool {
        TranscriptionBackend.backend(for: selectedTranscriptionBackendID) == .fluidAudio
    }

    var isWhisperSelected: Bool {
        !isFluidAudioSelected
    }

    var transcriptionLanguages: [TranscriptionLanguage] {
        TranscriptionLanguage.allCases
    }

    var selectedTranscriptionBackendDisplayName: String {
        TranscriptionBackend.displayName(for: selectedTranscriptionBackendID)
    }

    var vocabularyHintText: String {
        "Use for names, acronyms, product terms."
    }

    var vocabularyBoostingTerms: [String] {
        VocabularyTermEntry.parseFromEditorInput(vocabularyBoostingTermsInput, source: .global)
            .map(\.displayText)
    }

    var vocabularyReadinessStatus: VocabularyReadinessStatus {
        let backend = TranscriptionBackend.backend(for: selectedTranscriptionBackendID)
        guard backend == .fluidAudio else {
            return .unsupported(backend: backend)
        }

        let vocabularyIDs = lastModelValidation.missingModelIDs.filter {
            $0.hasSuffix("-ctc-vocab")
        }
        if !vocabularyIDs.isEmpty {
            let names = vocabularyIDs.map(Self.displayName(for:))
            return .missingModels(
                backend: backend,
                message: "Missing: \(names.joined(separator: ", "))"
            )
        }

        if case .needsDownload(let message) = state {
            return .missingModels(
                backend: backend,
                message: message ?? "Vocabulary models are not ready."
            )
        }

        return .ready(backend: backend)
    }

    var showsVocabularyReadinessRow: Bool {
        isFluidAudioSelected && vocabularyReadinessStatus.state == .missingModels
    }

    var vocabularyReadinessMessage: String? {
        vocabularyReadinessStatus.message
    }

    var transcriptionDownloadStatusState: StatusIcon.State {
        stateIconState(
            isRelevant: isSelectedTranscriptionModelMissingOrInvalid
                || isSelectedFluidAudioModelMissingOrInvalid
                || showsVocabularyReadinessRow
        )
    }

    var summarizationDownloadStatusState: StatusIcon.State {
        stateIconState(isRelevant: isBuiltInSummarizationSelectionMissingOrInvalid)
    }

    var screenContextDownloadStatusState: StatusIcon.State {
        stateIconState(isRelevant: isBuiltInScreenContextSelectionMissingOrInvalid)
    }

    var isCheckingModels: Bool {
        if case .checking = state {
            return true
        }
        return false
    }

    var activeDownloadProgress: ModelDownloadProgress? {
        if case .downloading(let progress) = state {
            return progress
        }
        return nil
    }

    var canStartModelDownload: Bool {
        switch state {
        case .needsDownload:
            return true
        case .ready, .downloading, .checking:
            return false
        }
    }

    var transcriptionDownloadMessage: String? {
        if isFluidAudioSelected {
            return specificDownloadMessage(for: selectedFluidAudioModelID) ?? vocabularyReadinessMessage
        }
        return specificDownloadMessage(for: selectedTranscriptionModelID)
    }

    var summarizationDownloadMessage: String? {
        specificDownloadMessage(for: selectedSummarizationModelID)
    }

    var screenContextDownloadMessage: String? {
        specificDownloadMessage(for: selectedVisionModelID)
    }

    private func persistVocabularySettings() {
        guard !isRestoringVocabularySettings else { return }
        let settings = GlobalVocabularyBoostingSettings(
            enabled: vocabularyBoostingEnabled,
            strength: vocabularyBoostingStrength,
            terms: vocabularyBoostingTerms
        )
        vocabularySettingsStore.save(settings)
    }

    private static func displayName(for id: String) -> String {
        if let summarization = SummarizationModelCatalog.model(for: id) {
            return summarization.displayName
        }
        if let transcription = TranscriptionModelCatalog.model(for: id) {
            return transcription.displayName
        }
        if let fluidAudio = FluidAudioASRModelCatalog.model(for: id) {
            return fluidAudio.displayName
        }
        if id.hasSuffix("-ctc-vocab") {
            return "FluidAudio CTC Vocabulary"
        }
        return id
    }

    private static func unavailableState(
        for capability: InferenceCapability,
        provider: InferenceProvider
    ) -> CapabilityAvailabilityState {
        let message: String
        let status: CapabilityAvailabilityStatus
        switch provider {
        case .builtIn:
            message = "Provider status is unavailable."
            status = .unknown
        case .ollama:
            message = "Ollama is unavailable. Start the local daemon and refresh."
            status = .daemonUnavailable
        case .lmStudio:
            message = "LM Studio is unavailable. Start the local server and refresh."
            status = .serverUnavailable
        }
        return CapabilityAvailabilityState(
            capabilityID: capability,
            providerID: provider,
            isReady: false,
            status: status,
            message: message,
            selectedReference: nil
        )
    }

    private func invalidEndpointState(
        for capability: InferenceCapability,
        provider: InferenceProvider
    ) -> CapabilityAvailabilityState {
        let message: String
        let selectedReference: String
        switch provider {
        case .builtIn:
            message = "Provider configuration is invalid."
            selectedReference = ""
        case .ollama:
            message = "Enter a valid Ollama base URL such as \(AppConfiguration.Defaults.defaultOllamaBaseURL)."
            selectedReference = selectedOllamaBaseURLString
        case .lmStudio:
            message = "Enter a valid LM Studio base URL such as \(AppConfiguration.Defaults.defaultLMStudioBaseURL)."
            selectedReference = selectedLMStudioBaseURLString
        }
        return CapabilityAvailabilityState(
            capabilityID: capability,
            providerID: provider,
            isReady: false,
            status: .needsConfiguration,
            message: message,
            selectedReference: selectedReference
        )
    }

    private func availabilityState(for capability: InferenceCapability) async throws -> CapabilityAvailabilityState {
        if usesCustomAvailabilityProvider {
            return try await availabilityProvider.availability(for: capability)
        }
        let provider = inferenceProviderStore.selectedProvider(for: capability)
        switch provider {
        case .builtIn:
            return try await availabilityProvider.availability(for: capability)
        case .ollama:
            guard let discoverer = makeOllamaModelDiscoverer() else {
                return invalidEndpointState(for: capability, provider: .ollama)
            }
            let tag = inferenceProviderStore.selectedOllamaModelTag(for: capability) ?? ""
            return try await discoverer.validateModelTag(tag, for: capability)
        case .lmStudio:
            guard let discoverer = makeLMStudioModelDiscoverer() else {
                return invalidEndpointState(for: capability, provider: .lmStudio)
            }
            let identifier = inferenceProviderStore.selectedLMStudioModelIdentifier(for: capability) ?? ""
            return try await discoverer.validateModelIdentifier(identifier, for: capability)
        }
    }

    private func discoverOllamaModels() async throws -> OllamaDiscoverySnapshot {
        guard let discoverer = makeOllamaModelDiscoverer() else {
            return OllamaDiscoverySnapshot(
                daemonReachable: false,
                failureReason: "Enter a valid Ollama base URL such as \(AppConfiguration.Defaults.defaultOllamaBaseURL)."
            )
        }
        return try await discoverer.discoverModels()
    }

    private func makeOllamaModelDiscoverer() -> (any OllamaModelDiscovering)? {
        if let providedOllamaModelDiscoverer {
            return providedOllamaModelDiscoverer
        }
        guard let baseURL = connectionStore.selectedBaseURL(for: .ollama) else {
            return nil
        }
        return OllamaModelDiscoveryService(client: OllamaAPIClient(baseURL: baseURL))
    }

    private func discoverLMStudioModels() async throws -> LMStudioDiscoverySnapshot {
        guard let discoverer = makeLMStudioModelDiscoverer() else {
            return LMStudioDiscoverySnapshot(
                serverReachable: false,
                failureReason: "Enter a valid LM Studio base URL such as \(AppConfiguration.Defaults.defaultLMStudioBaseURL)."
            )
        }
        return try await discoverer.discoverModels()
    }

    private func makeLMStudioModelDiscoverer() -> (any LMStudioModelDiscovering)? {
        if let providedLMStudioModelDiscoverer {
            return providedLMStudioModelDiscoverer
        }
        guard let baseURL = connectionStore.selectedBaseURL(for: .lmStudio) else {
            return nil
        }
        return LMStudioModelDiscoveryService(client: LMStudioAPIClient(baseURL: baseURL))
    }

    private var isSelectedTranscriptionModelMissingOrInvalid: Bool {
        lastModelValidation.missingModelIDs.contains(selectedTranscriptionModelID)
            || lastModelValidation.invalidModelIDs.contains(selectedTranscriptionModelID)
    }

    private var isSelectedFluidAudioModelMissingOrInvalid: Bool {
        guard let model = FluidAudioASRModelCatalog.model(for: selectedFluidAudioModelID) else {
            return false
        }
        let vocabularyID = FluidAudioASRModelManager.vocabularyModelID(for: model)
        return lastModelValidation.missingModelIDs.contains(selectedFluidAudioModelID)
            || lastModelValidation.invalidModelIDs.contains(selectedFluidAudioModelID)
            || lastModelValidation.missingModelIDs.contains(vocabularyID)
            || lastModelValidation.invalidModelIDs.contains(vocabularyID)
    }

    private var isBuiltInSummarizationSelectionMissingOrInvalid: Bool {
        guard isBuiltInSummarizationProviderSelected else { return false }
        return lastModelValidation.missingModelIDs.contains(selectedSummarizationModelID)
            || lastModelValidation.invalidModelIDs.contains(selectedSummarizationModelID)
    }

    private var isBuiltInScreenContextSelectionMissingOrInvalid: Bool {
        guard isBuiltInVisionProviderSelected else { return false }
        return lastModelValidation.missingModelIDs.contains(selectedVisionModelID)
            || lastModelValidation.invalidModelIDs.contains(selectedVisionModelID)
    }

    private func specificDownloadMessage(for modelID: String) -> String? {
        if lastModelValidation.missingModelIDs.contains(modelID) {
            return "Missing: \(Self.displayName(for: modelID))"
        }
        if lastModelValidation.invalidModelIDs.contains(modelID) {
            return "Invalid: \(Self.displayName(for: modelID))"
        }
        if case .needsDownload(let message) = state {
            return message
        }
        return nil
    }

    private func stateIconState(isRelevant: Bool) -> StatusIcon.State {
        if case .downloading = state {
            return .attention
        }
        if case .checking = state {
            return .blocked
        }
        if isRelevant {
            return .attention
        }
        return .ready
    }
}
