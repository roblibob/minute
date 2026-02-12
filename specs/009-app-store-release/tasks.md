---

description: "Task list for App Store Release Readiness"

---

# Tasks: App Store Release Readiness

**Input**: Design documents from `/Users/roblibob/Projects/FLX/Minute/Minute/specs/009-app-store-release/`
**Prerequisites**: `/Users/roblibob/Projects/FLX/Minute/Minute/specs/009-app-store-release/plan.md`, `/Users/roblibob/Projects/FLX/Minute/Minute/specs/009-app-store-release/spec.md`, `/Users/roblibob/Projects/FLX/Minute/Minute/specs/009-app-store-release/research.md`, `/Users/roblibob/Projects/FLX/Minute/Minute/specs/009-app-store-release/data-model.md`, `/Users/roblibob/Projects/FLX/Minute/Minute/specs/009-app-store-release/contracts/openapi.yaml`, `/Users/roblibob/Projects/FLX/Minute/Minute/specs/009-app-store-release/quickstart.md`

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Establish profile-aware scaffolding before core implementation.

- [X] T001 Create distribution profile build settings file at /Users/roblibob/Projects/FLX/Minute/Minute/Config/DistributionProfiles.xcconfig
- [X] T002 [P] Create release profile shell helper library at /Users/roblibob/Projects/FLX/Minute/Minute/scripts/release-profile.sh
- [X] T003 [P] Create script test harness directory and runner at /Users/roblibob/Projects/FLX/Minute/Minute/scripts/tests/run-release-tests.sh
- [X] T004 Create release domain model stubs for profile and summary at /Users/roblibob/Projects/FLX/Minute/Minute/MinuteCore/Sources/MinuteCore/Domain/DistributionProfile.swift and /Users/roblibob/Projects/FLX/Minute/Minute/MinuteCore/Sources/MinuteCore/Domain/ReleaseValidationSummary.swift

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Core profile policy and wiring required before any user story work.

**CRITICAL**: Complete this phase before starting user stories.

- [X] T005 Implement profile policy rules in /Users/roblibob/Projects/FLX/Minute/Minute/MinuteCore/Sources/MinuteCore/Domain/DistributionProfile.swift
- [X] T006 [P] Implement release run, validation check, and summary entities in /Users/roblibob/Projects/FLX/Minute/Minute/MinuteCore/Sources/MinuteCore/Domain/ReleaseValidationSummary.swift
- [X] T007 Wire profile-specific compilation settings into /Users/roblibob/Projects/FLX/Minute/Minute/Minute.xcodeproj/project.pbxproj using /Users/roblibob/Projects/FLX/Minute/Minute/Config/DistributionProfiles.xcconfig
- [X] T008 Require explicit DIST_PROFILE selection in /Users/roblibob/Projects/FLX/Minute/Minute/Makefile and profile parsing in /Users/roblibob/Projects/FLX/Minute/Minute/scripts/release-notarize.sh
- [X] T009 Add shared profile argument validation and JSON summary utility functions in /Users/roblibob/Projects/FLX/Minute/Minute/scripts/release-profile.sh and source them from /Users/roblibob/Projects/FLX/Minute/Minute/scripts/release-notarize.sh
- [X] T010 Add foundational profile validation smoke tests in /Users/roblibob/Projects/FLX/Minute/Minute/scripts/tests/release-profile-args-smoke.sh

**Checkpoint**: Distribution profile is explicit, validated, and wired through build + release entry points.

---

## Phase 3: User Story 1 - Produce App Store-ready build (Priority: P1) 🎯 MVP

**Goal**: Deliver an App Store release flow that fails fast on signing/sandbox issues and outputs a validation summary.

**Independent Test**: Run an app-store profile release from an archive; verify valid input completes with App Store-appropriate artifacts, and invalid signing/entitlement input fails before packaging with actionable errors.

### Tests for User Story 1

- [X] T011 [P] [US1] Add preflight failure smoke tests for signature and entitlement checks in /Users/roblibob/Projects/FLX/Minute/Minute/scripts/tests/release-app-store-preflight-smoke.sh
- [X] T012 [P] [US1] Add summary status aggregation tests in /Users/roblibob/Projects/FLX/Minute/Minute/MinuteCore/Tests/MinuteCoreTests/ReleaseValidationSummaryTests.swift

