import Foundation
import Testing
@testable import Minute
@testable import MinuteCore

@MainActor
struct ModelsSettingsInferenceProviderTests {
    @Test
    func capabilitySelectionsPersistIndependently() async throws {
        let suite = "ModelsSettingsInferenceProviderTests.persist.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defaults.removePersistentDomain(forName: suite)

        let providerStore = InferenceProviderSelectionStore(defaults: defaults)
        let summarizationStore = SummarizationModelSelectionStore(defaults: defaults, key: "sum")
        let visionStore = VisionModelSelectionStore(defaults: defaults, key: "vision")

        let model = ModelsSettingsViewModel(
            modelManager: StubInferenceProviderModelManager(validation: ModelValidationResult(missingModelIDs: [], invalidModelIDs: [])),
            inferenceProviderStore: providerStore,
            summarizationModelStore: summarizationStore,
            summarizationContextWindowStore: SummarizationContextWindowSelectionStore(defaults: defaults, key: "ctx"),
            visionModelStore: visionStore,
            transcriptionModelStore: TranscriptionModelSelectionStore(defaults: defaults, key: "trans"),
            transcriptionBackendStore: TranscriptionBackendSelectionStore(defaults: defaults, key: "backend"),
            fluidAudioModelStore: FluidAudioASRModelSelectionStore(defaults: defaults, key: "fluid")
        )

        model.selectedSummarizationProviderID = InferenceProvider.ollama.rawValue
        model.selectedSummarizationOllamaModelTag = "phi4-mini"
        model.selectedVisionProviderID = InferenceProvider.builtIn.rawValue
        model.selectedVisionModelID = VisionModelSelectionStore(defaults: defaults, key: "vision").selectedModel().id

        #expect(providerStore.selectedProvider(for: .summarization) == .ollama)
        #expect(providerStore.selectedOllamaModelTag(for: .summarization) == "phi4-mini")
        #expect(providerStore.selectedProvider(for: .vision) == .builtIn)

        model.selectedVisionProviderID = InferenceProvider.ollama.rawValue
        model.selectedVisionOllamaModelTag = "llava:latest"

        #expect(providerStore.selectedProvider(for: .vision) == .ollama)
        #expect(providerStore.selectedOllamaModelTag(for: .vision) == "llava:latest")
        #expect(providerStore.selectedOllamaModelTag(for: .summarization) == "phi4-mini")
    }

    @Test
    func restoringPersistedVisionSelection_updatesSettingsState() async throws {
        let suite = "ModelsSettingsInferenceProviderTests.restore.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defaults.removePersistentDomain(forName: suite)

        let providerStore = InferenceProviderSelectionStore(defaults: defaults)
        providerStore.setSelectedProvider(.ollama, for: .vision)
        providerStore.setSelectedOllamaModelTag("llava:13b", for: .vision)
        let visionStore = VisionModelSelectionStore(defaults: defaults, key: "vision")
        let builtInVision = visionStore.selectedModel()

        let model = ModelsSettingsViewModel(
            modelManager: StubInferenceProviderModelManager(validation: ModelValidationResult(missingModelIDs: [], invalidModelIDs: [])),
            inferenceProviderStore: providerStore,
            summarizationModelStore: SummarizationModelSelectionStore(defaults: defaults, key: "sum"),
            summarizationContextWindowStore: SummarizationContextWindowSelectionStore(defaults: defaults, key: "ctx"),
            visionModelStore: visionStore,
            transcriptionModelStore: TranscriptionModelSelectionStore(defaults: defaults, key: "trans"),
            transcriptionBackendStore: TranscriptionBackendSelectionStore(defaults: defaults, key: "backend"),
            fluidAudioModelStore: FluidAudioASRModelSelectionStore(defaults: defaults, key: "fluid")
        )

        #expect(model.selectedVisionProviderID == InferenceProvider.ollama.rawValue)
        #expect(model.selectedVisionOllamaModelTag == "llava:13b")
        #expect(model.selectedVisionModelID == builtInVision.id)
        #expect(model.isBuiltInVisionProviderSelected == false)
    }

