import Foundation

public final class ScreenContextSettingsStore {
    private let defaults: UserDefaults
    private let enabledKey: String
    private let selectedWindowsKey: String
    private let videoImportEnabledKey: String

    public init(
        defaults: UserDefaults = .standard,
        enabledKey: String = "screenContextEnabled",
        selectedWindowsKey: String = "screenContextSelectedWindows",
        videoImportEnabledKey: String = "screenContextVideoImportEnabled"
    ) {
        self.defaults = defaults
        self.enabledKey = enabledKey
        self.selectedWindowsKey = selectedWindowsKey
        self.videoImportEnabledKey = videoImportEnabledKey
    }

    public var isEnabled: Bool {
        defaults.object(forKey: enabledKey) as? Bool ?? false
    }

    public func setEnabled(_ value: Bool) {
        defaults.set(value, forKey: enabledKey)
    }

    public var isVideoImportEnabled: Bool {
        defaults.object(forKey: videoImportEnabledKey) as? Bool ?? false
    }

    public func setVideoImportEnabled(_ value: Bool) {
        defaults.set(value, forKey: videoImportEnabledKey)
    }

    public func selectedWindows() -> [ScreenContextWindowSelection] {
        guard let data = defaults.data(forKey: selectedWindowsKey) else { return [] }
        do {
            return try JSONDecoder().decode([ScreenContextWindowSelection].self, from: data)
        } catch {
            return []
        }
    }

    public func setSelectedWindows(_ windows: [ScreenContextWindowSelection]) {
        do {
            let data = try JSONEncoder().encode(windows)
            defaults.set(data, forKey: selectedWindowsKey)
        } catch {
            defaults.removeObject(forKey: selectedWindowsKey)
        }
    }
}
