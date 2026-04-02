import Foundation

public final class ProviderConnectionSettingsStore: @unchecked Sendable {
    private let defaults: UserDefaults
    private let keys: [InferenceProvider: String]
    private let defaultBaseURLStrings: [InferenceProvider: String]

    public init(
        defaults: UserDefaults = .standard,
        keys: [InferenceProvider: String] = [
            .ollama: AppConfiguration.Defaults.ollamaBaseURLKey,
            .lmStudio: AppConfiguration.Defaults.lmStudioBaseURLKey,
        ],
        defaultBaseURLStrings: [InferenceProvider: String] = [
            .ollama: AppConfiguration.Defaults.defaultOllamaBaseURL,
            .lmStudio: AppConfiguration.Defaults.defaultLMStudioBaseURL,
        ]
    ) {
        self.defaults = defaults
        self.keys = keys
        self.defaultBaseURLStrings = defaultBaseURLStrings
    }

    public func selectedBaseURLString(for provider: InferenceProvider) -> String {
        let fallback = defaultBaseURLStrings[provider] ?? AppConfiguration.Defaults.defaultOllamaBaseURL
        guard let key = keys[provider] else { return fallback }
        return AppConfiguration.validatedLocalServerBaseURL(
            defaults.string(forKey: key),
            fallback: fallback
        )
    }

    public func selectedBaseURL(for provider: InferenceProvider) -> URL? {
        URL(string: selectedBaseURLString(for: provider))
    }

    public func setSelectedBaseURLString(_ value: String?, for provider: InferenceProvider) {
        guard let key = keys[provider] else { return }
        let fallback = defaultBaseURLStrings[provider] ?? AppConfiguration.Defaults.defaultOllamaBaseURL
        let normalized = AppConfiguration.validatedLocalServerBaseURL(value, fallback: fallback)
        if normalized == fallback {
            defaults.removeObject(forKey: key)
        } else {
            defaults.set(normalized, forKey: key)
        }
    }
}
