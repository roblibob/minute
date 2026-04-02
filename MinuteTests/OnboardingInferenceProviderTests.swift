import Foundation
import Testing
@testable import Minute
@testable import MinuteCore

@MainActor
struct OnboardingInferenceProviderTests {
    @Test
    func selectingOllamaSummarizationProvider_persistsTagAndKeepsBuiltInModel() throws {
        let suite = "OnboardingInferenceProviderTests.persist.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defaults.removePersistentDomain(forName: suite)

        let providerStore = InferenceProviderSelectionStore(defaults: defaults)
        let summarizationStore = SummarizationModelSelectionStore(defaults: defaults, key: "sum")
        let contextStore = SummarizationContextWindowSelectionStore(defaults: defaults, key: "ctx")
        let visionStore = VisionModelSelectionStore(defaults: defaults, key: "vision")
        let transcriptionStore = TranscriptionModelSelectionStore(defaults: defaults, key: "trans")
        let backendStore = TranscriptionBackendSelectionStore(defaults: defaults, key: "backend")
        let fluidStore = FluidAudioASRModelSelectionStore(defaults: defaults, key: "fluid")

        let model = OnboardingViewModel(
            modelManager: StubOnboardingModelManager(validation: ModelValidationResult(missingModelIDs: [], invalidModelIDs: [])),
            defaults: defaults,
            inferenceProviderStore: providerStore,
            summarizationModelStore: summarizationStore,
            summarizationContextWindowStore: contextStore,
            visionModelStore: visionStore,
            transcriptionModelStore: transcriptionStore,
            transcriptionBackendStore: backendStore,
            fluidAudioModelStore: fluidStore
        )

        model.selectedSummarizationProviderID = InferenceProvider.ollama.rawValue
        model.selectedSummarizationOllamaModelTag = "  phi4-mini:latest  "

        #expect(providerStore.selectedProvider(for: .summarization) == .ollama)
        #expect(providerStore.selectedOllamaModelTag(for: .summarization) == "phi4-mini:latest")
        #expect(model.isBuiltInSummarizationProviderSelected == false)
        #expect(summarizationStore.selectedModelID() == SummarizationModelCatalog.defaultModel.id)
    }

    @Test
    func restoringPersistedOllamaSelection_updatesOnboardingState() throws {
        let suite = "OnboardingInferenceProviderTests.restore.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defaults.removePersistentDomain(forName: suite)

        let providerStore = InferenceProviderSelectionStore(defaults: defaults)
        providerStore.setSelectedProvider(.ollama, for: .summarization)
        providerStore.setSelectedOllamaModelTag("llama3.2:latest", for: .summarization)
        providerStore.setSelectedProvider(.ollama, for: .vision)
        providerStore.setSelectedOllamaModelTag("llava:latest", for: .vision)
        let visionStore = VisionModelSelectionStore(defaults: defaults, key: "vision")

        let model = OnboardingViewModel(
            modelManager: StubOnboardingModelManager(validation: ModelValidationResult(missingModelIDs: [], invalidModelIDs: [])),
            defaults: defaults,
            inferenceProviderStore: providerStore,
            summarizationModelStore: SummarizationModelSelectionStore(defaults: defaults, key: "sum"),
            summarizationContextWindowStore: SummarizationContextWindowSelectionStore(defaults: defaults, key: "ctx"),
            visionModelStore: visionStore,
            transcriptionModelStore: TranscriptionModelSelectionStore(defaults: defaults, key: "trans"),
            transcriptionBackendStore: TranscriptionBackendSelectionStore(defaults: defaults, key: "backend"),
            fluidAudioModelStore: FluidAudioASRModelSelectionStore(defaults: defaults, key: "fluid")
        )

        #expect(model.selectedSummarizationProviderID == InferenceProvider.ollama.rawValue)
        #expect(model.selectedSummarizationOllamaModelTag == "llama3.2:latest")
        #expect(model.isBuiltInSummarizationProviderSelected == false)
        #expect(model.selectedVisionProviderID == InferenceProvider.ollama.rawValue)
        #expect(model.selectedVisionOllamaModelTag == "llava:latest")
        #expect(model.selectedVisionModelID == visionStore.selectedModel().id)
        #expect(model.isBuiltInVisionProviderSelected == false)
    }

