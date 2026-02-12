# Data Model: App Store Release Readiness

**Branch**: 009-app-store-release  
**Date**: 2026-02-11

This feature introduces release-domain entities for profile-aware distribution and validation.

## Entities

### DistributionProfile

Represents channel policy used by build, app behavior gating, and release packaging.

Fields:
- `name`: `app-store` | `direct`
- `updaterPolicy`: `disabled` | `enabled`
- `artifactPolicy`: list of allowed output artifact types for the profile
- `requiredValidationChecks`: ordered list of mandatory checks
- `submissionChannel`: `app-store-connect` | `direct-download`

Validation rules:
- Only known profile names are accepted.
- `app-store` profile must set `updaterPolicy = disabled`.
- `direct` profile must allow existing direct-distribution update behavior.

### ReleaseRun

Represents one profile-specific release execution request.

Fields:
- `runId`: unique run identifier
- `profile`: DistributionProfile name
- `sourceArtifactPath`: archive/app input path
- `status`: lifecycle status
- `requestedAt`: timestamp
- `completedAt`: optional timestamp
- `triggerSource`: `make` | `script` | `manual`
- `requestedVersion`: optional version string

Validation rules:
- `profile` is required.
- `sourceArtifactPath` must resolve to a valid build artifact before preflight starts.
- A run cannot transition to packaging if mandatory preflight checks failed.

### ValidationCheckResult

Represents outcome of one release gate check.

Fields:
- `runId`: owning release run
- `checkType`: `signature` | `sandbox-policy` | `updater-policy` | `artifact-policy` | `profile-config`
- `target`: artifact or configuration scope that was checked
- `status`: `passed` | `failed` | `skipped`
- `message`: concise operator-facing result
- `details`: optional debugging context

Validation rules:
- `failed` checks must include actionable `message`.
- `skipped` checks are allowed only when profile policy marks the check optional.

### ReleaseArtifact

Represents one produced output file.

Fields:
- `runId`: owning release run
- `artifactType`: `archive` | `pkg` | `zip` | `dmg` | `appcast` | `submission-metadata`
- `path`: absolute or repo-relative artifact path
- `profile`: producing profile
- `generatedAt`: timestamp

Validation rules:
- Artifact type must be allowed by the selected profile.
- App Store profile must not produce direct-only artifacts.

### ReleaseValidationSummary

Represents final release validation report for one run.

Fields:
- `runId`: owning release run
- `profile`: selected profile
- `overallStatus`: `passed` | `failed`
- `checks`: collection of ValidationCheckResult
- `artifacts`: collection of ReleaseArtifact
- `generatedAt`: timestamp

Validation rules:
- `overallStatus = passed` only when all required checks passed.
- Summary must be emitted for every run, including failed runs.

## Relationships

- One `DistributionProfile` is selected by many `ReleaseRun` records.
- One `ReleaseRun` has many `ValidationCheckResult` entries.
- One `ReleaseRun` has many `ReleaseArtifact` entries.
- One `ReleaseRun` has one `ReleaseValidationSummary`.

## State Transitions

### ReleaseRun.status

- `created` → `preflight_running`: run starts with profile and inputs accepted.
- `preflight_running` → `preflight_failed`: one or more required checks fail.
- `preflight_running` → `preflight_passed`: all required checks pass.
- `preflight_passed` → `packaging`: profile-allowed artifact generation starts.
- `packaging` → `completed`: artifacts and summary successfully generated.
- `packaging` → `failed`: packaging or profile-policy validation fails.
- `created|preflight_running|packaging` → `canceled`: operator cancellation.

Transition constraints:
- `preflight_failed` is terminal for release output generation.
- `app-store` runs may not enter states that generate direct-only artifacts.

## Out of Scope

- Changes to meeting note rendering, transcript generation, or vault output paths.
- Changes to core pipeline states for recording/transcription/summarization.
