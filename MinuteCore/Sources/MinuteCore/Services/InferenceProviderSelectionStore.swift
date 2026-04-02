import Foundation

public final class InferenceProviderSelectionStore: @unchecked Sendable {
    private let defaults: UserDefaults
    private let providerKeys: [InferenceCapability: String]
    private let ollamaTagKeys: [InferenceCapability: String]
    private let lmStudioModelIdentifierKeys: [InferenceCapability: String]

    public init(
        defaults: UserDefaults = .standard,
        providerKeys: [InferenceCapability: String] = [
            .summarization: AppConfiguration.Defaults.summarizationProviderIDKey,
            .vision: AppConfiguration.Defaults.visionProviderIDKey,
        ],
        ollamaTagKeys: [InferenceCapability: String] = [
            .summarization: AppConfiguration.Defaults.summarizationOllamaModelTagKey,
            .vision: AppConfiguration.Defaults.visionOllamaModelTagKey,
        ],
        lmStudioModelIdentifierKeys: [InferenceCapability: String] = [
            .summarization: AppConfiguration.Defaults.summarizationLMStudioModelIdentifierKey,
            .vision: AppConfiguration.Defaults.visionLMStudioModelIdentifierKey,
        ]
    ) {
        self.defaults = defaults
        self.providerKeys = providerKeys
        self.ollamaTagKeys = ollamaTagKeys
        self.lmStudioModelIdentifierKeys = lmStudioModelIdentifierKeys
    }

    public func selectedProvider(for capability: InferenceCapability) -> InferenceProvider {
        guard let key = providerKeys[capability],
              let rawValue = defaults.string(forKey: key),
              let provider = InferenceProvider(rawValue: rawValue) else {
            return .builtIn
        }
        return provider
    }

    public func setSelectedProvider(_ provider: InferenceProvider, for capability: InferenceCapability) {
        guard let key = providerKeys[capability] else { return }
        defaults.set(provider.rawValue, forKey: key)
    }

    public func clearSelectedProvider(for capability: InferenceCapability) {
        guard let key = providerKeys[capability] else { return }
        defaults.removeObject(forKey: key)
    }

    public func selectedOllamaModelTag(for capability: InferenceCapability) -> String? {
        guard let key = ollamaTagKeys[capability] else { return nil }
        return normalizedOptionalString(forKey: key)
    }

    public func setSelectedOllamaModelTag(_ tag: String?, for capability: InferenceCapability) {
        guard let key = ollamaTagKeys[capability] else { return }
        setNormalizedOptionalString(tag, forKey: key)
    }

    public func clearSelectedOllamaModelTag(for capability: InferenceCapability) {
        guard let key = ollamaTagKeys[capability] else { return }
        defaults.removeObject(forKey: key)
    }

    public func selectedLMStudioModelIdentifier(for capability: InferenceCapability) -> String? {
        guard let key = lmStudioModelIdentifierKeys[capability] else { return nil }
        return normalizedOptionalString(forKey: key)
    }

    public func setSelectedLMStudioModelIdentifier(_ identifier: String?, for capability: InferenceCapability) {
        guard let key = lmStudioModelIdentifierKeys[capability] else { return }
        setNormalizedOptionalString(identifier, forKey: key)
    }

    public func clearSelectedLMStudioModelIdentifier(for capability: InferenceCapability) {
        guard let key = lmStudioModelIdentifierKeys[capability] else { return }
        defaults.removeObject(forKey: key)
    }

    public func selectedProviderReference(
        for capability: InferenceCapability,
        provider: InferenceProvider
    ) -> String? {
        switch provider {
        case .builtIn:
            return nil
        case .ollama:
            return selectedOllamaModelTag(for: capability)
        case .lmStudio:
            return selectedLMStudioModelIdentifier(for: capability)
        }
    }

    public func setSelectedProviderReference(
        _ reference: String?,
        for capability: InferenceCapability,
        provider: InferenceProvider
    ) {
        switch provider {
        case .builtIn:
            break
        case .ollama:
            setSelectedOllamaModelTag(reference, for: capability)
        case .lmStudio:
            setSelectedLMStudioModelIdentifier(reference, for: capability)
        }
    }

    private func normalizedOptionalString(forKey key: String) -> String? {
        let trimmed = defaults.string(forKey: key)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? nil : trimmed
    }

    private func setNormalizedOptionalString(_ value: String?, forKey key: String) {
        let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if trimmed.isEmpty {
            defaults.removeObject(forKey: key)
        } else {
            defaults.set(trimmed, forKey: key)
        }
    }
}
