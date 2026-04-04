import Foundation

public struct InferenceRuntimeFactory: Sendable, CapabilityAvailabilityProviding {
    public typealias BuiltInSummarizationBuilder =
        @Sendable (SummarizationModelSelectionStore, SummarizationContextWindowSelectionStore, SummarizationHardwareProfile) -> any SummarizationServicing
    public typealias OllamaSummarizationBuilder = @Sendable (String, URL?) -> any SummarizationServicing
    public typealias LMStudioSummarizationBuilder = @Sendable (String, URL?) -> any SummarizationServicing
    public typealias BuiltInVisionBuilder = @Sendable (VisionModelSelectionStore) -> any ScreenContextInferencing
    public typealias OllamaVisionBuilder = @Sendable (String, URL?) -> any ScreenContextInferencing
    public typealias LMStudioVisionBuilder = @Sendable (String, URL?) -> any ScreenContextInferencing

    private let providerStore: InferenceProviderSelectionStore
    private let connectionStore: ProviderConnectionSettingsStore
    private let summarizationModelStore: SummarizationModelSelectionStore
    private let summarizationContextWindowStore: SummarizationContextWindowSelectionStore
    private let visionModelStore: VisionModelSelectionStore
    private let hardwareProfileProvider: @Sendable () -> SummarizationHardwareProfile
    private let dateProvider: @Sendable () -> Date
    private let builtInSummarizationBuilder: BuiltInSummarizationBuilder
    private let ollamaSummarizationBuilder: OllamaSummarizationBuilder
    private let lmStudioSummarizationBuilder: LMStudioSummarizationBuilder
    private let builtInVisionBuilder: BuiltInVisionBuilder
    private let ollamaVisionBuilder: OllamaVisionBuilder
    private let lmStudioVisionBuilder: LMStudioVisionBuilder
    private let ollamaModelDiscoverer: (any OllamaModelDiscovering)?
    private let lmStudioModelDiscoverer: (any LMStudioModelDiscovering)?

    public init(
        providerStore: InferenceProviderSelectionStore = InferenceProviderSelectionStore(),
        connectionStore: ProviderConnectionSettingsStore = ProviderConnectionSettingsStore(),
        summarizationModelStore: SummarizationModelSelectionStore = SummarizationModelSelectionStore(),
        summarizationContextWindowStore: SummarizationContextWindowSelectionStore = SummarizationContextWindowSelectionStore(),
        visionModelStore: VisionModelSelectionStore = VisionModelSelectionStore(),
        hardwareProfileProvider: @escaping @Sendable () -> SummarizationHardwareProfile = { .current() },
        dateProvider: @escaping @Sendable () -> Date = Date.init,
        builtInSummarizationBuilder: @escaping BuiltInSummarizationBuilder = { _, _, _ in MissingSummarizationService() },
        ollamaSummarizationBuilder: @escaping OllamaSummarizationBuilder = { _, _ in MissingSummarizationService() },
        lmStudioSummarizationBuilder: @escaping LMStudioSummarizationBuilder = { _, _ in MissingSummarizationService() },
        builtInVisionBuilder: @escaping BuiltInVisionBuilder = { _ in MissingScreenContextInferenceService() },
        ollamaVisionBuilder: @escaping OllamaVisionBuilder = { _, _ in MissingScreenContextInferenceService() },
        lmStudioVisionBuilder: @escaping LMStudioVisionBuilder = { _, _ in MissingScreenContextInferenceService() },
        ollamaModelDiscoverer: (any OllamaModelDiscovering)? = nil,
        lmStudioModelDiscoverer: (any LMStudioModelDiscovering)? = nil
    ) {
        self.providerStore = providerStore
        self.connectionStore = connectionStore
        self.summarizationModelStore = summarizationModelStore
        self.summarizationContextWindowStore = summarizationContextWindowStore
        self.visionModelStore = visionModelStore
        self.hardwareProfileProvider = hardwareProfileProvider
        self.dateProvider = dateProvider
        self.builtInSummarizationBuilder = builtInSummarizationBuilder
        self.ollamaSummarizationBuilder = ollamaSummarizationBuilder
        self.lmStudioSummarizationBuilder = lmStudioSummarizationBuilder
        self.builtInVisionBuilder = builtInVisionBuilder
        self.ollamaVisionBuilder = ollamaVisionBuilder
        self.lmStudioVisionBuilder = lmStudioVisionBuilder
        self.ollamaModelDiscoverer = ollamaModelDiscoverer
        self.lmStudioModelDiscoverer = lmStudioModelDiscoverer
    }