    @Test
    func selectingLMStudioSummarizationProvider_persistsIdentifierAndKeepsBuiltInModel() throws {
        let suite = "OnboardingInferenceProviderTests.lmstudio.persist.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defaults.removePersistentDomain(forName: suite)

        let providerStore = InferenceProviderSelectionStore(defaults: defaults)
        let summarizationStore = SummarizationModelSelectionStore(defaults: defaults, key: "sum")
        let contextStore = SummarizationContextWindowSelectionStore(defaults: defaults, key: "ctx")
        let visionStore = VisionModelSelectionStore(defaults: defaults, key: "vision")
        let transcriptionStore = TranscriptionModelSelectionStore(defaults: defaults, key: "trans")
        let backendStore = TranscriptionBackendSelectionStore(defaults: defaults, key: "backend")
        let fluidStore = FluidAudioASRModelSelectionStore(defaults: defaults, key: "fluid")

        let model = OnboardingViewModel(
            modelManager: StubOnboardingModelManager(validation: ModelValidationResult(missingModelIDs: [], invalidModelIDs: [])),
            defaults: defaults,
            inferenceProviderStore: providerStore,
            summarizationModelStore: summarizationStore,
            summarizationContextWindowStore: contextStore,
            visionModelStore: visionStore,
            transcriptionModelStore: transcriptionStore,
            transcriptionBackendStore: backendStore,
            fluidAudioModelStore: fluidStore
        )

        model.selectedSummarizationProviderID = InferenceProvider.lmStudio.rawValue
        model.selectedSummarizationLMStudioModelIdentifier = "  qwen2.5-7b-instruct  "

        #expect(providerStore.selectedProvider(for: .summarization) == .lmStudio)
        #expect(providerStore.selectedLMStudioModelIdentifier(for: .summarization) == "qwen2.5-7b-instruct")
        #expect(model.isBuiltInSummarizationProviderSelected == false)
        #expect(summarizationStore.selectedModelID() == SummarizationModelCatalog.defaultModel.id)
    }

    @Test
    func restoringPersistedLMStudioSelection_updatesOnboardingState() throws {
        let suite = "OnboardingInferenceProviderTests.lmstudio.restore.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defaults.removePersistentDomain(forName: suite)

        let providerStore = InferenceProviderSelectionStore(defaults: defaults)
        providerStore.setSelectedProvider(.lmStudio, for: .summarization)
        providerStore.setSelectedLMStudioModelIdentifier("qwen2.5-7b-instruct", for: .summarization)
        providerStore.setSelectedProvider(.lmStudio, for: .vision)
        providerStore.setSelectedLMStudioModelIdentifier("qwen2.5-vl-7b", for: .vision)
        let visionStore = VisionModelSelectionStore(defaults: defaults, key: "vision")

        let model = OnboardingViewModel(
            modelManager: StubOnboardingModelManager(validation: ModelValidationResult(missingModelIDs: [], invalidModelIDs: [])),
            defaults: defaults,
            inferenceProviderStore: providerStore,
            summarizationModelStore: SummarizationModelSelectionStore(defaults: defaults, key: "sum"),
            summarizationContextWindowStore: SummarizationContextWindowSelectionStore(defaults: defaults, key: "ctx"),
            visionModelStore: visionStore,
            transcriptionModelStore: TranscriptionModelSelectionStore(defaults: defaults, key: "trans"),
            transcriptionBackendStore: TranscriptionBackendSelectionStore(defaults: defaults, key: "backend"),
            fluidAudioModelStore: FluidAudioASRModelSelectionStore(defaults: defaults, key: "fluid")
        )

        #expect(model.selectedSummarizationProviderID == InferenceProvider.lmStudio.rawValue)
        #expect(model.selectedSummarizationLMStudioModelIdentifier == "qwen2.5-7b-instruct")
        #expect(model.selectedVisionProviderID == InferenceProvider.lmStudio.rawValue)
        #expect(model.selectedVisionLMStudioModelIdentifier == "qwen2.5-vl-7b")
        #expect(model.selectedVisionModelID == visionStore.selectedModel().id)
    }

