---

description: "Task list for Swift Testing refactor and coverage improvements"
---

# Tasks: Swift Testing Refactor and Coverage

**Input**: Design documents from `/specs/001-swift-testing-refactor/`
**Prerequisites**: plan.md (required), spec.md (required), research.md, data-model.md, contracts/

**Tests**: Tests are REQUIRED for this feature because it is a test migration and coverage expansion.

**Organization**: Tasks are grouped by user story to enable independent implementation and testing of each story.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2, US3)
- Include exact file paths in descriptions

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Project initialization and baseline documentation

- [x] T001 Create test inventory in `docs/testing/test-inventory.md`
- [x] T002 Create coverage targets doc in `docs/testing/coverage-targets.md`

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Definitions required before migration and coverage expansion

**⚠️ CRITICAL**: No user story work can begin until this phase is complete

- [x] T003 Define critical paths in `docs/testing/critical-paths.md`
- [x] T004 Define migration exception log format in `docs/testing/migration-exceptions.md`

**Checkpoint**: Foundation ready - user story implementation can now begin in parallel

---

## Phase 3: User Story 1 - Reliable Test Migration (Priority: P1) 🎯 MVP

**Goal**: Migrate all existing automated tests across targets to Swift Testing without losing intent or coverage.

**Independent Test**: Run the full test suite and verify equivalent or improved coverage compared to the pre-migration suite.

### Tests for User Story 1 (REQUIRED) ⚠️

> **NOTE: Write these tests FIRST, ensure they FAIL before implementation**

- [x] T005 [P] [US1] Add Swift Testing helpers in `MinuteCore/Tests/MinuteCoreTests/TestSupport/SwiftTestingSupport.swift`

### Implementation for User Story 1

- [x] T006 [P] [US1] Migrate Markdown/rendering tests to Swift Testing in `MinuteCore/Tests/MinuteCoreTests/TranscriptMarkdownRendererTests.swift`
- [x] T007 [P] [US1] Migrate Markdown/rendering tests to Swift Testing in `MinuteCore/Tests/MinuteCoreTests/MarkdownRendererEscapingTests.swift`
- [x] T008 [P] [US1] Migrate Markdown/rendering tests to Swift Testing in `MinuteCore/Tests/MinuteCoreTests/MarkdownRendererGoldenTests.swift`
- [x] T009 [P] [US1] Migrate file contract tests to Swift Testing in `MinuteCore/Tests/MinuteCoreTests/MeetingFileContractTests.swift`
- [x] T010 [P] [US1] Migrate audio/format tests to Swift Testing in `MinuteCore/Tests/MinuteCoreTests/AudioWavConverterTests.swift`
- [x] T011 [P] [US1] Migrate audio/format tests to Swift Testing in `MinuteCore/Tests/MinuteCoreTests/ContractWavPCMReaderTests.swift`
- [x] T012 [P] [US1] Migrate transcription pipeline tests to Swift Testing in `MinuteCore/Tests/MinuteCoreTests/WhisperTranscriptionServiceTests.swift`
- [x] T013 [P] [US1] Migrate transcription pipeline tests to Swift Testing in `MinuteCore/Tests/MinuteCoreTests/LiveTranscriptionSessionTests.swift`
- [x] T014 [P] [US1] Migrate transcription pipeline tests to Swift Testing in `MinuteCore/Tests/MinuteCoreTests/LiveAudioTranscriptionQueueTests.swift`
- [x] T015 [P] [US1] Migrate pipeline coordinator tests to Swift Testing in `MinuteCore/Tests/MinuteCoreTests/MeetingPipelineCoordinatorTests.swift`
- [x] T016 [P] [US1] Migrate recovery/service tests to Swift Testing in `MinuteCore/Tests/MinuteCoreTests/RecordingRecoveryServiceTests.swift`
- [x] T017 [P] [US1] Migrate normalization tests to Swift Testing in `MinuteCore/Tests/MinuteCoreTests/StringNormalizerTests.swift`
- [x] T018 [P] [US1] Migrate normalization tests to Swift Testing in `MinuteCore/Tests/MinuteCoreTests/WhisperTranscriptNormalizerTests.swift`
- [x] T019 [P] [US1] Migrate normalization tests to Swift Testing in `MinuteCore/Tests/MinuteCoreTests/ScreenContextTimestampNormalizerTests.swift`
- [x] T020 [P] [US1] Migrate model/config tests to Swift Testing in `MinuteCore/Tests/MinuteCoreTests/WhisperModelPathsTests.swift`
- [x] T021 [P] [US1] Migrate model/config tests to Swift Testing in `MinuteCore/Tests/MinuteCoreTests/DefaultModelManagerTests.swift`
- [x] T022 [P] [US1] Migrate app configuration tests to Swift Testing in `MinuteCore/Tests/MinuteCoreTests/AppConfigurationTests.swift`
- [x] T023 [P] [US1] Migrate error handling tests to Swift Testing in `MinuteCore/Tests/MinuteCoreTests/ErrorHandlerTests.swift`
- [x] T024 [P] [US1] Migrate transcript/meeting decoding tests to Swift Testing in `MinuteCore/Tests/MinuteCoreTests/MeetingExtractionDecodingTests.swift`
- [x] T025 [P] [US1] Migrate vault browser tests to Swift Testing in `MinuteCore/Tests/MinuteCoreTests/VaultMeetingNotesBrowserTests.swift`
- [x] T026 [P] [US1] Migrate screen context tests to Swift Testing in `MinuteCore/Tests/MinuteCoreTests/ScreenContextAggregatorTests.swift`
- [x] T027 [P] [US1] Migrate selection store tests to Swift Testing in `MinuteCore/Tests/MinuteCoreTests/TranscriptionBackendSelectionStoreTests.swift`
- [x] T028 [P] [US1] Migrate filename sanitization tests to Swift Testing in `MinuteCore/Tests/MinuteCoreTests/FilenameSanitizerTests.swift`
- [x] T029 [P] [US1] Migrate JSON extraction tests to Swift Testing in `MinuteCore/Tests/MinuteCoreTests/JSONFirstObjectExtractorTests.swift`
- [x] T030 [P] [US1] Migrate smoke tests to Swift Testing in `MinuteCore/Tests/MinuteCoreTests/MinuteCoreTests.swift`
- [x] T031 [US1] Record any migration exceptions and follow-up issues in `docs/testing/migration-exceptions.md`

