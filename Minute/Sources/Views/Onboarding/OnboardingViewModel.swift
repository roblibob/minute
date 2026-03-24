import AVFoundation
import Combine
import CoreGraphics
import Foundation
import MinuteCore
import MinuteOllama

@MainActor
final class OnboardingViewModel: ObservableObject {
    enum Step: Int, CaseIterable {
        case intro
        case permissions
        case transcription
        case summarization
        case screenContext
        case vault
        case complete

        var progressionIndex: Int {
            switch self {
            case .intro:
                return 0
            case .permissions:
                return 1
            case .transcription:
                return 2
            case .summarization:
                return 3
            case .screenContext:
                return 4
            case .vault:
                return 5
            case .complete:
                return 6
            }
        }
    }

    typealias ModelsState = ModelSetupLifecycleController.State

    @Published private(set) var currentStep: Step = .intro
    @Published private(set) var isDebugWalkthroughActive = false
    @Published private(set) var microphonePermissionGranted = false
    @Published private(set) var screenRecordingPermissionGranted = false
    @Published private(set) var vaultConfigured = false
    @Published private(set) var modelsState: ModelsState = .checking
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
    @Published private(set) var isRefreshingAvailability = false
    @Published var selectedSummarizationProviderID: String {
        didSet {
            guard oldValue != selectedSummarizationProviderID else { return }
            let provider = InferenceProvider(rawValue: selectedSummarizationProviderID) ?? .builtIn
            inferenceProviderStore.setSelectedProvider(provider, for: .summarization)
            modelLifecycleController.refresh()
            refreshAvailability()
        }
    }
    @Published var selectedSummarizationModelID: String {
        didSet {
            guard oldValue != selectedSummarizationModelID else { return }
            summarizationModelStore.setSelectedModelID(selectedSummarizationModelID)
            modelLifecycleController.refresh()
            refreshAvailability()
        }
    }
    @Published var selectedSummarizationOllamaModelTag: String {
        didSet {
            guard oldValue != selectedSummarizationOllamaModelTag else { return }
            inferenceProviderStore.setSelectedOllamaModelTag(selectedSummarizationOllamaModelTag, for: .summarization)
            refreshAvailability()
        }
    }
    @Published var selectedOllamaBaseURLString: String {
        didSet {
            guard oldValue != selectedOllamaBaseURLString else { return }
            ollamaEndpointStore.setSelectedBaseURLString(selectedOllamaBaseURLString)
            refreshAvailability()
        }
    }
    @Published var selectedSummarizationContextWindowPreset: SummarizationContextWindowPreset {
        didSet {
            guard oldValue != selectedSummarizationContextWindowPreset else { return }
            summarizationContextWindowStore.setSelectedPreset(selectedSummarizationContextWindowPreset)
        }
    }
    @Published var screenContextEnabled: Bool {
        didSet {
            guard oldValue != screenContextEnabled else { return }
            screenContextSettingsStore.setEnabled(screenContextEnabled)
            modelLifecycleController.refresh()
            refreshAvailability()
            updateCurrentStepIfNeeded()
        }
    }
    @Published var selectedVisionProviderID: String {
        didSet {
            guard oldValue != selectedVisionProviderID else { return }
            let provider = InferenceProvider(rawValue: selectedVisionProviderID) ?? .builtIn
            inferenceProviderStore.setSelectedProvider(provider, for: .vision)
            modelLifecycleController.refresh()
            refreshAvailability()
        }
    }
    @Published var selectedVisionModelID: String {
        didSet {
            guard oldValue != selectedVisionModelID else { return }
            visionModelStore.setSelectedModelID(selectedVisionModelID)
            modelLifecycleController.refresh()
            refreshAvailability()
        }
    }
    @Published var selectedVisionOllamaModelTag: String {
        didSet {
            guard oldValue != selectedVisionOllamaModelTag else { return }
            inferenceProviderStore.setSelectedOllamaModelTag(selectedVisionOllamaModelTag, for: .vision)
            refreshAvailability()
        }
    }
    @Published var selectedTranscriptionBackendID: String {
        didSet {
            guard oldValue != selectedTranscriptionBackendID else { return }
            transcriptionBackendStore.setSelectedBackendID(selectedTranscriptionBackendID)
            modelLifecycleController.refresh()
        }
    }
    @Published var selectedTranscriptionModelID: String {
        didSet {
            guard oldValue != selectedTranscriptionModelID else { return }
            transcriptionModelStore.setSelectedModelID(selectedTranscriptionModelID)
            modelLifecycleController.refresh()
        }
    }
    @Published var selectedFluidAudioModelID: String {
        didSet {
            guard oldValue != selectedFluidAudioModelID else { return }
            fluidAudioModelStore.setSelectedModelID(selectedFluidAudioModelID)
            modelLifecycleController.refresh()
        }
    }