    @Test
    func selectingLMStudioProviders_persistsIdentifiersAndConnection() throws {
        let suite = "OnboardingInferenceProviderTests.lmstudio.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defaults.removePersistentDomain(forName: suite)

        let providerStore = InferenceProviderSelectionStore(defaults: defaults)
        let connectionStore = ProviderConnectionSettingsStore(defaults: defaults)

        let model = OnboardingViewModel(
            modelManager: StubOnboardingModelManager(validation: ModelValidationResult(missingModelIDs: [], invalidModelIDs: [])),
            defaults: defaults,
            inferenceProviderStore: providerStore,
            connectionStore: connectionStore,
            summarizationModelStore: SummarizationModelSelectionStore(defaults: defaults, key: "sum"),
            summarizationContextWindowStore: SummarizationContextWindowSelectionStore(defaults: defaults, key: "ctx"),
            visionModelStore: VisionModelSelectionStore(defaults: defaults, key: "vision"),
            transcriptionModelStore: TranscriptionModelSelectionStore(defaults: defaults, key: "trans"),
            transcriptionBackendStore: TranscriptionBackendSelectionStore(defaults: defaults, key: "backend"),
            fluidAudioModelStore: FluidAudioASRModelSelectionStore(defaults: defaults, key: "fluid")
        )

        model.selectedSummarizationProviderID = InferenceProvider.lmStudio.rawValue
        model.selectedSummarizationLMStudioModelIdentifier = "  qwen2.5-7b-instruct  "
        model.selectedVisionProviderID = InferenceProvider.lmStudio.rawValue
        model.selectedVisionLMStudioModelIdentifier = "  qwen2.5-vl-7b  "
        model.selectedLMStudioBaseURLString = " http://127.0.0.1:1234 "

        #expect(providerStore.selectedProvider(for: .summarization) == .lmStudio)
        #expect(providerStore.selectedLMStudioModelIdentifier(for: .summarization) == "qwen2.5-7b-instruct")
        #expect(providerStore.selectedProvider(for: .vision) == .lmStudio)
        #expect(providerStore.selectedLMStudioModelIdentifier(for: .vision) == "qwen2.5-vl-7b")
        #expect(connectionStore.selectedBaseURLString(for: .lmStudio) == "http://127.0.0.1:1234")
    }

    @Test
    func invalidOllamaSelections_keepWizardBlockedUntilValidationPasses() async throws {
        let suite = "OnboardingInferenceProviderTests.validation.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defaults.removePersistentDomain(forName: suite)
        defaults.set(true, forKey: AppConfiguration.Defaults.screenContextEnabledKey)

        let providerStore = InferenceProviderSelectionStore(defaults: defaults)
        providerStore.setSelectedProvider(.ollama, for: .summarization)
        providerStore.setSelectedOllamaModelTag("phi4-mini", for: .summarization)
        providerStore.setSelectedProvider(.ollama, for: .vision)
        providerStore.setSelectedOllamaModelTag("phi4-mini", for: .vision)

        let model = OnboardingViewModel(
            modelManager: StubOnboardingModelManager(validation: ModelValidationResult(missingModelIDs: [], invalidModelIDs: [])),
            defaults: defaults,
            inferenceProviderStore: providerStore,
            summarizationModelStore: SummarizationModelSelectionStore(defaults: defaults, key: "sum"),
            summarizationContextWindowStore: SummarizationContextWindowSelectionStore(defaults: defaults, key: "ctx"),
            visionModelStore: VisionModelSelectionStore(defaults: defaults, key: "vision"),
            transcriptionModelStore: TranscriptionModelSelectionStore(defaults: defaults, key: "trans"),
            transcriptionBackendStore: TranscriptionBackendSelectionStore(defaults: defaults, key: "backend"),
            fluidAudioModelStore: FluidAudioASRModelSelectionStore(defaults: defaults, key: "fluid"),
            availabilityProvider: StubOnboardingAvailabilityProvider(
                summarizationState: .ready(.summarization, reference: "phi4-mini", provider: .ollama),
                visionState: CapabilityAvailabilityState(
                    capabilityID: .vision,
                    providerID: .ollama,
                    isReady: false,
                    status: .visionUnsupported,
                    message: "Selected Ollama model does not advertise vision support.",
                    selectedReference: "phi4-mini"
                )
            ),
            ollamaModelDiscoverer: StubOnboardingOllamaDiscoverer(snapshot: OllamaDiscoverySnapshot(daemonReachable: true))
        )

        try await eventually(timeoutNanoseconds: 1_000_000_000) {
            await MainActor.run {
                model.visionAvailabilityState.status == .visionUnsupported
            }
        }

        #expect(model.selectedVisionOllamaModelTag == "phi4-mini")
        #expect(model.visionAvailabilityState.status == .visionUnsupported)
        #expect(model.modelsReady == false)
    }

