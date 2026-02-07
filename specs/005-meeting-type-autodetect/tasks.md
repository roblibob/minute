---

description: "Task list for feature implementation"

---

# Tasks: Meeting Type Autodetect Calibration

**Input**: Design documents from `/specs/005-meeting-type-autodetect/`
**Prerequisites**: plan.md (required), spec.md (required), research.md, data-model.md, contracts/, quickstart.md

**Tests**: Tests are REQUIRED (Minute constitution: TDD + test-gated core logic). These tasks include unit tests in `MinuteCore`.

**Organization**: Tasks are grouped by user story to enable independent implementation and testing.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2, US3)
- All tasks include exact file paths

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Ensure test scaffolding + fixture locations exist for this feature.

- [X] T001 Create summarization test folder `MinuteCore/Tests/MinuteCoreTests/Summarization/`
- [X] T002 [P] Create fixture folder `MinuteCore/Tests/MinuteCoreTests/Fixtures/`

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Shared fixtures and helpers used by all user stories.

**Checkpoint**: After this phase, story work can proceed independently.

- [X] T003 Create transcript snippet fixtures in `MinuteCore/Tests/MinuteCoreTests/Fixtures/MeetingTypeClassifierSnippets.swift`
- [X] T004 Create expected label fixtures in `MinuteCore/Tests/MinuteCoreTests/Fixtures/MeetingTypeClassifierExpectedLabels.swift`
- [X] T005 Add a test helper to normalize classifier outputs in `MinuteCore/Tests/MinuteCoreTests/Helpers/ClassifierTestHelpers.swift`

---

## Phase 3: User Story 1 - Reliable Autodetect Defaults (Priority: P1) 🎯 MVP

**Goal**: Make Autodetect conservative: uncertain/ambiguous/low-info → `General`.

**Independent Test**: Run `swift test` in `MinuteCore/` and verify the “uncertain ⇒ General” test suite passes.

### Tests for User Story 1 (REQUIRED) ⚠️

- [X] T006 [P] [US1] Add tests for low-information snippets → General in `MinuteCore/Tests/MinuteCoreTests/Summarization/MeetingTypeClassifierTests.swift`
- [X] T007 [P] [US1] Add tests for mixed-signal snippets → General in `MinuteCore/Tests/MinuteCoreTests/Summarization/MeetingTypeClassifierTests.swift`
- [X] T008 [P] [US1] Add tests for keyword-trap snippets → General in `MinuteCore/Tests/MinuteCoreTests/Summarization/MeetingTypeClassifierTests.swift`
- [X] T009 [US1] Add tests asserting the prompt contains an explicit “if uncertain ⇒ General” rule in `MinuteCore/Tests/MinuteCoreTests/Summarization/MeetingTypeClassifierPromptTests.swift`

### Implementation for User Story 1

- [X] T010 [US1] Update conservative rubric + anti-signals in `MinuteCore/Sources/MinuteCore/Summarization/Services/MeetingTypeClassifier.swift`
- [X] T011 [US1] Add a small few-shot section including ambiguous → General examples in `MinuteCore/Sources/MinuteCore/Summarization/Services/MeetingTypeClassifier.swift`
- [X] T012 [US1] Ensure prompt output whitelist is exact and unambiguous in `MinuteCore/Sources/MinuteCore/Summarization/Services/MeetingTypeClassifier.swift`

**Checkpoint**: US1 complete when all “uncertain ⇒ General” tests are green.

---

## Phase 4: User Story 2 - Fewer Wrong-Format Summaries (Priority: P2)

**Goal**: Improve “clear case” classification so obvious meetings still map to the right specialized type.

**Independent Test**: Run `swift test` in `MinuteCore/` and verify clear standup/presentation/planning/1:1/design-review examples map correctly.

### Tests for User Story 2 (REQUIRED) ⚠️

- [X] T013 [P] [US2] Add tests for clear Standup snippets → Standup in `MinuteCore/Tests/MinuteCoreTests/Summarization/MeetingTypeClassifierTests.swift`
- [X] T014 [P] [US2] Add tests for clear Presentation snippets → Presentation in `MinuteCore/Tests/MinuteCoreTests/Summarization/MeetingTypeClassifierTests.swift`
- [X] T015 [P] [US2] Add tests for clear Planning snippets → Planning in `MinuteCore/Tests/MinuteCoreTests/Summarization/MeetingTypeClassifierTests.swift`
- [X] T016 [P] [US2] Add tests for clear One-on-One snippets → One-on-One in `MinuteCore/Tests/MinuteCoreTests/Summarization/MeetingTypeClassifierTests.swift`
- [X] T017 [P] [US2] Add tests for clear Design Review snippets → Design Review in `MinuteCore/Tests/MinuteCoreTests/Summarization/MeetingTypeClassifierTests.swift`