**Checkpoint**: User Story 1 is functional and testable independently

---

## Phase 4: User Story 2 - Coverage Expansion (Priority: P2)

**Goal**: Expand automated coverage for the output contract and pipeline.

**Independent Test**: Run the test suite and confirm critical-path behaviors are covered and enforced by tests.

### Tests for User Story 2 (REQUIRED) ⚠️

- [x] T032 [P] [US2] Add pipeline critical-path coverage tests in `MinuteCore/Tests/MinuteCoreTests/PipelineCriticalPathCoverageTests.swift`
- [x] T033 [P] [US2] Add output contract coverage tests in `MinuteCore/Tests/MinuteCoreTests/OutputContractCoverageTests.swift`
- [x] T034 [P] [US2] Add vault write coverage tests in `MinuteCore/Tests/MinuteCoreTests/VaultWriteCoverageTests.swift`

### Implementation for User Story 2

- [x] T035 [US2] Expand existing tests to meet overall and critical-path coverage targets in `MinuteCore/Tests/MinuteCoreTests/`

**Checkpoint**: User Stories 1 AND 2 are independently functional

---

## Phase 5: User Story 3 - Coverage Visibility (Priority: P3)

**Goal**: Provide readable coverage summaries with optional machine output.

**Independent Test**: Run the suite and verify the human-readable summary is available, and that the optional machine-readable report can be generated.

### Tests for User Story 3 (REQUIRED) ⚠️

- [x] T036 [P] [US3] Add coverage summary validation tests in `MinuteCore/Tests/MinuteCoreTests/CoverageSummaryTests.swift`

### Implementation for User Story 3

- [x] T037 [US3] Add coverage summary script in `scripts/coverage/generate-coverage-summary.sh`
- [x] T038 [US3] Add optional machine-report flag handling in `scripts/coverage/generate-coverage-summary.sh`
- [x] T039 [US3] Document coverage summary usage in `docs/testing/coverage-summary.md`

**Checkpoint**: All user stories independently functional

---

## Phase N: Polish & Cross-Cutting Concerns

**Purpose**: Improvements that affect multiple user stories

- [x] T040 [P] Update quickstart and test instructions in `specs/001-swift-testing-refactor/quickstart.md`
- [x] T041 [P] Clean up deprecated XCTest references in `MinuteCore/Tests/MinuteCoreTests/MinuteCoreTests.swift`
- [x] T042 Run full test suite and document results in `specs/001-swift-testing-refactor/test-run-results.md`

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies - can start immediately
- **Foundational (Phase 2)**: Depends on Setup completion - BLOCKS all user stories
- **User Stories (Phase 3+)**: All depend on Foundational phase completion
- **Polish (Final Phase)**: Depends on all desired user stories being complete

### User Story Dependencies

- **User Story 1 (P1)**: Can start after Foundational - no dependencies
- **User Story 2 (P2)**: Can start after Foundational - depends on US1 migration
- **User Story 3 (P3)**: Can start after Foundational - can run after US1, but best after US2 so coverage targets exist

### Within Each User Story

- Tests (if included) MUST be written and FAIL before implementation
- Core migration before coverage expansion
- Coverage summary scripts after coverage targets defined

### Parallel Opportunities

- T006-T030 can run in parallel by test file
- T032-T034 can run in parallel by coverage area
- T036 can run in parallel with T037-T039 after US1 migration completes

---

## Parallel Example: User Story 1

```bash
Task: "Migrate Markdown/rendering tests in MinuteCore/Tests/MinuteCoreTests/TranscriptMarkdownRendererTests.swift"
Task: "Migrate audio/format tests in MinuteCore/Tests/MinuteCoreTests/AudioWavConverterTests.swift"
Task: "Migrate pipeline coordinator tests in MinuteCore/Tests/MinuteCoreTests/MeetingPipelineCoordinatorTests.swift"
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Complete Phase 1: Setup
2. Complete Phase 2: Foundational
3. Complete Phase 3: User Story 1
4. **STOP and VALIDATE**: Run the full test suite and verify equivalence

### Incremental Delivery

1. Setup + Foundational → Foundation ready
2. US1 Migration → Validate suite
3. US2 Coverage Expansion → Validate targets
4. US3 Coverage Visibility → Validate summary outputs
5. Polish tasks → Final verification
