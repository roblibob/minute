import Foundation

public final class ScreenContextSettingsStore {
    private let defaults: UserDefaults
    private let enabledKey: String
    private let selectedWindowsKey: String
    private let videoImportEnabledKey: String
    private let captureIntervalSecondsKey: String

    public init(
        defaults: UserDefaults = .standard,
        enabledKey: String = AppConfiguration.Defaults.screenContextEnabledKey,
        selectedWindowsKey: String = AppConfiguration.Defaults.screenContextSelectedWindowsKey,
        videoImportEnabledKey: String = AppConfiguration.Defaults.screenContextVideoImportEnabledKey,
        captureIntervalSecondsKey: String = AppConfiguration.Defaults.screenContextCaptureIntervalSecondsKey
    ) {
        self.defaults = defaults
        self.enabledKey = enabledKey
        self.selectedWindowsKey = selectedWindowsKey
        self.videoImportEnabledKey = videoImportEnabledKey
        self.captureIntervalSecondsKey = captureIntervalSecondsKey
    }

    public var isEnabled: Bool {
        defaults.object(forKey: enabledKey) as? Bool ?? AppConfiguration.Defaults.defaultScreenContextEnabled
    }

    public func setEnabled(_ value: Bool) {
        defaults.set(value, forKey: enabledKey)
    }

    public var isVideoImportEnabled: Bool {
        defaults.object(forKey: videoImportEnabledKey) as? Bool
            ?? AppConfiguration.Defaults.defaultScreenContextVideoImportEnabled
    }

    public func setVideoImportEnabled(_ value: Bool) {
        defaults.set(value, forKey: videoImportEnabledKey)
    }

    public var captureIntervalSeconds: TimeInterval {
        let value = defaults.object(forKey: captureIntervalSecondsKey) as? Double
        let fallback = AppConfiguration.Defaults.defaultScreenContextCaptureIntervalSeconds
        let resolved = value ?? fallback
        return resolved > 0 ? resolved : fallback
    }

    public func setCaptureIntervalSeconds(_ value: TimeInterval) {
        defaults.set(value, forKey: captureIntervalSecondsKey)
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