### Implementation for User Story 1

- [X] T013 [US1] Implement App Store profile signature preflight checks in /Users/roblibob/Projects/FLX/Minute/Minute/scripts/release-notarize.sh
- [X] T014 [US1] Implement App Store profile sandbox entitlement preflight checks in /Users/roblibob/Projects/FLX/Minute/Minute/scripts/release-notarize.sh
- [X] T015 [US1] Add fail-fast preflight error reporting with affected artifact details in /Users/roblibob/Projects/FLX/Minute/Minute/scripts/release-notarize.sh
- [X] T016 [US1] Generate per-run release validation summary output in /Users/roblibob/Projects/FLX/Minute/Minute/scripts/release-notarize.sh and /Users/roblibob/Projects/FLX/Minute/Minute/scripts/release-profile.sh
- [X] T017 [US1] Enforce app-store artifact policy (skip direct-only artifacts) in /Users/roblibob/Projects/FLX/Minute/Minute/scripts/release-notarize.sh
- [X] T018 [US1] Persist run status transitions (created/preflight/packaging/completed/failed) in summary output logic at /Users/roblibob/Projects/FLX/Minute/Minute/scripts/release-notarize.sh

**Checkpoint**: US1 is complete when App Store profile releases are preflight-gated, fail fast when invalid, and emit validation summaries.

---

## Phase 4: User Story 2 - Enforce channel-specific updater behavior (Priority: P2)

**Goal**: Disable self-update behavior for App Store builds while keeping direct-distribution update behavior unchanged.

**Independent Test**: Build app-store and direct profiles, launch both, and verify update UI/commands are absent in app-store profile and present in direct profile.

### Tests for User Story 2

- [X] T019 [P] [US2] Add updater profile behavior tests for command/menu visibility in /Users/roblibob/Projects/FLX/Minute/Minute/MinuteTests/UpdaterProfileBehaviorTests.swift
- [X] T020 [P] [US2] Add updater view model profile-mode tests in /Users/roblibob/Projects/FLX/Minute/Minute/MinuteTests/UpdaterViewModelProfileTests.swift

### Implementation for User Story 2

- [X] T021 [US2] Implement profile-aware updater abstraction in /Users/roblibob/Projects/FLX/Minute/Minute/Minute/Sources/ViewModels/UpdaterViewModel.swift
- [X] T022 [US2] Gate updater startup by distribution profile in /Users/roblibob/Projects/FLX/Minute/Minute/Minute/Sources/App/MinuteApp.swift
- [X] T023 [P] [US2] Hide update settings section for app-store profile in /Users/roblibob/Projects/FLX/Minute/Minute/Minute/Sources/Views/Settings/MainSettingsView.swift and /Users/roblibob/Projects/FLX/Minute/Minute/Minute/Sources/Views/Settings/UpdatesSettingsSection.swift
- [X] T024 [P] [US2] Remove Check for Updates command for app-store profile in /Users/roblibob/Projects/FLX/Minute/Minute/Minute/Sources/App/MinuteApp.swift and /Users/roblibob/Projects/FLX/Minute/Minute/Minute/Sources/Views/CheckForUpdatesView.swift
- [X] T025 [US2] Make Sparkle metadata profile-aware in /Users/roblibob/Projects/FLX/Minute/Minute/Config/MinuteInfo.plist and /Users/roblibob/Projects/FLX/Minute/Minute/Minute.xcodeproj/project.pbxproj

**Checkpoint**: US2 is complete when app-store builds have no self-update behavior and direct builds preserve existing updater behavior.

---

## Phase 5: User Story 3 - Integrate release scripts with channel profiles (Priority: P3)

**Goal**: Make existing release scripts and documentation profile-driven with clear operator behavior and output rules.

**Independent Test**: Run release flow with direct and app-store profiles and verify each runs only profile-appropriate steps, with invalid/missing profile failing before artifact generation.

### Tests for User Story 3

