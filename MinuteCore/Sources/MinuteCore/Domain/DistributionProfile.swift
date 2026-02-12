import Foundation

public enum DistributionProfile: String, CaseIterable, Codable, Sendable {
    case appStore = "app-store"
    case direct

    public var updaterPolicy: UpdaterPolicy {
        switch self {
        case .appStore:
            return .disabled
        case .direct:
            return .enabled
        }
    }

    public var requiredValidationChecks: [ReleaseValidationCheckType] {
        switch self {
        case .appStore:
            return [.profileConfig, .signature, .sandboxPolicy, .updaterPolicy, .artifactPolicy]
        case .direct:
            return [.profileConfig, .signature, .updaterPolicy, .artifactPolicy]
        }
    }

    public var allowedArtifacts: Set<ReleaseArtifactType> {
        switch self {
        case .appStore:
            return [.archive, .zip, .submissionMetadata]
        case .direct:
            return [.archive, .zip, .dmg, .appcast]
        }
    }

    public var submissionChannel: String {
        switch self {
        case .appStore:
            return "app-store-connect"
        case .direct:
            return "direct-download"
        }
    }

    public static func resolve(from rawValue: String?) -> DistributionProfile? {
        guard let rawValue else { return nil }
        return DistributionProfile(rawValue: rawValue)
    }
}

public enum UpdaterPolicy: String, Codable, Sendable {
    case enabled
    case disabled
}