    private let defaults: UserDefaults
    private let inferenceProviderStore: InferenceProviderSelectionStore
    private let ollamaEndpointStore: OllamaEndpointSettingsStore
    private let summarizationModelStore: SummarizationModelSelectionStore
    private let summarizationContextWindowStore: SummarizationContextWindowSelectionStore
    private let screenContextSettingsStore: ScreenContextSettingsStore
    private let visionModelStore: VisionModelSelectionStore
    private let transcriptionModelStore: TranscriptionModelSelectionStore
    private let transcriptionBackendStore: TranscriptionBackendSelectionStore
    private let fluidAudioModelStore: FluidAudioASRModelSelectionStore
    private let modelLifecycleController: ModelSetupLifecycleController
    private let availabilityProvider: any CapabilityAvailabilityProviding
    private let usesCustomAvailabilityProvider: Bool
    private let providedOllamaModelDiscoverer: (any OllamaModelDiscovering)?

    private var defaultsObserver: AnyCancellable?
    private var observedVaultBookmark: Data?
    private var cancellables: Set<AnyCancellable> = []
    private var availabilityTask: Task<Void, Never>?

    private enum DefaultsKey {
        static let didShowIntro = "didShowOnboardingIntro"
        static let didCompleteOnboarding = "didCompleteOnboarding"
        static let didSkipPermissions = "didSkipOnboardingPermissions"
    }

