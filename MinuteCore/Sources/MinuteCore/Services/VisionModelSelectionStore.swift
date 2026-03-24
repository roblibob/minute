import Foundation

public final class VisionModelSelectionStore: @unchecked Sendable {
    private let defaults: UserDefaults
    private let key: String

    public init(
        defaults: UserDefaults = .standard,
        key: String = AppConfiguration.Defaults.visionBuiltInModelIDKey
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

    public func selectedModel() -> SummarizationModel {
        if let selected = SummarizationModelCatalog.model(for: selectedModelID()),
           selected.mmprojDestinationURL != nil {
            return selected
        }
        return SummarizationModelCatalog.all.first(where: { $0.mmprojDestinationURL != nil })
            ?? SummarizationModelCatalog.defaultModel
    }
}
