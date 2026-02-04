# Feature Specification: Reorganize folder and package structure

**Feature Branch**: `001-reorg-folder-structure`
**Created**: 2026-02-04
**Status**: Draft
**Input**: User description: "Reorganize folder and package structure to follow conventional project layout and logical module boundaries."

## User Scenarios & Testing (mandatory)

### User Story 1 - Developer build & run (Priority: P1)

Developers can pull the branch, open the workspace/project in Xcode, build the app and run it on macOS without performing manual path fixes.

**Why this priority**: A working build is the prerequisite for any downstream verification (tests, QA, packaging).

**Independent Test**: Clone branch, open the workspace in the IDE or run the repository's CI build steps. Build must succeed without manual file relocations.

**Acceptance Scenarios**:

1. **Given** a developer checkout of the feature branch, **When** they open the workspace and build, **Then** the build succeeds.
2. **Given** a developer runs the app, **When** they start and stop a recording flow, **Then** no runtime crashes occur caused by missing imports or moved files.

---

### User Story 2 - CI and tests (Priority: P2)

The CI pipeline continues to build `MinuteCore` and run unit tests, and `Minute` app integration steps complete as before.

**Why this priority**: Ensures continuous integration and releases are not blocked.

**Independent Test**: Run the repository's standard test steps in CI or the IDE. All existing tests must pass.

**Acceptance Scenarios**:

1. **Given** the restructured repo, **When** CI runs the test steps, **Then** all previously passing tests remain passing (or failures are documented and addressed as part of the change).

---

### User Story 3 - Contributor discoverability (Priority: P3)

New contributors can find module boundaries and package manifests easily, and the repo layout matches common Swift/macOS conventions (app target in `Minute/`, packages in top-level `MinuteCore/` or `Packages/`, shared `Vendor/` for external binaries).

**Why this priority**: Lowers onboarding friction and reduces accidental cross-target code coupling.

**Independent Test**: A reviewer unfamiliar with the repo can locate `MinuteCore` sources, tests, and build scripts within 2 minutes using the README and directory layout.

**Acceptance Scenarios**:

1. **Given** a fresh checkout and the updated README, **When** a contributor inspects the top-level folders, **Then** they can identify the app, packages, vendor binaries, scripts, and specs without opening Xcode.

---

### Edge Cases

- Xcode project file references (`.pbxproj`) may contain group/file references that point to moved files — these must be updated or removed.
- Swift Package target names and `Package.swift` target paths must be validated to avoid duplicate target names or compile-time conflicts.
- Git history will not be preserved on moved files beyond standard `git mv` semantics; large moves may require avoiding diff noise.

## Requirements (mandatory)

### Functional Requirements

- **FR-001**: Repo MUST expose a clear top-level layout with at minimum these folders: `Minute/` (app target sources), `MinuteCore/` (Swift package sources + tests), `Vendor/` (third-party binaries), `specs/`, `scripts/`, and `docs/`.
- **FR-002**: All Swift targets referenced by `Minute.xcodeproj` and `Package.swift` MUST have valid file references after the reorg; builds must succeed without manual file relocation.
- **FR-003**: Public APIs and module boundaries in `MinuteCore` MUST be preserved so external behavior and tests continue to pass.
- **FR-004**: Update `Package.swift`, `Minute.xcodeproj` and any test targets to match the new paths; changes MUST be minimal and documented in `docs/tasks/`.
- **FR-005**: Add or update a `CONTRIBUTING` subsection describing the new layout and how to add packages, binaries, and targets.
- **FR-006**: Preserve the three-file meeting output contract defined in `AGENTS.md` and related docs; file path generation helpers must not change behavior unless explicitly documented and tested.
- **FR-007**: Any scripts in `scripts/` that reference paths must be updated to the new layout, and a smoke test script added to validate common flows (build, run tests).

*Marked unclear and requiring confirmation:*

- **FR-008**: Change package/module names to match new folders: packages and module names WILL be renamed where appropriate to align with the new folder layout. This requires updating imports and public-facing module identifiers and will be done as part of the migration (permitted by Q1: B).
- **FR-009**: Update `Minute.xcodeproj` groups and file references in-place: the project file will be updated to point to new file locations directly, producing in-place `.pbxproj` edits (permitted by Q2: A).
- **FR-010**: Scope of reorg: the reorganization WILL include the entire repository, including `Vendor/`, `scripts/`, `specs/`, and docs, to produce a consistent layout (permitted by Q3: B).

### Non-Functional Requirements (mandatory)

- **NFR-001**: System MUST preserve local-only processing and avoid outbound network calls except model downloads.
- **NFR-002**: System MUST maintain deterministic output for any note rendering or contract changes.
- **NFR-003**: Long-running operations MUST support cancellation and avoid blocking the UI thread.
- **NFR-004**: UX changes MUST align with the pipeline state machine and provide clear user status/errors without leaking internal details.
- **NFR-005**: The reorganization MUST not introduce outbound network calls or change model download behavior.
- **NFR-006**: Repo should be easy to navigate in both Finder and Xcode's Project Navigator; Xcode groups should reflect on-disk layout where practical.

### Key Entities

- **App Target (`Minute`)**: UI sources and resources for the macOS app.
- **Package (`MinuteCore`)**: Non-UI domain logic, services, rendering, file contracts, and tests.
- **Service Targets**: `MinuteWhisperService` and other helper executables or XPC services.
- **Vendor**: External binaries and bundled resources (e.g., `ffmpeg/`).
- **Scripts**: Build and release helper scripts in `scripts/`.

## Success Criteria (mandatory)

