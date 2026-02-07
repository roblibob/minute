---
description: "Task list for feature 004 implementation"
---

# Tasks: Background Summarization for Back-to-Back Meetings (004)

**Input**: Design documents in `specs/004-background-summarization/` (spec.md, plan.md, research.md, data-model.md, quickstart.md)

**Tests**: REQUIRED (this feature changes MinuteCore + user-facing behavior). Add Swift Testing tasks in `MinuteCore/Tests/MinuteCoreTests/`.

**Organization**: Tasks are grouped by user story so each story can be implemented and verified independently.

**TDD note (constitution)**: For this repo, “red” can include compile-time failures (e.g., tests referencing types that don’t exist yet). Write tests first, then add the minimum production code to compile + pass.

## Format

Every task line uses this strict format:

Example (structure only): `T001 [P] [US1] Description with file path`

Where:
- `[P]` = safe to do in parallel (different files, no dependency)
- `[US#]` = user story label (only in story phases)

---

## Phase 1: Setup (Shared Infrastructure)

- [x] T001 [P] Add failing busy gate tests in MinuteCore/Tests/MinuteCoreTests/ProcessingBusyGateTests.swift
- [x] T002 [P] Add failing orchestrator tests (single-active + pending slot) in MinuteCore/Tests/MinuteCoreTests/MeetingProcessingOrchestratorTests.swift
- [x] T003 [P] Add failing inference deferral tests in MinuteCore/Tests/MinuteCoreTests/ScreenContextCaptureServiceDeferralTests.swift

---

## Phase 2: Foundational (Blocking Prerequisites)

- [x] T004 Create background processing status types in MinuteCore/Sources/MinuteCore/Domain/BackgroundProcessingTypes.swift
- [x] T005 Implement ProcessingBusyGate (isBusy + waitUntilIdle + scoped busy token) in MinuteCore/Sources/MinuteCore/Services/ProcessingBusyGate.swift
- [x] T006 Create MeetingProcessingOrchestrator actor skeleton in MinuteCore/Sources/MinuteCore/Pipeline/MeetingProcessingOrchestrator.swift
- [x] T007 Implement MeetingProcessingOrchestrator single-active + optional single-pending behavior in MinuteCore/Sources/MinuteCore/Pipeline/MeetingProcessingOrchestrator.swift
- [x] T008 Wire the orchestrator to MeetingPipelineCoordinator in MinuteCore/Sources/MinuteCore/Pipeline/MeetingProcessingOrchestrator.swift

**Checkpoint**: Orchestrator compiles and is unit-testable.

---

## Phase 3: User Story 1 — Record Back-to-Back While Previous Meeting Processes (Priority: P1) 🎯 MVP

**Goal**: Allow Meeting B recording to start immediately while Meeting A processes; defer Meeting B’s *first* screen inference until Meeting A processing completes.

**Independent Test**: Quickstart Scenario A in specs/004-background-summarization/quickstart.md.

### Tests (write first)

- [x] T009 [P] [US1] Extend orchestrator tests to cover pending-slot overflow policy (FIFO + manual processing for additional meetings) in MinuteCore/Tests/MinuteCoreTests/MeetingProcessingOrchestratorTests.swift
- [x] T010 [P] [US1] Add test for “first inference = first attempt (any window)” semantics in MinuteCore/Tests/MinuteCoreTests/ScreenContextCaptureServiceDeferralTests.swift
- [x] T011 [P] [US1] Add test that capture continues while inference is deferred (inference paused, optional latest preview updates) in MinuteCore/Tests/MinuteCoreTests/ScreenContextCaptureServiceDeferralTests.swift
- [x] T012 [P] [US1] Add regression test that orchestrator does not trigger duplicate processing runs / duplicate vault writes for the same meeting completion event in MinuteCore/Tests/MinuteCoreTests/MeetingProcessingOrchestratorExactlyOnceTests.swift

### Implementation

- [x] T013 [US1] Propagate gate busy state around processing execution in MinuteCore/Sources/MinuteCore/Pipeline/MeetingProcessingOrchestrator.swift
- [x] T014 [US1] Add a gate-aware “defer first inference” check in MinuteCore/Sources/MinuteCore/Services/ScreenContextCaptureService.swift
- [x] T015 [US1] Expose a user-visible “first inference deferred” signal in MinuteCore/Sources/MinuteCore/Services/ScreenContextCaptureService.swift
- [x] T016 [US1] Refactor capture vs processing state in Minute/Sources/ViewModels/MeetingPipelineViewModel.swift (add separate published capture state + processing status)
- [x] T017 [US1] Update start/stop recording flow to enqueue processing and return to recordable state in Minute/Sources/ViewModels/MeetingPipelineViewModel.swift
- [x] T018 [US1] Inject a shared ProcessingBusyGate into both orchestrator + screen capture in Minute/Sources/ViewModels/MeetingPipelineViewModel.swift
- [x] T019 [US1] Update UI record controls to use capture state (not processing state) in Minute/Sources/Views/ContentView.swift
- [x] T020 [US1] Show “Processing” (Meeting A) and “Deferred inference” (Meeting B) status UI in Minute/Sources/Views/ContentView.swift