### Implementation for User Story 2

- [X] T018 [US2] Refine “strong signals” definitions per type in `MinuteCore/Sources/MinuteCore/Summarization/Services/MeetingTypeClassifier.swift`
- [X] T019 [US2] Add 1–2 clear positive few-shot examples per high-confusion type pair in `MinuteCore/Sources/MinuteCore/Summarization/Services/MeetingTypeClassifier.swift`

**Checkpoint**: US2 complete when clear-case tests are green without increasing false positives for US1.

---

## Phase 5: User Story 3 - Predictable Behavior Under Failure (Priority: P3)

**Goal**: Invalid / messy model output never causes accidental specialized-type selection; fallback remains `General`.

**Independent Test**: Run `swift test` in `MinuteCore/` and verify invalid outputs map to General.

### Tests for User Story 3 (REQUIRED) ⚠️

- [X] T020 [P] [US3] Add tests for outputs with extra text/punctuation → General in `MinuteCore/Tests/MinuteCoreTests/Summarization/MeetingTypeClassifierParseTests.swift`
- [X] T021 [P] [US3] Add tests for multiple labels present → General in `MinuteCore/Tests/MinuteCoreTests/Summarization/MeetingTypeClassifierParseTests.swift`
- [X] T022 [P] [US3] Add tests for empty/whitespace outputs → General in `MinuteCore/Tests/MinuteCoreTests/Summarization/MeetingTypeClassifierParseTests.swift`

### Implementation for User Story 3

- [X] T023 [US3] Tighten parsing to exact-label match only (no substring heuristics) in `MinuteCore/Sources/MinuteCore/Summarization/Services/MeetingTypeClassifier.swift`
- [X] T024 [US3] Ensure any unrecognized/invalid response deterministically maps to `.general` in `MinuteCore/Sources/MinuteCore/Summarization/Services/MeetingTypeClassifier.swift`

**Checkpoint**: US3 complete when parse robustness tests are green.

---

## Phase 6: Polish & Cross-Cutting Concerns

**Purpose**: Performance bounds, determinism, privacy-safe logging, and documentation sync.

- [X] T025 [P] Add a classification settings override (low temp, small max tokens) in `MinuteCore/Sources/MinuteLlama/Services/LlamaLibrarySummarizationService.swift`
- [X] T026 [P] Add a unit test ensuring prompt length stays bounded (no unbounded fixtures) in `MinuteCore/Tests/MinuteCoreTests/Summarization/MeetingTypeClassifierPromptTests.swift`
- [X] T027 Update `specs/005-meeting-type-autodetect/quickstart.md` with the final test command + evaluation notes
- [X] T028 Run `swift test` and record outcomes in `specs/005-meeting-type-autodetect/quickstart.md`

---

## Dependencies & Execution Order

### User Story Completion Order

- US1 → US2 → US3 (US1 provides the core “default-safe” behavior and should land first)

### Phase Dependencies

- Phase 1 (Setup) blocks Phase 2
- Phase 2 (Foundational) blocks all user story phases
- US2 and US3 depend on the fixture/test scaffolding from Phase 2 but are otherwise independent of each other

---

## Parallel Execution Examples

### Foundational (after Setup)

- In parallel:
  - T003 `MinuteCore/Tests/MinuteCoreTests/Fixtures/MeetingTypeClassifierSnippets.swift`
  - T004 `MinuteCore/Tests/MinuteCoreTests/Fixtures/MeetingTypeClassifierExpectedLabels.swift`
  - T005 `MinuteCore/Tests/MinuteCoreTests/Helpers/ClassifierTestHelpers.swift`

### User Story 1

- In parallel:
  - T006/T007/T008 (different test sections) in `MinuteCore/Tests/MinuteCoreTests/Summarization/MeetingTypeClassifierTests.swift`
  - T009 in `MinuteCore/Tests/MinuteCoreTests/Summarization/MeetingTypeClassifierPromptTests.swift`

---

## Implementation Strategy

### MVP Scope

- Complete Phases 1–3 (US1). Stop and validate with `swift test` in `MinuteCore/`.

### Incremental Delivery

- Land US1 first (safe default)
- Then add US2 (clear-case accuracy) while keeping US1 tests green
- Then add US3 (robustness to invalid output)