    @Test
    func disabledScreenContext_doesNotBlockWizardReadiness() async throws {
        let suite = "OnboardingInferenceProviderTests.disabledScreenContext.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defaults.removePersistentDomain(forName: suite)
        defaults.set(false, forKey: AppConfiguration.Defaults.screenContextEnabledKey)

        let providerStore = InferenceProviderSelectionStore(defaults: defaults)
        providerStore.setSelectedProvider(.ollama, for: .summarization)
        providerStore.setSelectedOllamaModelTag("phi4-mini", for: .summarization)
        providerStore.setSelectedProvider(.ollama, for: .vision)
        providerStore.setSelectedOllamaModelTag("broken-vision-tag", for: .vision)

        let model = OnboardingViewModel(
            modelManager: StubOnboardingModelManager(validation: ModelValidationResult(missingModelIDs: [], invalidModelIDs: [])),
            defaults: defaults,
            inferenceProviderStore: providerStore,
            summarizationModelStore: SummarizationModelSelectionStore(defaults: defaults, key: "sum"),
            summarizationContextWindowStore: SummarizationContextWindowSelectionStore(defaults: defaults, key: "ctx"),
            visionModelStore: VisionModelSelectionStore(defaults: defaults, key: "vision"),
            transcriptionModelStore: TranscriptionModelSelectionStore(defaults: defaults, key: "trans"),
            transcriptionBackendStore: TranscriptionBackendSelectionStore(defaults: defaults, key: "backend"),
            fluidAudioModelStore: FluidAudioASRModelSelectionStore(defaults: defaults, key: "fluid"),
            availabilityProvider: StubOnboardingAvailabilityProvider(
                summarizationState: .ready(.summarization, reference: "phi4-mini", provider: .ollama),
                visionState: CapabilityAvailabilityState(
                    capabilityID: .vision,
                    providerID: .ollama,
                    isReady: false,
                    status: .visionUnsupported,
                    message: "Selected Ollama model does not advertise vision support.",
                    selectedReference: "broken-vision-tag"
                )
            ),
            ollamaModelDiscoverer: StubOnboardingOllamaDiscoverer(snapshot: OllamaDiscoverySnapshot(daemonReachable: true))
        )

        try await eventually(timeoutNanoseconds: 1_000_000_000) {
            await MainActor.run {
                model.modelsReady
            }
        }

        #expect(model.screenContextEnabled == false)
        #expect(model.screenContextStageReady)
        #expect(model.modelsReady)
    }