-- **SC-001**: Local build success — the project builds successfully in the IDE or via CI without file-not-found or target-not-found errors.
-- **SC-002**: `MinuteCore` unit tests pass when run via the repository's standard test steps in CI or the IDE.
- **SC-003**: No change to the meeting output contract paths and filenames; golden tests (renderer, filename sanitization) pass.
- **SC-004**: Developer onboarding time for locating modules reduced (qualitative) — README and contributing docs updated.
- **SC-005**: CI pipeline continues to pass in a preserved or minimally updated job configuration.

---

## Assumptions

- The primary goal is on-disk folder organization and package clarity rather than large API refactors.
- The `Minute.xcodeproj` and `Minute.xcworkspace` may be updated in the branch to reflect new file locations.
- Large git history preservation is desirable but not strictly required for every file (standard `git mv` behavior is acceptable).

## Dependencies

- Coordination with CI config owners if pipeline steps require path changes.
- A reviewer with Xcode macOS experience to validate project file edits.

## Next steps

1. Resolve the clarification questions below (max 3).
2. Create a migration plan that lists file moves, `Package.swift` changes, and `Minute.xcodeproj` edits.
3. Implement the moves in a small batch with smoke-build and tests after each batch.
4. Update `docs/` and `CONTRIBUTING.md` to reflect the new layout.

## Clarifications Required

1. [NEEDS CLARIFICATION: Rename packages vs. only relocate files?]
2. [NEEDS CLARIFICATION: Update `.pbxproj` groups in-place vs. add new groups to avoid history churn?]
3. [NEEDS CLARIFICATION: Scope — reorg only `Minute/` and `MinuteCore/` or whole repo including `Vendor/`, `scripts/`, and `specs/`?]
# Feature Specification: [FEATURE NAME]

**Feature Branch**: `[###-feature-name]`  
**Created**: [DATE]  
**Status**: Draft  
**Input**: User description: "$ARGUMENTS"

## User Scenarios & Testing *(mandatory)*

<!--
  IMPORTANT: User stories should be PRIORITIZED as user journeys ordered by importance.
  Each user story/journey must be INDEPENDENTLY TESTABLE - meaning if you implement just ONE of them,
  you should still have a viable MVP (Minimum Viable Product) that delivers value.
  
  Assign priorities (P1, P2, P3, etc.) to each story, where P1 is the most critical.
  Think of each story as a standalone slice of functionality that can be:
  - Developed independently
  - Tested independently
  - Deployed independently
  - Demonstrated to users independently
-->

### User Story 1 - [Brief Title] (Priority: P1)

[Describe this user journey in plain language]

**Why this priority**: [Explain the value and why it has this priority level]

**Independent Test**: [Describe how this can be tested independently - e.g., "Can be fully tested by [specific action] and delivers [specific value]"]

**Acceptance Scenarios**:

1. **Given** [initial state], **When** [action], **Then** [expected outcome]
2. **Given** [initial state], **When** [action], **Then** [expected outcome]

---

### User Story 2 - [Brief Title] (Priority: P2)

[Describe this user journey in plain language]

**Why this priority**: [Explain the value and why it has this priority level]

**Independent Test**: [Describe how this can be tested independently]

**Acceptance Scenarios**:

1. **Given** [initial state], **When** [action], **Then** [expected outcome]

---

### User Story 3 - [Brief Title] (Priority: P3)

[Describe this user journey in plain language]

**Why this priority**: [Explain the value and why it has this priority level]

**Independent Test**: [Describe how this can be tested independently]

**Acceptance Scenarios**:

1. **Given** [initial state], **When** [action], **Then** [expected outcome]

---

[Add more user stories as needed, each with an assigned priority]

### Edge Cases

<!--
  ACTION REQUIRED: The content in this section represents placeholders.
  Fill them out with the right edge cases.
-->

- What happens when [boundary condition]?
- How does system handle [error scenario]?

## Requirements *(mandatory)*

<!--
  ACTION REQUIRED: The content in this section represents placeholders.
  Fill them out with the right functional requirements.
-->

### Functional Requirements

- **FR-001**: System MUST [specific capability, e.g., "allow users to create accounts"]
- **FR-002**: System MUST [specific capability, e.g., "validate email addresses"]  
- **FR-003**: Users MUST be able to [key interaction, e.g., "reset their password"]
- **FR-004**: System MUST [data requirement, e.g., "persist user preferences"]
- **FR-005**: System MUST [behavior, e.g., "log all security events"]

*Example of marking unclear requirements:*

- **FR-006**: System MUST authenticate users via [NEEDS CLARIFICATION: auth method not specified - email/password, SSO, OAuth?]
- **FR-007**: System MUST retain user data for [NEEDS CLARIFICATION: retention period not specified]

### Non-Functional Requirements *(mandatory)*

- **NFR-001**: System MUST preserve local-only processing and avoid outbound
  network calls except model downloads.
- **NFR-002**: System MUST maintain deterministic output for any note rendering
  or contract changes.
- **NFR-003**: Long-running operations MUST support cancellation and avoid
  blocking the UI thread.
- **NFR-004**: UX changes MUST align with the pipeline state machine and
  provide clear user status/errors without leaking internal details.

### Key Entities *(include if feature involves data)*

- **[Entity 1]**: [What it represents, key attributes without implementation]
- **[Entity 2]**: [What it represents, relationships to other entities]

## Success Criteria *(mandatory)*

<!--
  ACTION REQUIRED: Define measurable success criteria.
  These must be technology-agnostic and measurable.
-->

### Measurable Outcomes

- **SC-001**: [Measurable metric, e.g., "Users can complete account creation in under 2 minutes"]
- **SC-002**: [Measurable metric, e.g., "System handles 1000 concurrent users without degradation"]
- **SC-003**: [User satisfaction metric, e.g., "90% of users successfully complete primary task on first attempt"]
- **SC-004**: [Business metric, e.g., "Reduce support tickets related to [X] by 50%"]
