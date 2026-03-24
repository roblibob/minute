import Foundation

public final class OllamaEndpointSettingsStore: @unchecked Sendable {
    private let defaults: UserDefaults
    private let key: String
    private let defaultBaseURLString: String

    public init(
        defaults: UserDefaults = .standard,
        key: String = AppConfiguration.Defaults.ollamaBaseURLKey,
        defaultBaseURLString: String = AppConfiguration.Defaults.defaultOllamaBaseURL
    ) {
        self.defaults = defaults
        self.key = key
        self.defaultBaseURLString = defaultBaseURLString
    }

    public func selectedBaseURLString() -> String {
        AppConfiguration.validatedOllamaBaseURL(
            defaults.string(forKey: key),
            fallback: defaultBaseURLString
        )
    }

    public func selectedBaseURL() -> URL? {
        URL(string: selectedBaseURLString())
    }

    public func setSelectedBaseURLString(_ value: String?) {
        let normalized = AppConfiguration.validatedOllamaBaseURL(value, fallback: defaultBaseURLString)
        if normalized == defaultBaseURLString {
            defaults.removeObject(forKey: key)
        } else {
            defaults.set(normalized, forKey: key)
        }
    }
}