    @Test
    func lmStudioCapabilitySelectionsPersistIndependently() async throws {
        let suite = "ModelsSettingsInferenceProviderTests.lmstudio.persist.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defaults.removePersistentDomain(forName: suite)

        let providerStore = InferenceProviderSelectionStore(defaults: defaults)
        let summarizationStore = SummarizationModelSelectionStore(defaults: defaults, key: "sum")
        let visionStore = VisionModelSelectionStore(defaults: defaults, key: "vision")

        let model = ModelsSettingsViewModel(
            modelManager: StubInferenceProviderModelManager(validation: ModelValidationResult(missingModelIDs: [], invalidModelIDs: [])),
            inferenceProviderStore: providerStore,
            summarizationModelStore: summarizationStore,
            summarizationContextWindowStore: SummarizationContextWindowSelectionStore(defaults: defaults, key: "ctx"),
            visionModelStore: visionStore,
            transcriptionModelStore: TranscriptionModelSelectionStore(defaults: defaults, key: "trans"),
            transcriptionBackendStore: TranscriptionBackendSelectionStore(defaults: defaults, key: "backend"),
            fluidAudioModelStore: FluidAudioASRModelSelectionStore(defaults: defaults, key: "fluid")
        )

        model.selectedSummarizationProviderID = InferenceProvider.lmStudio.rawValue
        model.selectedSummarizationLMStudioModelIdentifier = "qwen2.5-7b-instruct"
        model.selectedVisionProviderID = InferenceProvider.ollama.rawValue
        model.selectedVisionOllamaModelTag = "llava:latest"

        #expect(providerStore.selectedProvider(for: .summarization) == .lmStudio)
        #expect(providerStore.selectedLMStudioModelIdentifier(for: .summarization) == "qwen2.5-7b-instruct")
        #expect(providerStore.selectedProvider(for: .vision) == .ollama)
        #expect(providerStore.selectedOllamaModelTag(for: .vision) == "llava:latest")
    }

    @Test
    func restoringPersistedLMStudioVisionSelection_updatesSettingsState() async throws {
        let suite = "ModelsSettingsInferenceProviderTests.lmstudio.restore.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defaults.removePersistentDomain(forName: suite)

        let providerStore = InferenceProviderSelectionStore(defaults: defaults)
        providerStore.setSelectedProvider(.lmStudio, for: .vision)
        providerStore.setSelectedLMStudioModelIdentifier("qwen2.5-vl-7b", for: .vision)
        let visionStore = VisionModelSelectionStore(defaults: defaults, key: "vision")
        let builtInVision = visionStore.selectedModel()

        let model = ModelsSettingsViewModel(
            modelManager: StubInferenceProviderModelManager(validation: ModelValidationResult(missingModelIDs: [], invalidModelIDs: [])),
            inferenceProviderStore: providerStore,
            summarizationModelStore: SummarizationModelSelectionStore(defaults: defaults, key: "sum"),
            summarizationContextWindowStore: SummarizationContextWindowSelectionStore(defaults: defaults, key: "ctx"),
            visionModelStore: visionStore,
            transcriptionModelStore: TranscriptionModelSelectionStore(defaults: defaults, key: "trans"),
            transcriptionBackendStore: TranscriptionBackendSelectionStore(defaults: defaults, key: "backend"),
            fluidAudioModelStore: FluidAudioASRModelSelectionStore(defaults: defaults, key: "fluid")
        )

        #expect(model.selectedVisionProviderID == InferenceProvider.lmStudio.rawValue)
        #expect(model.selectedVisionLMStudioModelIdentifier == "qwen2.5-vl-7b")
        #expect(model.selectedVisionModelID == builtInVision.id)
    }

