# Tasks: Reprocess Meeting Type

**Input**: Design documents from `/specs/016-reprocess-meeting-type/`
**Prerequisites**: plan.md (required), spec.md (required for user stories), research.md, data-model.md, contracts/

**Tests**: Tests are REQUIRED for this feature because it changes MinuteCore behavior, transcript rendering, and a contract-sensitive recovery flow.

**Organization**: Tasks are grouped by user story so each story can be implemented and tested independently.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., [US1], [US2], [US3])
- Every task includes the exact file path to change

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Add shared fixtures and scaffolding for transcript-based reprocessing work.

- [x] T001 [P] Add transcript reprocessing fixtures and helpers in `/Users/roblibob/Projects/FLX/Minute/Minute/MinuteCore/Tests/MinuteCoreTests/TestSupport/ReprocessMeetingFixtures.swift`
- [x] T002 [P] Add meeting notes browser reprocessing test support in `/Users/roblibob/Projects/FLX/Minute/Minute/MinuteTests/TestSupport/ReprocessMeetingBrowserTestSupport.swift`

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Define shared reprocessing types and browser metadata support that all user stories depend on.

**⚠️ CRITICAL**: No user story work can begin until this phase is complete.

- [x] T003 Define transcript timeline and reprocess request/availability types in `/Users/roblibob/Projects/FLX/Minute/Minute/MinuteCore/Sources/MinuteCore/Pipeline/PipelineTypes.swift`
- [x] T004 [P] Extend meeting note parsing utilities with note metadata extraction hooks in `/Users/roblibob/Projects/FLX/Minute/Minute/MinuteCore/Sources/MinuteCore/Rendering/MeetingNoteParsing.swift`
- [x] T005 Extend vault meeting browser metadata loading for current meeting type and transcript availability in `/Users/roblibob/Projects/FLX/Minute/Minute/MinuteCore/Sources/MinuteCore/Services/VaultMeetingNotesBrowser.swift`

**Checkpoint**: Shared reprocessing types and processed-meeting metadata are ready; user stories can now proceed.

---

## Phase 3: User Story 1 - Reprocess a misclassified meeting (Priority: P1) 🎯 MVP

**Goal**: Let users regenerate a processed meeting note from its saved transcript using a different explicit meeting type, without rewriting transcript or audio artifacts.

**Independent Test**: Open a processed meeting with a transcript, choose a different explicit meeting type, run reprocessing, and verify only the meeting note is regenerated while transcript/audio remain unchanged.

### Tests for User Story 1 (REQUIRED) ⚠️

> **NOTE: Write these tests FIRST, ensure they FAIL before implementation**

- [X] T006 [P] [US1] Add note-only reprocessing coordinator tests in `/Users/roblibob/Projects/FLX/Minute/Minute/MinuteCore/Tests/MinuteCoreTests/MeetingPipelineCoordinatorReprocessingTests.swift`
- [X] T007 [P] [US1] Add file-contract coverage for reprocessing writes in `/Users/roblibob/Projects/FLX/Minute/Minute/MinuteCore/Tests/MinuteCoreTests/VaultWriteCoverageTests.swift`
- [X] T008 [P] [US1] Add meeting notes browser reprocessing validation tests in `/Users/roblibob/Projects/FLX/Minute/Minute/MinuteTests/MeetingNotesBrowserViewModelReprocessingTests.swift`

### Implementation for User Story 1

- [X] T009 [US1] Implement reprocess request validation and explicit-target rules in `/Users/roblibob/Projects/FLX/Minute/Minute/MinuteCore/Sources/MinuteCore/Pipeline/PipelineTypes.swift`
- [X] T010 [US1] Add transcript-to-summarization source reconstruction helpers in `/Users/roblibob/Projects/FLX/Minute/Minute/MinuteCore/Sources/MinuteCore/Rendering/MeetingNoteParsing.swift`
- [X] T011 [US1] Implement note-only reprocessing orchestration in `/Users/roblibob/Projects/FLX/Minute/Minute/MinuteCore/Sources/MinuteCore/Pipeline/MeetingPipelineCoordinator.swift`
- [X] T012 [US1] Preserve owned participant frontmatter during note regeneration in `/Users/roblibob/Projects/FLX/Minute/Minute/MinuteCore/Sources/MinuteCore/Pipeline/MeetingPipelineCoordinator.swift`
- [X] T013 [US1] Add meeting notes browser state and shared `Resummarize as…` actions for explicit-type reprocessing in `/Users/roblibob/Projects/FLX/Minute/Minute/Minute/Sources/Views/MeetingNotes/MeetingNotesBrowserViewModel.swift`
- [X] T014 [US1] Add `Resummarize as…` to the meeting row context menu in `/Users/roblibob/Projects/FLX/Minute/Minute/Minute/Sources/Views/MeetingNotes/MeetingNotesSidebarView.swift`
- [X] T015 [US1] Add `Resummarize as…` to the meatball menu in `/Users/roblibob/Projects/FLX/Minute/Minute/Minute/Sources/Views/MeetingNotes/MarkdownViewerOverlay.swift`
- [X] T016 [US1] Exclude `Autodetect` from reprocess target selection and enforce different-type validation in `/Users/roblibob/Projects/FLX/Minute/Minute/Minute/Sources/Views/MeetingNotes/MeetingNotesBrowserViewModel.swift`

