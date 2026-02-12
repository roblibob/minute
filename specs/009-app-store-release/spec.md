# Feature Specification: App Store Release Readiness

**Feature Branch**: `009-app-store-release`  
**Created**: 2026-02-11  
**Status**: Draft  
**Input**: User description: "get app ready for releasing on apple app store, that includes but is not limited to fixing signatures, sandboxes and build time disabling of sparkle and integrating in current release scripts"

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Produce App Store-ready build (Priority: P1)

As a release manager, I need a repeatable release flow that produces an App Store submission-ready build that passes signing and sandbox validation before upload.

**Why this priority**: Without this, the app cannot be shipped through the App Store channel.

**Independent Test**: Can be fully tested by running the App Store release flow for a candidate version and confirming the produced artifact passes local validation and App Store submission checks.

**Acceptance Scenarios**:

1. **Given** a release candidate and valid release credentials, **When** the release manager runs the App Store release flow, **Then** the system produces an artifact set that passes signing and sandbox validation checks.
2. **Given** a release candidate with an invalid signature or missing required entitlement, **When** the release manager runs the App Store release flow, **Then** the flow fails before submission and reports the exact blocking issue.

---

### User Story 2 - Enforce channel-specific updater behavior (Priority: P2)

As a product owner, I need App Store builds to run without self-update behavior while preserving update behavior for non-App Store distributions.

**Why this priority**: App Store compliance requires channel-appropriate update behavior, and direct-distribution releases still rely on existing updater workflows.

**Independent Test**: Can be tested by producing one App Store build and one non-App Store build, launching both, and verifying updater behavior matches the selected channel profile.

**Acceptance Scenarios**:

1. **Given** an App Store build, **When** a user launches the app and uses settings related to updates, **Then** no self-update checks, prompts, or update UI are available.
2. **Given** a non-App Store build, **When** a user launches the app and checks for updates, **Then** the existing update behavior remains available.

---

### User Story 3 - Integrate release scripts with channel profiles (Priority: P3)

As a release operator, I need current release scripts to support App Store and non-App Store profiles so I can execute the correct flow without manual script edits.

**Why this priority**: Scripted release consistency reduces human error and avoids ad hoc steps during release windows.

**Independent Test**: Can be tested by executing the release scripts in each distribution profile and confirming profile-specific outputs and validation steps are applied.

**Acceptance Scenarios**:

1. **Given** a selected distribution profile, **When** the release operator runs the release script, **Then** only profile-appropriate packaging and validation steps execute.
2. **Given** a missing or invalid profile selection, **When** the release operator starts the release script, **Then** the script exits with a clear correction message before producing artifacts.

### Edge Cases

- A release candidate contains correctly signed app binaries but an unsigned or mismatched embedded helper.
- Entitlements satisfy runtime needs but violate App Store sandbox policy constraints.
- App Store profile is selected but updater behavior remains accidentally enabled.
- Non-App Store profile is selected but updater behavior is accidentally disabled.
- A prior failed release attempt leaves partial artifacts that could contaminate a new release run.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The system MUST support at least two explicit release profiles: App Store distribution and non-App Store distribution.
- **FR-002**: The system MUST apply profile-specific signing rules to all shipped executable components and fail the release flow when any required signature is missing or invalid.
- **FR-003**: The system MUST enforce App Store sandbox entitlement validation before release completion and block release output when violations are detected.
- **FR-004**: The system MUST disable self-update functionality for App Store profile builds at build time.
- **FR-005**: The system MUST preserve updater functionality for non-App Store profile builds.
- **FR-006**: The release scripts MUST accept profile selection as an explicit input and run the correct profile-specific release path without manual script modification.
- **FR-007**: The release flow MUST run preflight checks for signatures, entitlements, and profile-policy mismatches before generating final release outputs.
- **FR-008**: The release flow MUST emit actionable error messages that identify the failing validation area and the affected artifact.
- **FR-009**: The system MUST produce a release validation summary for each run that records profile, validation outcomes, and final pass/fail status.
- **FR-010**: Release documentation MUST define the profile-specific release steps and required prerequisites for both App Store and non-App Store channels.

### Assumptions

- Existing non-App Store release functionality remains supported and must not regress.
- App Store submission is handled through an operator-driven process after local release validation passes.
- The product continues to allow outbound network access only for model downloads in runtime behavior.

### Dependencies

- Valid Apple Developer account access and signing credentials are available to the release operator.
- Current release scripts remain the authoritative path for packaging and validation execution.
- Existing release documentation remains the canonical source for operational release steps.

### Out of Scope

- Redesigning core meeting capture, transcription, summarization, or vault file output behavior.
- Changing the product output contract for meeting notes, audio, or transcript files.
- Replacing non-App Store distribution channels.

### Non-Functional Requirements *(mandatory)*

- **NFR-001**: System MUST preserve local-only processing and avoid outbound network calls except model downloads.
- **NFR-002**: System MUST maintain deterministic output for any note rendering or contract changes.
- **NFR-003**: Long-running operations MUST support cancellation and avoid blocking the UI thread.
- **NFR-004**: UX changes MUST align with the pipeline state machine and provide clear user status/errors without leaking internal details.
- **NFR-005**: Profile-specific release checks MUST complete in a predictable, repeatable way from the same source revision and release inputs.

### Key Entities *(include if feature involves data)*

- **Distribution Profile**: Declares release channel policy (App Store vs non-App Store), including allowed updater behavior and required validation gates.
- **Release Validation Summary**: Captures validation outcomes for signing, sandbox policy compliance, and profile-specific checks for a given release run.
- **Release Artifact Set**: The channel-specific packaged outputs and metadata produced by a successful release flow.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: 100% of App Store profile release runs fail fast on detected signing or sandbox violations before submission steps begin.
- **SC-002**: At least 90% of App Store candidate builds pass App Store submission validation on the first attempt across two consecutive release cycles.
- **SC-003**: In App Store profile QA validation, 0 update prompts or self-update actions are observed across 20 consecutive app launches.
- **SC-004**: A release operator can complete a profile-based release run setup and execution in 15 minutes or less (excluding external review/upload wait times) for at least 80% of runs.
- **SC-005**: For two consecutive release cycles, no critical release blockers are attributed to profile misconfiguration in release scripts.
