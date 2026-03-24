import Foundation
import Testing
@testable import MinuteCore

struct InferenceRuntimeFactoryTests {
    @Test
    func resolvesBuiltInBindingsForDefaults() throws {
        let defaults = makeDefaults()
        let providerStore = InferenceProviderSelectionStore(defaults: defaults)
        let summarizationStore = SummarizationModelSelectionStore(defaults: defaults)
        let visionStore = VisionModelSelectionStore(defaults: defaults)
        let factory = InferenceRuntimeFactory(
            providerStore: providerStore,
            summarizationModelStore: summarizationStore,
            visionModelStore: visionStore,
            dateProvider: { Date(timeIntervalSince1970: 123) }
        )

        let summarization = try factory.resolveBinding(for: .summarization)
        let vision = try factory.resolveBinding(for: .vision)

        #expect(summarization.providerID == .builtIn)
        #expect(summarization.providerReference == SummarizationModelCatalog.defaultModel.id)
        #expect(summarization.supportsVisionInputs == false)
        #expect(vision.providerID == .builtIn)
        #expect(vision.providerReference == VisionModelSelectionStore(defaults: defaults).selectedModel().id)
        #expect(vision.supportsVisionInputs == true)
    }

    @Test
    func resolvesOllamaBindingsPerCapability() throws {
        let defaults = makeDefaults()
        let providerStore = InferenceProviderSelectionStore(defaults: defaults)
        providerStore.setSelectedProvider(.ollama, for: .summarization)
        providerStore.setSelectedOllamaModelTag("phi4", for: .summarization)
        providerStore.setSelectedProvider(.ollama, for: .vision)
        providerStore.setSelectedOllamaModelTag("llava", for: .vision)

        let factory = InferenceRuntimeFactory(
            providerStore: providerStore,
            summarizationModelStore: SummarizationModelSelectionStore(defaults: defaults),
            visionModelStore: VisionModelSelectionStore(defaults: defaults)
        )

        let summarization = try factory.resolveBinding(for: .summarization)
        let vision = try factory.resolveBinding(for: .vision)

        #expect(summarization.providerID == .ollama)
        #expect(summarization.providerReference == "phi4")
        #expect(summarization.supportsVisionInputs == false)
        #expect(vision.providerID == .ollama)
        #expect(vision.providerReference == "llava")
        #expect(vision.supportsVisionInputs == true)
    }

    @Test
    func makesServicesUsingMatchingBuilders() throws {
        let defaults = makeDefaults()
        let providerStore = InferenceProviderSelectionStore(defaults: defaults)
        providerStore.setSelectedProvider(.ollama, for: .summarization)
        providerStore.setSelectedOllamaModelTag("phi4", for: .summarization)
        providerStore.setSelectedProvider(.builtIn, for: .vision)
        let summarizationService = MockSummarizationService()
        let visionService = MockScreenContextInferenceService()

        let factory = InferenceRuntimeFactory(
            providerStore: providerStore,
            summarizationModelStore: SummarizationModelSelectionStore(defaults: defaults),
            visionModelStore: VisionModelSelectionStore(defaults: defaults),
            builtInSummarizationBuilder: { _, _, _ in MissingSummarizationService() },
            ollamaSummarizationBuilder: { tag in
                #expect(tag == "phi4")
                return summarizationService
            },
            builtInVisionBuilder: { _ in visionService },
            ollamaVisionBuilder: { _ in MissingScreenContextInferenceService() }
        )

        let resolvedSummarization = try factory.makeSummarizationService()
        let resolvedVision = try factory.makeScreenContextInferencer()

        #expect(type(of: resolvedSummarization) == type(of: summarizationService))
        #expect(type(of: resolvedVision) == type(of: visionService))
    }

    @Test
    func builtInSummarizationUsesModelContextWhileOllamaUsesSavedTag() throws {
        let defaults = makeDefaults()
        let providerStore = InferenceProviderSelectionStore(defaults: defaults)
        let summarizationStore = SummarizationModelSelectionStore(defaults: defaults)
        let contextWindowStore = SummarizationContextWindowSelectionStore(defaults: defaults)
        let builtInService = MockSummarizationService()
        let ollamaService = MockSummarizationService()

        let factory = InferenceRuntimeFactory(
            providerStore: providerStore,
            summarizationModelStore: summarizationStore,
            summarizationContextWindowStore: contextWindowStore,
            visionModelStore: VisionModelSelectionStore(defaults: defaults),
            builtInSummarizationBuilder: { store, _, _ in
                #expect(store.selectedModel().id == summarizationStore.selectedModel().id)
                return builtInService
            },
            ollamaSummarizationBuilder: { tag in
                #expect(tag == "phi4-mini")
                return ollamaService
            }
        )

        let initial = try factory.makeSummarizationService()
        #expect(type(of: initial) == type(of: builtInService))

        providerStore.setSelectedProvider(.ollama, for: .summarization)
        providerStore.setSelectedOllamaModelTag("phi4-mini", for: .summarization)

        let updated = try factory.makeSummarizationService()
        let binding = try factory.resolveBinding(for: .summarization)

        #expect(type(of: updated) == type(of: ollamaService))
        #expect(binding.providerID == .ollama)
        #expect(binding.providerReference == "phi4-mini")
    }

