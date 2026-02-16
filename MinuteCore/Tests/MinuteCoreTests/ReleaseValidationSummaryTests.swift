import Foundation
import Testing
@testable import MinuteCore

struct ReleaseValidationSummaryTests {
    @Test
    func refreshOverallStatus_reportsPassedWhenAllRequiredChecksPass() {
        var summary = ReleaseValidationSummary(
            runID: "run-1",
            profile: .appStore,
            overallStatus: .failed,
            checks: [
                ReleaseValidationCheckResult(
                    checkType: .profileConfig,
                    target: "profile",
                    status: .passed,
                    message: "profile is valid"
                ),
                ReleaseValidationCheckResult(
                    checkType: .signature,
                    target: "Minute.app",
                    status: .passed,
                    message: "signature is valid"
                ),
                ReleaseValidationCheckResult(
                    checkType: .sandboxPolicy,
                    target: "Minute.app",
                    status: .passed,
                    message: "sandbox is valid"
                ),
                ReleaseValidationCheckResult(
                    checkType: .updaterPolicy,
                    target: "Minute.app",
                    status: .passed,
                    message: "updater disabled"
                ),
                ReleaseValidationCheckResult(
                    checkType: .artifactPolicy,
                    target: "output",
                    status: .passed,
                    message: "artifacts valid"
                ),
            ],
            artifacts: []
        )

        summary.refreshOverallStatus(requiredChecks: DistributionProfile.appStore.requiredValidationChecks)

        #expect(summary.overallStatus == .passed)
    }

    @Test
    func refreshOverallStatus_reportsFailedWhenRequiredCheckFails() {
        var summary = ReleaseValidationSummary(
            runID: "run-2",
            profile: .appStore,
            overallStatus: .passed,
            checks: [
                ReleaseValidationCheckResult(
                    checkType: .profileConfig,
                    target: "profile",
                    status: .passed,
                    message: "profile is valid"
                ),
                ReleaseValidationCheckResult(
                    checkType: .signature,
                    target: "Minute.app",
                    status: .failed,
                    message: "signature missing"
                ),
            ],
            artifacts: []
        )

        summary.refreshOverallStatus(requiredChecks: DistributionProfile.appStore.requiredValidationChecks)

        #expect(summary.overallStatus == .failed)
    }

    @Test
    func refreshOverallStatus_reportsFailedWhenRequiredCheckIsMissing() {
        var summary = ReleaseValidationSummary(
            runID: "run-3",
            profile: .direct,
            overallStatus: .passed,
            checks: [
                ReleaseValidationCheckResult(
                    checkType: .profileConfig,
                    target: "profile",
                    status: .passed,
                    message: "profile is valid"
                ),
                ReleaseValidationCheckResult(
                    checkType: .signature,
                    target: "Minute.app",
                    status: .passed,
                    message: "signature valid"
                ),
            ],
            artifacts: []
        )

        summary.refreshOverallStatus(requiredChecks: DistributionProfile.direct.requiredValidationChecks)

        #expect(summary.overallStatus == .failed)
    }

    @Test
    func refreshOverallStatus_reportsFailedWhenRequiredCheckIsSkipped() {
        var summary = ReleaseValidationSummary(
            runID: "run-4",
            profile: .direct,
            overallStatus: .passed,
            checks: [
                ReleaseValidationCheckResult(
                    checkType: .profileConfig,
                    target: "profile",
                    status: .passed,
                    message: "profile is valid"
                ),
                ReleaseValidationCheckResult(
                    checkType: .signature,
                    target: "Minute.app",
                    status: .passed,
                    message: "signature valid"
                ),
                ReleaseValidationCheckResult(
                    checkType: .updaterPolicy,
                    target: "Minute.app",
                    status: .passed,
                    message: "updater policy valid"
                ),
                ReleaseValidationCheckResult(
                    checkType: .artifactPolicy,
                    target: "output",
                    status: .skipped,
                    message: "artifact policy skipped unexpectedly"
                ),
            ],
            artifacts: []
        )

        summary.refreshOverallStatus(requiredChecks: DistributionProfile.direct.requiredValidationChecks)

        #expect(summary.overallStatus == .failed)
    }

    @Test
    func refreshOverallStatus_prefersWorstStatusWhenChecksContainDuplicates() {
        var summary = ReleaseValidationSummary(
            runID: "run-5",
            profile: .appStore,
            overallStatus: .passed,
            checks: [
                ReleaseValidationCheckResult(
                    checkType: .profileConfig,
                    target: "profile",
                    status: .passed,
                    message: "profile is valid"
                ),
                ReleaseValidationCheckResult(
                    checkType: .signature,
                    target: "Minute.app",
                    status: .passed,
                    message: "signature valid"
                ),
                ReleaseValidationCheckResult(
                    checkType: .signature,
                    target: "Sparkle.framework",
                    status: .failed,
                    message: "sparkle signature invalid"
                ),
                ReleaseValidationCheckResult(
                    checkType: .sandboxPolicy,
                    target: "Minute.app",
                    status: .passed,
                    message: "sandbox valid"
                ),
                ReleaseValidationCheckResult(
                    checkType: .updaterPolicy,
                    target: "Minute.app",
                    status: .passed,
                    message: "updater disabled"
                ),
                ReleaseValidationCheckResult(
                    checkType: .artifactPolicy,
                    target: "output",
                    status: .passed,
                    message: "artifact policy valid"
                ),
            ],
            artifacts: []
        )

        summary.refreshOverallStatus(requiredChecks: DistributionProfile.appStore.requiredValidationChecks)

        #expect(summary.overallStatus == .failed)
    }
}