**Checkpoint**: US1 passes Quickstart Scenario A end-to-end.

---

## Phase 4: User Story 2 — Understand and Control Background Work (Priority: P2)

**Goal**: Provide clear status and allow canceling active processing safely.

**Independent Test**: Quickstart Scenario B + C in specs/004-background-summarization/quickstart.md.

### Tests

- [x] T021 [P] [US2] Add cancel behavior tests (cancel while running + stable end state) in MinuteCore/Tests/MinuteCoreTests/MeetingProcessingOrchestratorCancelTests.swift

### Implementation

- [x] T022 [US2] Implement cancel API for active processing (and clear pending when requested) in MinuteCore/Sources/MinuteCore/Pipeline/MeetingProcessingOrchestrator.swift
- [x] T023 [US2] Add processing status snapshot suitable for UI (stage/progress/outcome) in MinuteCore/Sources/MinuteCore/Pipeline/MeetingProcessingOrchestrator.swift
- [x] T024 [US2] Wire cancel action to orchestrator cancel in Minute/Sources/ViewModels/MeetingPipelineViewModel.swift
- [x] T025 [US2] Add/adjust cancel button and status presentation in Minute/Sources/Views/ContentView.swift

**Checkpoint**: US2 passes Quickstart Scenarios B and C.

---

## Phase 5: User Story 3 — Recover Gracefully From Delays or Failures (Priority: P3)

**Goal**: If processing fails or is canceled, user can retry later without affecting recording.

**Independent Test**: Simulate a summarization failure via a mock service and verify retry works while recording remains usable.

### Tests

- [x] T026 [P] [US3] Add retry tests (failed/canceled → retry → success) in MinuteCore/Tests/MinuteCoreTests/MeetingProcessingOrchestratorRetryTests.swift

### Implementation

- [x] T027 [US3] Implement retry API that re-enqueues the last failed/canceled meeting (respecting single-active policy) in MinuteCore/Sources/MinuteCore/Pipeline/MeetingProcessingOrchestrator.swift
- [x] T028 [US3] Surface user-visible retry affordance and error summary in Minute/Sources/ViewModels/MeetingPipelineViewModel.swift
- [x] T029 [US3] Add retry UI action and messaging in Minute/Sources/Views/ContentView.swift

**Checkpoint**: US3 retry works; recording remains startable throughout.

---

## Phase 6: Polish & Cross-Cutting Concerns

- [x] T030 [P] Update manual validation wording to match the new UI states in specs/004-background-summarization/quickstart.md
- [x] T031 [P] Ensure docs reflect v1 scope (single-active processing, no daemon promises) in specs/004-background-summarization/research.md
- [x] T032 Run targeted tests for the feature (MinuteCore scheme) and document the command in specs/004-background-summarization/quickstart.md

---

## Dependencies & Execution Order

### User Story Dependencies

- US1 (P1) is the MVP and must be completed first.
- US2 depends on US1 (needs orchestrator + UI state split).
- US3 depends on US2 (retry UX assumes status + cancel/error surfacing patterns).

### Dependency Graph (Story Level)

US1 → US2 → US3

---

## Parallel Execution Examples

### US1 parallel examples

- T009–T012 can be done in parallel (separate test files under MinuteCore/Tests/MinuteCoreTests/).
- T013 and T015 can be started in parallel once T010–T012 land (different modules: MinuteCore vs app).

### US2 parallel examples

- T021 can be written while T022–T023 are being implemented (test-first recommended) in MinuteCore/Tests/MinuteCoreTests/MeetingProcessingOrchestratorCancelTests.swift.

### US3 parallel examples

- T026 can be written in parallel with UI-only scaffolding for retry in Minute/Sources/Views/ContentView.swift (but keep implementation gated on orchestrator retry support).

---

## Implementation Strategy

### MVP First

1. Phase 1 + Phase 2 (foundation for orchestrator + gate)
2. Phase 3 (US1) end-to-end
3. Stop and validate (Quickstart Scenario A)

### Incremental Delivery

- After US1 is stable: add US2 (status + cancel), then US3 (retry + recovery).
