import Foundation

public final class FluidAudioASRModelSelectionStore {
    private let defaults: UserDefaults
    private let key: String

    public init(
        defaults: UserDefaults = .standard,
        key: String = AppConfiguration.Defaults.fluidAudioAsrModelIDKey
    ) {
        self.defaults = defaults
        self.key = key
    }

    public func selectedModelID() -> String? {
        defaults.string(forKey: key)
    }

    public func setSelectedModelID(_ id: String) {
        defaults.set(id, forKey: key)
    }

    public func clearSelectedModelID() {
        defaults.removeObject(forKey: key)
    }

    public func selectedModel() -> FluidAudioASRModel {
        FluidAudioASRModelCatalog.model(for: selectedModelID()) ?? FluidAudioASRModelCatalog.defaultModel
    }
}
