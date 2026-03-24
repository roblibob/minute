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
