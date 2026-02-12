import Foundation
import MinuteCore

struct AppDistributionConfiguration: Sendable {
    let profile: DistributionProfile
    let updaterEnabled: Bool

    static func current(bundle: Bundle = .main) -> AppDistributionConfiguration {
        let profileRaw = bundle.object(forInfoDictionaryKey: "MINUTEDistributionProfile") as? String
        let profile = DistributionProfile.resolve(from: profileRaw) ?? .direct

        let updaterRaw = bundle.object(forInfoDictionaryKey: "MINUTEEnableUpdater")
        let updaterEnabled = parseBoolean(updaterRaw, defaultValue: profile == .direct)

        return AppDistributionConfiguration(profile: profile, updaterEnabled: updaterEnabled)
    }

    private static func parseBoolean(_ raw: Any?, defaultValue: Bool) -> Bool {
        switch raw {
        case let value as Bool:
            return value
        case let value as NSNumber:
            return value.boolValue
        case let value as String:
            switch value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
            case "1", "true", "yes", "on":
                return true
            case "0", "false", "no", "off", "":
                return false
            default:
                return defaultValue
            }
        default:
            return defaultValue
        }
    }
}