    @Test
    func invalidLMStudioVisionSelection_keepsWizardBlockedUntilValidationPasses() async throws {
        let suite = "OnboardingInferenceProviderTests.lmstudio.validation.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defaults.removePersistentDomain(forName: suite)
        defaults.set(true, forKey: AppConfiguration.Defaults.screenContextEnabledKey)

        let providerStore = InferenceProviderSelectionStore(defaults: defaults)
        providerStore.setSelectedProvider(.lmStudio, for: .summarization)
        providerStore.setSelectedLMStudioModelIdentifier("qwen2.5-7b-instruct", for: .summarization)
        providerStore.setSelectedProvider(.lmStudio, for: .vision)
        providerStore.setSelectedLMStudioModelIdentifier("qwen2.5-7b-instruct", for: .vision)

        let model = OnboardingViewModel(
            modelManager: StubOnboardingModelManager(validation: ModelValidationResult(missingModelIDs: [], invalidModelIDs: [])),
            defaults: defaults,
            inferenceProviderStore: providerStore,
            summarizationModelStore: SummarizationModelSelectionStore(defaults: defaults, key: "sum"),
            summarizationContextWindowStore: SummarizationContextWindowSelectionStore(defaults: defaults, key: "ctx"),
            visionModelStore: VisionModelSelectionStore(defaults: defaults, key: "vision"),
            transcriptionModelStore: TranscriptionModelSelectionStore(defaults: defaults, key: "trans"),
            transcriptionBackendStore: TranscriptionBackendSelectionStore(defaults: defaults, key: "backend"),
            fluidAudioModelStore: FluidAudioASRModelSelectionStore(defaults: defaults, key: "fluid"),
            availabilityProvider: StubOnboardingAvailabilityProvider(
                summarizationState: .ready(.summarization, reference: "qwen2.5-7b-instruct", provider: .lmStudio),
                visionState: CapabilityAvailabilityState(
                    capabilityID: .vision,
                    providerID: .lmStudio,
                    isReady: false,
                    status: .visionUnsupported,
                    message: "Selected LM Studio model does not advertise vision support.",
                    selectedReference: "qwen2.5-7b-instruct"
                )
            ),
            lmStudioModelDiscoverer: StubOnboardingLMStudioDiscoverer(snapshot: LMStudioDiscoverySnapshot(serverReachable: true))
        )

        try await eventually(timeoutNanoseconds: 1_000_000_000) {
            await MainActor.run {
                model.visionAvailabilityState.status == .visionUnsupported
            }
        }

        #expect(model.selectedVisionLMStudioModelIdentifier == "qwen2.5-7b-instruct")
        #expect(model.visionAvailabilityState.status == .visionUnsupported)
        #expect(model.modelsReady == false)
    }
}

private struct StubOnboardingModelManager: ModelManaging {
    var validation: ModelValidationResult

    func ensureModelsPresent(progress: (@Sendable (ModelDownloadProgress) -> Void)?) async throws {
        _ = progress
    }

    func validateModels() async throws -> ModelValidationResult {
        validation
    }

    func removeModels(withIDs ids: [String]) async throws {
        _ = ids
    }
}

private struct StubOnboardingAvailabilityProvider: CapabilityAvailabilityProviding {
    var summarizationState: CapabilityAvailabilityState
    var visionState: CapabilityAvailabilityState

    func availability(for capability: InferenceCapability) async throws -> CapabilityAvailabilityState {
        switch capability {
        case .summarization:
            return summarizationState
        case .vision:
            return visionState
        }
    }
}

private struct StubOnboardingOllamaDiscoverer: OllamaModelDiscovering {
    var snapshot: OllamaDiscoverySnapshot

    func discoverModels() async throws -> OllamaDiscoverySnapshot {
        snapshot
    }

    func validateModelTag(_ tag: String, for capability: InferenceCapability) async throws -> CapabilityAvailabilityState {
        .ready(capability, reference: tag, provider: .ollama)
    }
}

private struct StubOnboardingLMStudioDiscoverer: LMStudioModelDiscovering {
    var snapshot: LMStudioDiscoverySnapshot

    func discoverModels() async throws -> LMStudioDiscoverySnapshot {
        snapshot
    }

    func validateModelIdentifier(_ identifier: String, for capability: InferenceCapability) async throws -> CapabilityAvailabilityState {
        .ready(capability, reference: identifier, provider: .lmStudio)
    }
}

private extension CapabilityAvailabilityState {
    static func ready(
        _ capability: InferenceCapability,
        reference: String,
        provider: InferenceProvider = .builtIn
    ) -> CapabilityAvailabilityState {
        CapabilityAvailabilityState(
            capabilityID: capability,
            providerID: provider,
            isReady: true,
            status: .ready,
            message: nil,
            selectedReference: reference
        )
    }
}