    init(
        modelManager: (any ModelManaging)? = nil,
        defaults: UserDefaults = .standard,
        inferenceProviderStore: InferenceProviderSelectionStore? = nil,
        ollamaEndpointStore: OllamaEndpointSettingsStore? = nil,
        summarizationModelStore: SummarizationModelSelectionStore? = nil,
        summarizationContextWindowStore: SummarizationContextWindowSelectionStore? = nil,
        screenContextSettingsStore: ScreenContextSettingsStore? = nil,
        visionModelStore: VisionModelSelectionStore? = nil,
        transcriptionModelStore: TranscriptionModelSelectionStore? = nil,
        transcriptionBackendStore: TranscriptionBackendSelectionStore? = nil,
        fluidAudioModelStore: FluidAudioASRModelSelectionStore? = nil,
        availabilityProvider: (any CapabilityAvailabilityProviding)? = nil,
        ollamaModelDiscoverer: (any OllamaModelDiscovering)? = nil
    ) {
        let providerStore = inferenceProviderStore ?? InferenceProviderSelectionStore(defaults: defaults)
        let endpointStore = ollamaEndpointStore ?? OllamaEndpointSettingsStore(defaults: defaults)
        let store = summarizationModelStore ?? SummarizationModelSelectionStore(defaults: defaults)
        let contextStore = summarizationContextWindowStore ?? SummarizationContextWindowSelectionStore(defaults: defaults)
        let screenContextStore = screenContextSettingsStore ?? ScreenContextSettingsStore(defaults: defaults)
        let visionStore = visionModelStore ?? VisionModelSelectionStore(defaults: defaults)
        let transcriptionStore = transcriptionModelStore ?? TranscriptionModelSelectionStore(defaults: defaults)
        let backendStore = transcriptionBackendStore ?? TranscriptionBackendSelectionStore(defaults: defaults)
        let fluidStore = fluidAudioModelStore ?? FluidAudioASRModelSelectionStore(defaults: defaults)
        let resolvedModelManager = modelManager ?? DefaultModelManager(
            providerStore: providerStore,
            selectionStore: store,
            visionModelStore: visionStore,
            transcriptionSelectionStore: transcriptionStore,
            transcriptionBackendStore: backendStore,
            fluidAudioModelStore: fluidStore
        )
        self.defaults = defaults
        self.inferenceProviderStore = providerStore
        self.ollamaEndpointStore = endpointStore
        self.summarizationModelStore = store
        self.summarizationContextWindowStore = contextStore
        self.screenContextSettingsStore = screenContextStore
        self.visionModelStore = visionStore
        self.transcriptionModelStore = transcriptionStore
        self.transcriptionBackendStore = backendStore
        self.fluidAudioModelStore = fluidStore
        self.providedOllamaModelDiscoverer = ollamaModelDiscoverer
        self.usesCustomAvailabilityProvider = availabilityProvider != nil
        self.availabilityProvider = availabilityProvider ?? InferenceRuntimeFactory(
            providerStore: providerStore,
            summarizationModelStore: store,
            summarizationContextWindowStore: contextStore,
            visionModelStore: visionStore
        )
        self.modelLifecycleController = ModelSetupLifecycleController(
            modelManager: resolvedModelManager,
            displayName: Self.displayName(for:)
        )
        let selectedProvider = providerStore.selectedProvider(for: .summarization)
        self.selectedSummarizationProviderID = selectedProvider.rawValue
        let selectedModel = store.selectedModel()
        self.selectedSummarizationModelID = selectedModel.id
        if store.selectedModelID() != selectedModel.id {
            store.setSelectedModelID(selectedModel.id)
        }
        self.selectedSummarizationOllamaModelTag = providerStore.selectedOllamaModelTag(for: .summarization) ?? ""
        self.selectedOllamaBaseURLString = endpointStore.selectedBaseURLString()
        self.selectedSummarizationContextWindowPreset = contextStore.selectedPreset()
        self.screenContextEnabled = screenContextStore.isEnabled
        let selectedVisionProvider = providerStore.selectedProvider(for: .vision)
        self.selectedVisionProviderID = selectedVisionProvider.rawValue
        let selectedVisionModel = visionStore.selectedModel()
        self.selectedVisionModelID = selectedVisionModel.id
        if visionStore.selectedModelID() != selectedVisionModel.id {
            visionStore.setSelectedModelID(selectedVisionModel.id)
        }
        self.selectedVisionOllamaModelTag = providerStore.selectedOllamaModelTag(for: .vision) ?? ""
        let selectedBackend = backendStore.selectedBackend()
        self.selectedTranscriptionBackendID = selectedBackend.id
        if backendStore.selectedBackendID() != selectedBackend.id {
            backendStore.setSelectedBackendID(selectedBackend.id)
        }
        let selectedTranscription = transcriptionStore.selectedModel()
        self.selectedTranscriptionModelID = selectedTranscription.id
        if transcriptionStore.selectedModelID() != selectedTranscription.id {
            transcriptionStore.setSelectedModelID(selectedTranscription.id)
        }
        let selectedFluid = fluidStore.selectedModel()
        self.selectedFluidAudioModelID = selectedFluid.id
        if fluidStore.selectedModelID() != selectedFluid.id {
            fluidStore.setSelectedModelID(selectedFluid.id)
        }
        let bookmarkStore = UserDefaultsVaultBookmarkStore(
            defaults: defaults,
            key: AppConfiguration.Defaults.vaultRootBookmarkKey
        )
        Self.migrateLegacyCompletionIfNeeded(defaults: defaults, bookmarkStore: bookmarkStore)

        refreshAll()
        observedVaultBookmark = currentVaultBookmark()

        defaultsObserver = NotificationCenter.default.publisher(
            for: UserDefaults.didChangeNotification,
            object: defaults
        )
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.handleDefaultsDidChange()
            }