**Checkpoint**: User Story 1 is independently functional and testable as the MVP.

---

## Phase 4: User Story 2 - Screen context survives into transcript-based reprocessing (Priority: P2)

**Goal**: Persist screen context in the transcript as clearly labeled timeline entries and reuse that durable context during later reprocessing.

**Independent Test**: Process a meeting with screen context enabled, verify the transcript contains chronological `Screen Context` entries, then reprocess the meeting and confirm those entries are reused as source material.

### Tests for User Story 2 (REQUIRED) ⚠️

- [X] T017 [P] [US2] Add transcript renderer tests for screen context timeline entries in `/Users/roblibob/Projects/FLX/Minute/Minute/MinuteCore/Tests/MinuteCoreTests/TranscriptMarkdownRendererScreenContextTests.swift`
- [X] T018 [P] [US2] Add transcript timeline parsing round-trip tests in `/Users/roblibob/Projects/FLX/Minute/Minute/MinuteCore/Tests/MinuteCoreTests/MeetingNoteParsingScreenContextTests.swift`
- [X] T019 [P] [US2] Add pipeline coverage for screen context transcript persistence in `/Users/roblibob/Projects/FLX/Minute/Minute/MinuteCore/Tests/MinuteCoreTests/MeetingPipelineCoordinatorSpeakerTranscriptTests.swift`

### Implementation for User Story 2

- [X] T020 [US2] Extend transcript timeline domain models for screen context entries in `/Users/roblibob/Projects/FLX/Minute/Minute/MinuteCore/Sources/MinuteCore/Domain/ScreenContext.swift`
- [X] T021 [US2] Implement deterministic screen context rendering in `/Users/roblibob/Projects/FLX/Minute/Minute/MinuteCore/Sources/MinuteCore/Rendering/TranscriptMarkdownRenderer.swift`
- [X] T022 [US2] Implement screen context timeline parsing helpers in `/Users/roblibob/Projects/FLX/Minute/Minute/MinuteCore/Sources/MinuteCore/Rendering/MeetingNoteParsing.swift`
- [X] T023 [US2] Pass persisted screen context into transcript writes in `/Users/roblibob/Projects/FLX/Minute/Minute/MinuteCore/Sources/MinuteCore/Pipeline/MeetingPipelineCoordinator.swift`
- [X] T024 [US2] Feed parsed screen context entries back into the reprocessing source assembly in `/Users/roblibob/Projects/FLX/Minute/Minute/MinuteCore/Sources/MinuteCore/Pipeline/MeetingPipelineCoordinator.swift`

**Checkpoint**: User Stories 1 and 2 both work independently; transcript durability now includes screen context.

---

## Phase 5: User Story 3 - Reprocess availability is explicit and safe (Priority: P3)

**Goal**: Surface clear reprocess availability, transcript-required blocking, and overwrite confirmation when edited notes are detected.

**Independent Test**: Attempt reprocessing with a missing transcript, the same current meeting type, and an edited note; verify the browser explains the block reasons and prompts overwrite or cancel before rewriting the note.

### Tests for User Story 3 (REQUIRED) ⚠️

- [X] T025 [P] [US3] Add reprocess availability and blocking-reason tests in `/Users/roblibob/Projects/FLX/Minute/Minute/MinuteCore/Tests/MinuteCoreTests/VaultMeetingNotesBrowserTests.swift`
- [X] T026 [P] [US3] Add overwrite confirmation and disabled-menu state tests in `/Users/roblibob/Projects/FLX/Minute/Minute/MinuteTests/MeetingNotesBrowserViewModelReprocessingTests.swift`
- [X] T027 [P] [US3] Add note-edit detection and cancel-path tests in `/Users/roblibob/Projects/FLX/Minute/Minute/MinuteCore/Tests/MinuteCoreTests/MeetingPipelineCoordinatorReprocessingTests.swift`

### Implementation for User Story 3

- [X] T028 [US3] Implement reprocess availability resolution and blocking reasons in `/Users/roblibob/Projects/FLX/Minute/Minute/MinuteCore/Sources/MinuteCore/Services/VaultMeetingNotesBrowser.swift`
- [X] T029 [US3] Add edited-note detection helpers for managed note overwrite gating in `/Users/roblibob/Projects/FLX/Minute/Minute/MinuteCore/Sources/MinuteCore/Rendering/MeetingNoteParsing.swift`
- [X] T030 [US3] Add overwrite-or-cancel guardrails before note rewrites in `/Users/roblibob/Projects/FLX/Minute/Minute/Minute/Sources/Views/MeetingNotes/MeetingNotesBrowserViewModel.swift`
- [X] T031 [US3] Surface transcript-missing and invalid-target error messaging and disabled menu state in `/Users/roblibob/Projects/FLX/Minute/Minute/Minute/Sources/Views/MeetingNotes/MeetingNotesBrowserViewModel.swift`