    public func resolveBinding(for capability: InferenceCapability) throws -> InferenceTaskBinding {
        let provider = providerStore.selectedProvider(for: capability)
        switch (capability, provider) {
        case (.summarization, .builtIn):
            let model = summarizationModelStore.selectedModel()
            return InferenceTaskBinding(
                capabilityID: capability,
                providerID: provider,
                providerReference: model.id,
                connectionBaseURLString: nil,
                capturedAt: dateProvider(),
                supportsVisionInputs: false
            )
        case (.vision, .builtIn):
            let model = visionModelStore.selectedModel()
            guard model.mmprojDestinationURL != nil else {
                throw MinuteError.mmprojMissing
            }
            return InferenceTaskBinding(
                capabilityID: capability,
                providerID: provider,
                providerReference: model.id,
                connectionBaseURLString: nil,
                capturedAt: dateProvider(),
                supportsVisionInputs: true
            )
        case (_, .ollama):
            guard let tag = providerStore.selectedOllamaModelTag(for: capability), !tag.isEmpty else {
                throw MinuteError.modelMissing
            }
            return InferenceTaskBinding(
                capabilityID: capability,
                providerID: provider,
                providerReference: tag,
                connectionBaseURLString: connectionStore.selectedBaseURLString(for: .ollama),
                capturedAt: dateProvider(),
                supportsVisionInputs: capability == .vision
            )
        case (_, .lmStudio):
            guard let identifier = providerStore.selectedLMStudioModelIdentifier(for: capability), !identifier.isEmpty else {
                throw MinuteError.modelMissing
            }
            return InferenceTaskBinding(
                capabilityID: capability,
                providerID: provider,
                providerReference: identifier,
                connectionBaseURLString: connectionStore.selectedBaseURLString(for: .lmStudio),
                capturedAt: dateProvider(),
                supportsVisionInputs: capability == .vision
            )
        }
    }

    public func makeSummarizationService() throws -> any SummarizationServicing {
        let binding = try resolveBinding(for: .summarization)
        return try makeSummarizationService(binding: binding)
    }

    public func makeSummarizationService(binding: InferenceTaskBinding) throws -> any SummarizationServicing {
        guard binding.capabilityID == .summarization else {
            throw MinuteError.modelMissing
        }
        switch binding.providerID {
        case .builtIn:
            return builtInSummarizationBuilder(
                summarizationModelStore,
                summarizationContextWindowStore,
                hardwareProfileProvider()
            )
        case .ollama:
            return ollamaSummarizationBuilder(binding.providerReference, resolvedConnectionURL(for: binding))
        case .lmStudio:
            return lmStudioSummarizationBuilder(binding.providerReference, resolvedConnectionURL(for: binding))
        }
    }

    public func makeScreenContextInferencer() throws -> any ScreenContextInferencing {
        let binding = try resolveBinding(for: .vision)
        return try makeScreenContextInferencer(binding: binding)
    }

    public func makeScreenContextInferencer(binding: InferenceTaskBinding) throws -> any ScreenContextInferencing {
        guard binding.capabilityID == .vision else {
            throw MinuteError.modelMissing
        }
        switch binding.providerID {
        case .builtIn:
            return builtInVisionBuilder(visionModelStore)
        case .ollama:
            return ollamaVisionBuilder(binding.providerReference, resolvedConnectionURL(for: binding))
        case .lmStudio:
            return lmStudioVisionBuilder(binding.providerReference, resolvedConnectionURL(for: binding))
        }
    }