- [X] T026 [P] [US3] Add direct profile artifact smoke tests in /Users/roblibob/Projects/FLX/Minute/Minute/scripts/tests/release-direct-profile-smoke.sh
- [X] T027 [P] [US3] Add app-store profile artifact exclusion smoke tests in /Users/roblibob/Projects/FLX/Minute/Minute/scripts/tests/release-app-store-artifacts-smoke.sh

### Implementation for User Story 3

- [X] T028 [US3] Add DIST_PROFILE passthrough and profile help text to /Users/roblibob/Projects/FLX/Minute/Minute/Makefile
- [X] T029 [US3] Make notarization/packaging/appcast branches profile-aware in /Users/roblibob/Projects/FLX/Minute/Minute/scripts/release-notarize.sh
- [X] T030 [US3] Restrict appcast generation to direct profile in /Users/roblibob/Projects/FLX/Minute/Minute/scripts/generate-appcast.sh
- [X] T031 [US3] Update operator release instructions for both profiles in /Users/roblibob/Projects/FLX/Minute/Minute/docs/releasing.md

**Checkpoint**: US3 is complete when one script entry point supports both profiles safely and docs match actual behavior.

---

## Phase 6: Polish & Cross-Cutting Concerns

**Purpose**: Final verification, regression checks, and release-readiness evidence.

- [X] T032 [P] Add profile-mode release behavior note to /Users/roblibob/Projects/FLX/Minute/Minute/docs/overview.md
- [X] T033 Run automated checks from /Users/roblibob/Projects/FLX/Minute/Minute/specs/009-app-store-release/quickstart.md and record execution notes in /Users/roblibob/Projects/FLX/Minute/Minute/specs/009-app-store-release/quickstart.md
- [X] T034 Execute focused manual QA and capture results in /Users/roblibob/Projects/FLX/Minute/Minute/specs/009-app-store-release/release-qa.md
- [X] T035 [P] Run both profile release dry-runs and document validation summary file locations in /Users/roblibob/Projects/FLX/Minute/Minute/docs/releasing.md

---

## Dependencies & Execution Order

### Phase Dependencies

- Phase 1 -> Phase 2 -> Phase 3/4/5 -> Phase 6
- User stories start only after Foundational tasks (T005-T010) complete.

### User Story Dependency Graph

- US1 (P1): starts after Phase 2; no dependency on US2 or US3.
- US2 (P2): starts after Phase 2; independent from US1 except shared profile plumbing from T005-T010.
- US3 (P3): starts after Phase 2; independent from US1/US2 feature behavior but shares script/profile foundation.
- Recommended delivery order: US1 -> US2 -> US3.

Graph:
- Setup -> Foundational -> {US1, US2, US3} -> Polish

### Within Each User Story

- Complete story test tasks before implementation tasks.
- Keep changes scoped so each story can be validated independently.
- Do not let US2/US3 work change US1 acceptance behavior.

---

## Parallel Execution Examples

### User Story 1

```bash
Task T011 [US1] and Task T012 [US1] can run in parallel
```

### User Story 2

```bash
Task T019 [US2] and Task T020 [US2] can run in parallel
Task T023 [US2] and Task T024 [US2] can run in parallel after T022
```

### User Story 3

```bash
Task T026 [US3] and Task T027 [US3] can run in parallel
```

---

## Implementation Strategy

### MVP First (US1 only)

1. Complete Phase 1 and Phase 2.
2. Deliver Phase 3 (US1) and validate App Store preflight + summary behavior.
3. Pause for release operator review before expanding scope.

### Incremental Delivery

1. Ship US1 (App Store preflight-gated release flow).
2. Add US2 (profile-gated updater behavior).
3. Add US3 (fully integrated script/documentation profile workflow).
4. Finish with Polish tasks and release evidence capture.

### Parallel Team Strategy

1. One engineer completes Foundation (T005-T010).
2. After foundation:
   - Engineer A: US1
   - Engineer B: US2
   - Engineer C: US3
3. Consolidate in Phase 6 for final validation.

---

## Notes

- All task lines use strict checklist format: `- [ ] T### [P?] [US?] Description with file path`.
- `[US#]` labels are used only in user story phases.
- Paths are absolute for direct execution without additional path resolution.