    @Test
    func lmStudioSelectionsPersistIndependentlyAcrossCapabilities() async throws {
        let suite = "ModelsSettingsInferenceProviderTests.lmstudio.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defaults.removePersistentDomain(forName: suite)

        let providerStore = InferenceProviderSelectionStore(defaults: defaults)
        let connectionStore = ProviderConnectionSettingsStore(defaults: defaults)

        let model = ModelsSettingsViewModel(
            modelManager: StubInferenceProviderModelManager(validation: ModelValidationResult(missingModelIDs: [], invalidModelIDs: [])),
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
        model.selectedSummarizationLMStudioModelIdentifier = "qwen2.5-7b-instruct"
        model.selectedLMStudioBaseURLString = "http://127.0.0.1:1234"
        model.selectedVisionProviderID = InferenceProvider.lmStudio.rawValue
        model.selectedVisionLMStudioModelIdentifier = "qwen2.5-vl-7b"

        #expect(providerStore.selectedLMStudioModelIdentifier(for: .summarization) == "qwen2.5-7b-instruct")
        #expect(providerStore.selectedLMStudioModelIdentifier(for: .vision) == "qwen2.5-vl-7b")
        #expect(connectionStore.selectedBaseURLString(for: .lmStudio) == "http://127.0.0.1:1234")

        model.selectedVisionProviderID = InferenceProvider.builtIn.rawValue

        #expect(providerStore.selectedProvider(for: .vision) == .builtIn)
        #expect(providerStore.selectedLMStudioModelIdentifier(for: .summarization) == "qwen2.5-7b-instruct")
        #expect(providerStore.selectedLMStudioModelIdentifier(for: .vision) == "qwen2.5-vl-7b")
    }

    @Test
    func invalidOllamaVisionSelection_preservesTagAndExposesValidationState() async throws {
        let suite = "ModelsSettingsInferenceProviderTests.validation.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defaults.removePersistentDomain(forName: suite)

        let providerStore = InferenceProviderSelectionStore(defaults: defaults)
        providerStore.setSelectedProvider(.ollama, for: .vision)
        providerStore.setSelectedOllamaModelTag("phi4-mini", for: .vision)

        let model = ModelsSettingsViewModel(
            modelManager: StubInferenceProviderModelManager(validation: ModelValidationResult(missingModelIDs: [], invalidModelIDs: [])),
            inferenceProviderStore: providerStore,
            summarizationModelStore: SummarizationModelSelectionStore(defaults: defaults, key: "sum"),
            summarizationContextWindowStore: SummarizationContextWindowSelectionStore(defaults: defaults, key: "ctx"),
            visionModelStore: VisionModelSelectionStore(defaults: defaults, key: "vision"),
            transcriptionModelStore: TranscriptionModelSelectionStore(defaults: defaults, key: "trans"),
            transcriptionBackendStore: TranscriptionBackendSelectionStore(defaults: defaults, key: "backend"),
            fluidAudioModelStore: FluidAudioASRModelSelectionStore(defaults: defaults, key: "fluid"),
            availabilityProvider: StubCapabilityAvailabilityProvider(
                summarizationState: .ready(.summarization, reference: SummarizationModelCatalog.defaultModel.id),
                visionState: CapabilityAvailabilityState(
                    capabilityID: .vision,
                    providerID: .ollama,
                    isReady: false,
                    status: .visionUnsupported,
                    message: "Selected Ollama model does not advertise vision support.",
                    selectedReference: "phi4-mini"
                )
            ),
            ollamaModelDiscoverer: StubOllamaModelDiscoverer(
                snapshot: OllamaDiscoverySnapshot(
                    daemonReachable: true,
                    models: [OllamaModelDescriptor(tag: "phi4-mini", displayName: "phi4-mini", digest: "sha", sizeBytes: 1)]
                )
            )
        )

        try await eventually(timeoutNanoseconds: 1_000_000_000) {
            await MainActor.run {
                model.visionAvailabilityState.status == .visionUnsupported &&
                model.ollamaDiscoveredModelTags == ["phi4-mini"]
            }
        }

        #expect(model.selectedVisionOllamaModelTag == "phi4-mini")
        #expect(model.visionAvailabilityState.status == .visionUnsupported)
        #expect(model.ollamaDiscoveredModelTags == ["phi4-mini"])
    }

    @Test
    func invalidLMStudioVisionSelection_preservesIdentifierAndExposesValidationState() async throws {
        let suite = "ModelsSettingsInferenceProviderTests.lmstudio.validation.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defaults.removePersistentDomain(forName: suite)

        let providerStore = InferenceProviderSelectionStore(defaults: defaults)
        providerStore.setSelectedProvider(.lmStudio, for: .vision)
        providerStore.setSelectedLMStudioModelIdentifier("qwen2.5-7b-instruct", for: .vision)

        let model = ModelsSettingsViewModel(
            modelManager: StubInferenceProviderModelManager(validation: ModelValidationResult(missingModelIDs: [], invalidModelIDs: [])),
            inferenceProviderStore: providerStore,
            summarizationModelStore: SummarizationModelSelectionStore(defaults: defaults, key: "sum"),
            summarizationContextWindowStore: SummarizationContextWindowSelectionStore(defaults: defaults, key: "ctx"),
            visionModelStore: VisionModelSelectionStore(defaults: defaults, key: "vision"),
            transcriptionModelStore: TranscriptionModelSelectionStore(defaults: defaults, key: "trans"),
            transcriptionBackendStore: TranscriptionBackendSelectionStore(defaults: defaults, key: "backend"),
            fluidAudioModelStore: FluidAudioASRModelSelectionStore(defaults: defaults, key: "fluid"),
            availabilityProvider: StubCapabilityAvailabilityProvider(
                summarizationState: .ready(.summarization, reference: SummarizationModelCatalog.defaultModel.id),
                visionState: CapabilityAvailabilityState(
                    capabilityID: .vision,
                    providerID: .lmStudio,
                    isReady: false,
                    status: .visionUnsupported,
                    message: "Selected LM Studio model does not advertise vision support.",
                    selectedReference: "qwen2.5-7b-instruct"
                )
            ),
            lmStudioModelDiscoverer: StubLMStudioModelDiscoverer(
                snapshot: LMStudioDiscoverySnapshot(
                    serverReachable: true,
                    models: [LMStudioModelDescriptor(identifier: "qwen2.5-7b-instruct", displayName: "qwen2.5-7b-instruct", modelType: "llm")]
                )
            )
        )

        try await eventually(timeoutNanoseconds: 1_000_000_000) {
            await MainActor.run {
                model.visionAvailabilityState.status == .visionUnsupported &&
                model.lmStudioDiscoveredModelIdentifiers == ["qwen2.5-7b-instruct"]
            }
        }

        #expect(model.selectedVisionLMStudioModelIdentifier == "qwen2.5-7b-instruct")
        #expect(model.visionAvailabilityState.status == .visionUnsupported)
        #expect(model.lmStudioDiscoveredModelIdentifiers == ["qwen2.5-7b-instruct"])
    }
}

private struct StubInferenceProviderModelManager: ModelManaging {
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

private struct StubCapabilityAvailabilityProvider: CapabilityAvailabilityProviding {
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

private struct StubOllamaModelDiscoverer: OllamaModelDiscovering {
    var snapshot: OllamaDiscoverySnapshot

    func discoverModels() async throws -> OllamaDiscoverySnapshot {
        snapshot
    }

    func validateModelTag(_ tag: String, for capability: InferenceCapability) async throws -> CapabilityAvailabilityState {
        .ready(capability, reference: tag, provider: .ollama)
    }
}

private struct StubLMStudioModelDiscoverer: LMStudioModelDiscovering {
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