**Checkpoint**: All user stories are independently functional, including safety and availability messaging.

---

## Phase 6: Polish & Cross-Cutting Concerns

**Purpose**: Finalize documentation, regression coverage, and end-to-end validation across all stories.

- [X] T032 [P] Update feature validation notes and test commands in `/Users/roblibob/Projects/FLX/Minute/Minute/specs/016-reprocess-meeting-type/quickstart.md`
- [X] T033 Verify reprocess contract documentation stays aligned with implementation in `/Users/roblibob/Projects/FLX/Minute/Minute/specs/016-reprocess-meeting-type/contracts/openapi.yaml`
- [X] T034 Run `swift test --package-path MinuteCore` and record outcomes in `/Users/roblibob/Projects/FLX/Minute/Minute/specs/016-reprocess-meeting-type/quickstart.md`
- [X] T035 Run `xcodebuild -project Minute.xcodeproj -scheme Minute -configuration Debug test` and record outcomes in `/Users/roblibob/Projects/FLX/Minute/Minute/specs/016-reprocess-meeting-type/quickstart.md`

---

## Dependencies & Execution Order

### Phase Dependencies

- **Phase 1: Setup**: No dependencies; can start immediately.
- **Phase 2: Foundational**: Depends on Phase 1 and blocks all user stories.
- **Phase 3: User Story 1**: Depends on Phase 2; this is the MVP.
- **Phase 4: User Story 2**: Depends on Phase 2 and builds on the note-only reprocess path from US1.
- **Phase 5: User Story 3**: Depends on Phase 2 and can begin after the shared reprocess state exists; it complements US1 safety behavior.
- **Phase 6: Polish**: Depends on all desired user stories being complete.

### User Story Dependencies

- **US1 (P1)**: Starts after Foundational; no dependency on US2 or US3.
- **US2 (P2)**: Starts after Foundational; reuses the reprocessing path from US1 but remains independently testable by validating transcript persistence and reuse.
- **US3 (P3)**: Starts after Foundational; adds explicit availability and overwrite safety around the same browser flow.

### Within Each User Story

- Tests MUST be written and fail before implementation.
- Shared parsing/domain updates come before orchestration changes.
- MinuteCore behavior comes before browser/view-model integration.
- Story validation must pass before moving to the next priority.

### Parallel Opportunities

- T001 and T002 can run in parallel.
- T004 and T005 can run in parallel after T003.
- For US1, T006-T008 can run in parallel, then T009-T010, followed by T011-T014.
- For US2, T015-T017 can run in parallel, then T018-T020, followed by T021-T022.
- For US3, T023-T025 can run in parallel, then T026-T029.
- T032-T033 can run in parallel before the final test execution tasks.

---

## Parallel Example: User Story 1

```bash
# Launch US1 tests together
Task: "Add note-only reprocessing coordinator tests in MinuteCore/Tests/MinuteCoreTests/MeetingPipelineCoordinatorReprocessingTests.swift"
Task: "Add file-contract coverage for reprocessing writes in MinuteCore/Tests/MinuteCoreTests/VaultWriteCoverageTests.swift"
Task: "Add meeting notes browser reprocessing validation tests in MinuteTests/MeetingNotesBrowserViewModelReprocessingTests.swift"

# Launch US1 shared implementation work together after tests fail
Task: "Implement reprocess request validation and explicit-target rules in MinuteCore/Sources/MinuteCore/Pipeline/PipelineTypes.swift"
Task: "Add transcript-to-summarization source reconstruction helpers in MinuteCore/Sources/MinuteCore/Rendering/MeetingNoteParsing.swift"
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Complete Phase 1: Setup
2. Complete Phase 2: Foundational
3. Complete Phase 3: User Story 1
4. **STOP and VALIDATE**: Reprocess a meeting from its transcript and confirm only the note changes
5. Demo/deploy the MVP if appropriate

### Incremental Delivery

1. Finish Setup + Foundational
2. Deliver US1 for note-only reprocessing
3. Add US2 for persisted screen context timeline support
4. Add US3 for availability messaging and overwrite safeguards
5. Finish with documentation and full test validation

### Parallel Team Strategy

1. One developer completes Setup + Foundational
2. Then split by story:
   - Developer A: US1 coordinator + note regeneration
   - Developer B: US2 transcript timeline persistence/parsing
   - Developer C: US3 browser safety and confirmation behavior
3. Recombine for Phase 6 validation

---

## Notes

- [P] tasks touch different files and can be executed concurrently.
- Each user story remains independently testable.
- The feature must preserve the three-file contract at all times.
- Do not add a save-as-new path or any fourth artifact during implementation.