    @Test
    func builtInAndOllamaVisionBindingsResolveIndependently() throws {
        let defaults = makeDefaults()
        let providerStore = InferenceProviderSelectionStore(defaults: defaults)
        let visionStore = VisionModelSelectionStore(defaults: defaults)
        providerStore.setSelectedProvider(.builtIn, for: .summarization)
        providerStore.setSelectedProvider(.ollama, for: .vision)
        providerStore.setSelectedOllamaModelTag("llava:latest", for: .vision)
        let builtInVision = visionStore.selectedModel()
        let ollamaVisionService = MockScreenContextInferenceService()

        let factory = InferenceRuntimeFactory(
            providerStore: providerStore,
            summarizationModelStore: SummarizationModelSelectionStore(defaults: defaults),
            summarizationContextWindowStore: SummarizationContextWindowSelectionStore(defaults: defaults),
            visionModelStore: visionStore,
            builtInVisionBuilder: { store in
                #expect(store.selectedModel().id == builtInVision.id)
                return MissingScreenContextInferenceService()
            },
            ollamaVisionBuilder: { tag in
                #expect(tag == "llava:latest")
                return ollamaVisionService
            }
        )

        let visionBinding = try factory.resolveBinding(for: .vision)
        let visionService = try factory.makeScreenContextInferencer()
        let summarizationBinding = try factory.resolveBinding(for: .summarization)

        #expect(visionBinding.providerID == .ollama)
        #expect(visionBinding.providerReference == "llava:latest")
        #expect(type(of: visionService) == type(of: ollamaVisionService))
        #expect(summarizationBinding.providerID == .builtIn)
    }

    @Test
    func availability_reportsNeedsConfigurationForMissingOllamaTag() async throws {
        let defaults = makeDefaults()
        let providerStore = InferenceProviderSelectionStore(defaults: defaults)
        providerStore.setSelectedProvider(.ollama, for: .summarization)
        let factory = InferenceRuntimeFactory(
            providerStore: providerStore,
            summarizationModelStore: SummarizationModelSelectionStore(defaults: defaults),
            visionModelStore: VisionModelSelectionStore(defaults: defaults)
        )

        let state = try await factory.availability(for: .summarization)

        #expect(state.status == .needsConfiguration)
        #expect(state.isReady == false)
    }

    @Test
    func availability_usesOllamaValidatorForVisionCapability() async throws {
        let defaults = makeDefaults()
        let providerStore = InferenceProviderSelectionStore(defaults: defaults)
        providerStore.setSelectedProvider(.ollama, for: .vision)
        providerStore.setSelectedOllamaModelTag("phi4-mini", for: .vision)
        let discoverer = StubOllamaModelDiscoverer(
            validationState: CapabilityAvailabilityState(
                capabilityID: .vision,
                providerID: .ollama,
                isReady: false,
                status: .visionUnsupported,
                message: "No vision support",
                selectedReference: "phi4-mini"
            )
        )
        let factory = InferenceRuntimeFactory(
            providerStore: providerStore,
            summarizationModelStore: SummarizationModelSelectionStore(defaults: defaults),
            visionModelStore: VisionModelSelectionStore(defaults: defaults),
            ollamaModelDiscoverer: discoverer
        )

        let state = try await factory.availability(for: .vision)

        #expect(state.status == .visionUnsupported)
        #expect(discoverer.validatedTags.count == 1)
        #expect(discoverer.validatedTags.first?.0 == .vision)
        #expect(discoverer.validatedTags.first?.1 == "phi4-mini")
    }

    private func makeDefaults() -> UserDefaults {
        let suiteName = "InferenceRuntimeFactoryTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }
}

private final class StubOllamaModelDiscoverer: OllamaModelDiscovering, @unchecked Sendable {
    let validationState: CapabilityAvailabilityState
    private(set) var validatedTags: [(InferenceCapability, String)] = []

    init(validationState: CapabilityAvailabilityState) {
        self.validationState = validationState
    }

    func discoverModels() async throws -> OllamaDiscoverySnapshot {
        OllamaDiscoverySnapshot(daemonReachable: true)
    }

    func validateModelTag(_ tag: String, for capability: InferenceCapability) async throws -> CapabilityAvailabilityState {
        validatedTags.append((capability, tag))
        return validationState
    }
}
