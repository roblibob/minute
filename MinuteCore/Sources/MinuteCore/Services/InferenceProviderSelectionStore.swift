import Foundation

public final class InferenceProviderSelectionStore: @unchecked Sendable {
    private let defaults: UserDefaults
    private let providerKeys: [InferenceCapability: String]
    private let ollamaTagKeys: [InferenceCapability: String]

    public init(
        defaults: UserDefaults = .standard,
        providerKeys: [InferenceCapability: String] = [
            .summarization: AppConfiguration.Defaults.summarizationProviderIDKey,
            .vision: AppConfiguration.Defaults.visionProviderIDKey,
        ],
        ollamaTagKeys: [InferenceCapability: String] = [
            .summarization: AppConfiguration.Defaults.summarizationOllamaModelTagKey,
            .vision: AppConfiguration.Defaults.visionOllamaModelTagKey,
        ]
    ) {
        self.defaults = defaults
        self.providerKeys = providerKeys
        self.ollamaTagKeys = ollamaTagKeys
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
        let trimmed = defaults.string(forKey: key)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? nil : trimmed
    }

    public func setSelectedOllamaModelTag(_ tag: String?, for capability: InferenceCapability) {
        guard let key = ollamaTagKeys[capability] else { return }
        let trimmed = tag?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if trimmed.isEmpty {
            defaults.removeObject(forKey: key)
        } else {
            defaults.set(trimmed, forKey: key)
        }
    }

    public func clearSelectedOllamaModelTag(for capability: InferenceCapability) {
        guard let key = ollamaTagKeys[capability] else { return }
        defaults.removeObject(forKey: key)
    }
}
