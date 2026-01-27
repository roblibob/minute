import Foundation

public final class TranscriptionBackendSelectionStore {
    private let defaults: UserDefaults
    private let key: String

    public init(
        defaults: UserDefaults = .standard,
        key: String = AppConfiguration.Defaults.transcriptionBackendIDKey
    ) {
        self.defaults = defaults
        self.key = key
    }

    public func selectedBackendID() -> String? {
        defaults.string(forKey: key)
    }

    public func setSelectedBackendID(_ id: String) {
        defaults.set(id, forKey: key)
    }

    public func clearSelectedBackendID() {
        defaults.removeObject(forKey: key)
    }

    public func selectedBackend() -> TranscriptionBackend {
        TranscriptionBackend.backend(for: selectedBackendID())
    }
}