        modelLifecycleController.$state
            .receive(on: RunLoop.main)
            .sink { [weak self] state in
                self?.modelsState = state
                self?.updateCurrentStepIfNeeded()
            }
            .store(in: &cancellables)
    }

    var permissionsReady: Bool {
        microphonePermissionGranted && screenRecordingPermissionGranted
    }

    var modelsReady: Bool {
        guard summarizationConfigurationReady,
              summarizationAvailabilityState.isReady,
              screenContextStageReady else {
            return false
        }
        if case .ready = modelsState {
            return true
        }
        return false
    }

    var requirementsMet: Bool {
        permissionsSatisfied && modelsReady && vaultConfigured
    }

    var isComplete: Bool {
        didCompleteOnboarding
    }

    var summarizationModels: [SummarizationModel] {
        SummarizationModelCatalog.all
    }

    var summarizationProviders: [InferenceProvider] {
        InferenceProvider.allCases
    }

    var isBuiltInSummarizationProviderSelected: Bool {
        selectedSummarizationProviderID == InferenceProvider.builtIn.rawValue
    }

    var summarizationContextWindowPresets: [SummarizationContextWindowPreset] {
        SummarizationContextWindowPreset.allCases
    }

    var recommendedSummarizationContextWindowPreset: SummarizationContextWindowPreset {
        summarizationContextWindowStore.recommendedPreset()
    }

    var visionModels: [SummarizationModel] {
        SummarizationModelCatalog.all.filter { $0.mmprojDestinationURL != nil }
    }

    var isBuiltInVisionProviderSelected: Bool {
        selectedVisionProviderID == InferenceProvider.builtIn.rawValue
    }

    var usesOllamaForSummarization: Bool {
        selectedSummarizationProviderID == InferenceProvider.ollama.rawValue
    }

    var usesOllamaForScreenContext: Bool {
        selectedVisionProviderID == InferenceProvider.ollama.rawValue
    }

    var ollamaDiscoveredModelTags: [String] {
        ollamaDiscoverySnapshot?.models.map(\.tag) ?? []
    }

    var transcriptionSetupReady: Bool {
        if isFluidAudioSelected {
            return !selectedFluidAudioModelID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
        return !selectedTranscriptionModelID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var summarizationStageReady: Bool {
        guard summarizationConfigurationReady else { return false }
        if usesOllamaForSummarization {
            return summarizationAvailabilityState.isReady
        }
        return true
    }

    var screenContextStageReady: Bool {
        guard screenContextEnabled else { return true }
        guard visionConfigurationReady else { return false }
        if usesOllamaForScreenContext {
            return visionAvailabilityState.isReady
        }
        return true
    }

    var showsOllamaEndpointConfigurationForSummarization: Bool {
        usesOllamaForSummarization
    }

    var showsOllamaEndpointConfigurationForScreenContext: Bool {
        usesOllamaForScreenContext
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

    var selectedTranscriptionBackendDisplayName: String {
        TranscriptionBackend.displayName(for: selectedTranscriptionBackendID)
    }

    var primaryButtonTitle: String {
        switch currentStep {
        case .transcription:
            return "Next: Summarization"
        case .summarization:
            return "Next: Screen Context"
        case .screenContext:
            return "Continue"
        case .vault:
            return "Done"
        case .complete:
            return "Done"
        default:
            return "Continue"
        }
    }

    var modelStepDescription: String {
        switch currentStep {
        case .transcription:
            return "Start by choosing your transcription backend and local transcription model."
        case .summarization:
            return "Choose the summarization provider that fits your workflow: built-in for simplicity or Ollama for advanced control."
        case .screenContext:
            return "Screen context is optional. Turn it on only if you want Minute to use selected window content while summarizing."
        default:
            return ""
        }
    }

    var primaryButtonEnabled: Bool {
        switch currentStep {
        case .intro:
            return true
        case .permissions:
            return permissionsSatisfied
        case .transcription:
            return transcriptionSetupReady
        case .summarization:
            return summarizationStageReady
        case .screenContext:
            return screenContextStageReady
        case .vault:
            return vaultConfigured
        case .complete:
            return true
        }
    }

    func refreshAll() {
        refreshPermissions()
        refreshVaultStatus()
        modelLifecycleController.refresh()
        refreshAvailability()
        updateCurrentStepIfNeeded()
    }

    func startDebugWalkthrough() {
        guard !isDebugWalkthroughActive else { return }
        isDebugWalkthroughActive = true
        setCurrentStep(.intro)
    }

    func requestMicrophonePermission() {
        Task {
            let granted = await AVCaptureDevice.requestAccess(for: .audio)
            microphonePermissionGranted = granted
            updateCurrentStepIfNeeded()
        }
    }

    func requestScreenRecordingPermission() {
        Task {
            let granted = await ScreenRecordingPermission.request()
            screenRecordingPermissionGranted = granted
            updateCurrentStepIfNeeded()
        }
    }

    func startModelDownload() {
        modelLifecycleController.startDownload()
    }

    func refreshAvailability() {
        availabilityTask?.cancel()
        let usesOllamaForSummarization = selectedSummarizationProviderID == InferenceProvider.ollama.rawValue
        let usesOllamaForVision = selectedVisionProviderID == InferenceProvider.ollama.rawValue
        let shouldDiscoverOllama = usesOllamaForSummarization || usesOllamaForVision
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

            do {
                let summarizationState = try await summarization
                let visionState = try await vision
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    self.summarizationAvailabilityState = summarizationState
                    self.visionAvailabilityState = visionState
                    self.ollamaDiscoverySnapshot = snapshot
                    self.isRefreshingAvailability = false
                    self.updateCurrentStepIfNeeded()
                }
            } catch {
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    self.isRefreshingAvailability = false
                    if usesOllamaForSummarization {
                        self.summarizationAvailabilityState = Self.unavailableState(for: .summarization)
                    }
                    if usesOllamaForVision {
                        self.visionAvailabilityState = Self.unavailableState(for: .vision)
                    }
                    self.ollamaDiscoverySnapshot = snapshot
                    self.updateCurrentStepIfNeeded()
                }
            }
        }
    }

    func advance() {
        if isDebugWalkthroughActive {
            advanceDebugWalkthrough()
            return
        }

        switch currentStep {
        case .intro:
            didShowIntro = true
            setCurrentStep(.permissions)

        case .permissions:
            guard permissionsSatisfied else { return }
            setCurrentStep(.transcription)

        case .transcription:
            guard transcriptionSetupReady else { return }
            setCurrentStep(.summarization)

        case .summarization:
            guard summarizationStageReady else { return }
            setCurrentStep(.screenContext)

        case .screenContext:
            guard screenContextStageReady else { return }
            setCurrentStep(.vault)

        case .vault:
            guard vaultConfigured else { return }
            didCompleteOnboarding = true
            setCurrentStep(.complete)

        case .complete:
            break
        }
    }

    func skipPermissions() {
        didSkipPermissions = true
        setCurrentStep(.transcription)
    }

    private func refreshPermissions() {
        let status = AVCaptureDevice.authorizationStatus(for: .audio)
        microphonePermissionGranted = (status == .authorized)
        Task {
            let granted = await ScreenRecordingPermission.refresh()
            screenRecordingPermissionGranted = granted
            updateCurrentStepIfNeeded()
        }
    }

    private func handleDefaultsDidChange() {
        let bookmark = currentVaultBookmark()
        guard bookmark != observedVaultBookmark else { return }
        observedVaultBookmark = bookmark
        refreshVaultStatus()
    }

    private func currentVaultBookmark() -> Data? {
        defaults.data(forKey: AppConfiguration.Defaults.vaultRootBookmarkKey)
    }

    private func refreshVaultStatus() {
        let isConfigured = currentVaultBookmark() != nil
        guard vaultConfigured != isConfigured else { return }
        vaultConfigured = isConfigured
        updateCurrentStepIfNeeded()
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

    private func updateCurrentStepIfNeeded() {
        guard !isDebugWalkthroughActive else { return }

        guard didShowIntro else {
            setCurrentStep(.intro)
            return
        }

        let required = requiredStep()
        if currentStep == .intro || required.progressionIndex < currentStep.progressionIndex {
            setCurrentStep(required)
        }
    }

    private func requiredStep() -> Step {
        if !permissionsSatisfied {
            return .permissions
        }
        if !transcriptionSetupReady {
            return .transcription
        }
        if !summarizationStageReady {
            return .summarization
        }
        if !screenContextStageReady {
            return .screenContext
        }
        if !vaultConfigured {
            return .vault
        }
        return .complete
    }

    private func setCurrentStep(_ step: Step) {
        currentStep = step
    }

    private func advanceDebugWalkthrough() {
        switch currentStep {
        case .intro:
            setCurrentStep(.permissions)

        case .permissions:
            guard permissionsSatisfied else { return }
            setCurrentStep(.transcription)

        case .transcription:
            guard transcriptionSetupReady else { return }
            setCurrentStep(.summarization)

        case .summarization:
            guard summarizationStageReady else { return }
            setCurrentStep(.screenContext)

        case .screenContext:
            guard screenContextStageReady else { return }
            setCurrentStep(.vault)

        case .vault:
            guard vaultConfigured else { return }
            didCompleteOnboarding = true
            setCurrentStep(.complete)

        case .complete:
            isDebugWalkthroughActive = false
        }
    }

    private var didShowIntro: Bool {
        get { defaults.bool(forKey: DefaultsKey.didShowIntro) }
        set { defaults.set(newValue, forKey: DefaultsKey.didShowIntro) }
    }

    private var didCompleteOnboarding: Bool {
        get { defaults.bool(forKey: DefaultsKey.didCompleteOnboarding) }
        set { defaults.set(newValue, forKey: DefaultsKey.didCompleteOnboarding) }
    }

    private var didSkipPermissions: Bool {
        get { defaults.bool(forKey: DefaultsKey.didSkipPermissions) }
        set { defaults.set(newValue, forKey: DefaultsKey.didSkipPermissions) }
    }

    private var permissionsSatisfied: Bool {
        permissionsReady || didSkipPermissions
    }

    private var summarizationConfigurationReady: Bool {
        let provider = InferenceProvider(rawValue: selectedSummarizationProviderID) ?? .builtIn
        switch provider {
        case .builtIn:
            return !selectedSummarizationModelID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .ollama:
            return !selectedSummarizationOllamaModelTag.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
    }

    private var visionConfigurationReady: Bool {
        guard screenContextEnabled else { return true }
        let provider = InferenceProvider(rawValue: selectedVisionProviderID) ?? .builtIn
        switch provider {
        case .builtIn:
            return !selectedVisionModelID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .ollama:
            return !selectedVisionOllamaModelTag.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
    }

    private static func migrateLegacyCompletionIfNeeded(
        defaults: UserDefaults,
        bookmarkStore: any VaultBookmarkStoring
    ) {
        guard defaults.object(forKey: DefaultsKey.didCompleteOnboarding) == nil else {
            return
        }
        guard bookmarkStore.loadVaultRootBookmark() != nil else {
            return
        }

        defaults.set(true, forKey: DefaultsKey.didShowIntro)
        defaults.set(true, forKey: DefaultsKey.didCompleteOnboarding)
    }

    private static func unavailableState(for capability: InferenceCapability) -> CapabilityAvailabilityState {
        CapabilityAvailabilityState(
            capabilityID: capability,
            providerID: .ollama,
            isReady: false,
            status: .daemonUnavailable,
            message: "Ollama is unavailable. Start the local daemon and refresh.",
            selectedReference: nil
        )
    }

    private func invalidEndpointState(for capability: InferenceCapability) -> CapabilityAvailabilityState {
        CapabilityAvailabilityState(
            capabilityID: capability,
            providerID: .ollama,
            isReady: false,
            status: .needsConfiguration,
            message: "Enter a valid Ollama base URL such as \(AppConfiguration.Defaults.defaultOllamaBaseURL).",
            selectedReference: selectedOllamaBaseURLString
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
                return invalidEndpointState(for: capability)
            }
            let tag = inferenceProviderStore.selectedOllamaModelTag(for: capability) ?? ""
            return try await discoverer.validateModelTag(tag, for: capability)
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
        guard let baseURL = ollamaEndpointStore.selectedBaseURL() else {
            return nil
        }
        return OllamaModelDiscoveryService(client: OllamaAPIClient(baseURL: baseURL))
    }
}
