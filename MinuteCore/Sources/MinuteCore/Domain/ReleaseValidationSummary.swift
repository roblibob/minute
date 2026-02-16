import Foundation

public enum ReleaseRunStatus: String, Codable, Sendable {
    case created
    case preflightRunning = "preflight_running"
    case preflightFailed = "preflight_failed"
    case preflightPassed = "preflight_passed"
    case packaging
    case completed
    case failed
    case canceled
}

public enum ReleaseValidationCheckType: String, Codable, Sendable {
    case signature
    case sandboxPolicy = "sandbox-policy"
    case updaterPolicy = "updater-policy"
    case artifactPolicy = "artifact-policy"
    case profileConfig = "profile-config"
}

public enum ReleaseValidationCheckStatus: String, Codable, Sendable {
    case passed
    case failed
    case skipped
}

public enum ReleaseArtifactType: String, Codable, Sendable {
    case archive
    case pkg
    case zip
    case dmg
    case appcast
    case submissionMetadata = "submission-metadata"
}

public struct ReleaseRun: Codable, Sendable, Equatable {
    public let runID: String
    public let profile: DistributionProfile
    public let sourceArtifactPath: String
    public var status: ReleaseRunStatus
    public let requestedAt: Date
    public var completedAt: Date?
    public let triggerSource: String
    public let requestedVersion: String?

    public init(
        runID: String,
        profile: DistributionProfile,
        sourceArtifactPath: String,
        status: ReleaseRunStatus,
        requestedAt: Date,
        completedAt: Date? = nil,
        triggerSource: String,
        requestedVersion: String? = nil
    ) {
        self.runID = runID
        self.profile = profile
        self.sourceArtifactPath = sourceArtifactPath
        self.status = status
        self.requestedAt = requestedAt
        self.completedAt = completedAt
        self.triggerSource = triggerSource
        self.requestedVersion = requestedVersion
    }
}

public struct ReleaseValidationCheckResult: Codable, Sendable, Equatable {
    public let checkType: ReleaseValidationCheckType
    public let target: String
    public let status: ReleaseValidationCheckStatus
    public let message: String
    public let details: String?

    public init(
        checkType: ReleaseValidationCheckType,
        target: String,
        status: ReleaseValidationCheckStatus,
        message: String,
        details: String? = nil
    ) {
        self.checkType = checkType
        self.target = target
        self.status = status
        self.message = message
        self.details = details
    }
}

public struct ReleaseArtifact: Codable, Sendable, Equatable {
    public let artifactType: ReleaseArtifactType
    public let path: String
    public let profile: DistributionProfile
    public let generatedAt: Date?

    public init(
        artifactType: ReleaseArtifactType,
        path: String,
        profile: DistributionProfile,
        generatedAt: Date? = Date()
    ) {
        self.artifactType = artifactType
        self.path = path
        self.profile = profile
        self.generatedAt = generatedAt
    }
}

public struct ReleaseValidationSummary: Codable, Sendable, Equatable {
    public let runID: String
    public let profile: DistributionProfile
    public var overallStatus: ReleaseValidationCheckStatus
    public var checks: [ReleaseValidationCheckResult]
    public var artifacts: [ReleaseArtifact]
    public var generatedAt: Date

    public init(
        runID: String,
        profile: DistributionProfile,
        overallStatus: ReleaseValidationCheckStatus,
        checks: [ReleaseValidationCheckResult],
        artifacts: [ReleaseArtifact],
        generatedAt: Date = Date()
    ) {
        self.runID = runID
        self.profile = profile
        self.overallStatus = overallStatus
        self.checks = checks
        self.artifacts = artifacts
        self.generatedAt = generatedAt
    }

    public mutating func addCheck(_ check: ReleaseValidationCheckResult) {
        checks.append(check)
    }

    public mutating func addArtifact(_ artifact: ReleaseArtifact) {
        artifacts.append(artifact)
    }

    public mutating func refreshOverallStatus(requiredChecks: [ReleaseValidationCheckType]) {
        let checkMap = checks.reduce(into: [ReleaseValidationCheckType: ReleaseValidationCheckStatus]()) { map, check in
            guard let existing = map[check.checkType] else {
                map[check.checkType] = check.status
                return
            }
            map[check.checkType] = worstStatus(existing, check.status)
        }

        let hasBlockingStatus = requiredChecks.contains { requiredCheck in
            guard let status = checkMap[requiredCheck] else { return true }
            return status != .passed
        }
        overallStatus = hasBlockingStatus ? .failed : .passed
    }

    private func worstStatus(
        _ lhs: ReleaseValidationCheckStatus,
        _ rhs: ReleaseValidationCheckStatus
    ) -> ReleaseValidationCheckStatus {
        if lhs == .failed || rhs == .failed {
            return .failed
        }
        if lhs == .skipped || rhs == .skipped {
            return .skipped
        }
        return .passed
    }
}