    public func preflightConfiguration(for binding: InferenceTaskBinding) -> SummarizationPreflightConfiguration {
        switch binding.providerID {
        case .builtIn:
            return SummarizationPreflightConfiguration(
                contextWindowTokens: summarizationContextWindowStore.requestedContextTokens(
                    hardwareProfile: hardwareProfileProvider()
                ),
                reservedOutputTokens: 1_024
            )
        case .ollama, .lmStudio:
            return .default
        }
    }

    public func availability(for capability: InferenceCapability) async throws -> CapabilityAvailabilityState {
        let provider = providerStore.selectedProvider(for: capability)
        switch (capability, provider) {
        case (.summarization, .builtIn):
            let model = summarizationModelStore.selectedModel()
            return CapabilityAvailabilityState(
                capabilityID: capability,
                providerID: provider,
                isReady: true,
                status: .ready,
                message: "Using built-in model \(model.displayName).",
                selectedReference: model.id
            )
        case (.vision, .builtIn):
            let model = visionModelStore.selectedModel()
            guard model.mmprojDestinationURL != nil else {
                return CapabilityAvailabilityState(
                    capabilityID: capability,
                    providerID: provider,
                    isReady: false,
                    status: .unsupported,
                    message: "Selected built-in vision model is missing multimodal support.",
                    selectedReference: model.id
                )
            }
            return CapabilityAvailabilityState(
                capabilityID: capability,
                providerID: provider,
                isReady: true,
                status: .ready,
                message: "Using built-in vision model \(model.displayName).",
                selectedReference: model.id
            )
        case (_, .ollama):
            let trimmedTag = providerStore.selectedOllamaModelTag(for: capability)?
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            guard !trimmedTag.isEmpty else {
                return CapabilityAvailabilityState(
                    capabilityID: capability,
                    providerID: provider,
                    isReady: false,
                    status: .needsConfiguration,
                    message: "Enter an Ollama model tag for \(capability.displayName.lowercased()).",
                    selectedReference: nil
                )
            }
            guard let ollamaModelDiscoverer else {
                return CapabilityAvailabilityState(
                    capabilityID: capability,
                    providerID: provider,
                    isReady: false,
                    status: .unknown,
                    message: "Ollama validation is unavailable.",
                    selectedReference: trimmedTag
                )
            }
            return try await ollamaModelDiscoverer.validateModelTag(trimmedTag, for: capability)
        case (_, .lmStudio):
            let trimmedIdentifier = providerStore.selectedLMStudioModelIdentifier(for: capability)?
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            guard !trimmedIdentifier.isEmpty else {
                return CapabilityAvailabilityState(
                    capabilityID: capability,
                    providerID: provider,
                    isReady: false,
                    status: .needsConfiguration,
                    message: "Choose an LM Studio model for \(capability.displayName.lowercased()).",
                    selectedReference: nil
                )
            }
            guard let lmStudioModelDiscoverer else {
                return CapabilityAvailabilityState(
                    capabilityID: capability,
                    providerID: provider,
                    isReady: false,
                    status: .unknown,
                    message: "LM Studio validation is unavailable.",
                    selectedReference: trimmedIdentifier
                )
            }
            return try await lmStudioModelDiscoverer.validateModelIdentifier(trimmedIdentifier, for: capability)
        }
    }

    private func resolvedConnectionURL(for binding: InferenceTaskBinding) -> URL? {
        if let connectionBaseURLString = binding.connectionBaseURLString,
           let url = URL(string: connectionBaseURLString) {
            return url
        }

        switch binding.providerID {
        case .builtIn:
            return nil
        case .ollama, .lmStudio:
            return connectionStore.selectedBaseURL(for: binding.providerID)
        }
    }
}
