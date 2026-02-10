---

description: "Task list for Main UI Refactor (Recording Stage)"

---

# Tasks: Main UI Refactor (Recording Stage)

**Input**: Design documents from `specs/008-main-ui-refactor/`

## Phase 1: Setup (Shared Infrastructure)

- [X] T001 Confirm current Stage + control bar touchpoints in Minute/Sources/Views/ContentView.swift and Minute/Sources/ViewModels/MeetingPipelineViewModel.swift
- [X] T002 Add Stage preference defaults keys in MinuteCore/Sources/MinuteCore/Configuration/AppConfiguration.swift
- [X] T003 [P] Create LanguageProcessingProfile domain type in MinuteCore/Sources/MinuteCore/Domain/LanguageProcessingProfile.swift
- [X] T004 [P] Create StagePreferences domain type in MinuteCore/Sources/MinuteCore/Domain/StagePreferences.swift

---

## Phase 2: Foundational (Blocking Prerequisites)

- [X] T005 Implement StagePreferencesStore (UserDefaults-backed) in MinuteCore/Sources/MinuteCore/Services/StagePreferencesStore.swift
- [X] T006 [P] Add StagePreferencesStore round-trip + defaulting tests in MinuteCore/Tests/MinuteCoreTests/StagePreferencesStoreTests.swift
- [X] T007 Extend PipelineContext to include languageProcessing in MinuteCore/Sources/MinuteCore/Pipeline/PipelineTypes.swift
- [X] T008 Update SummarizationServicing to accept languageProcessing in MinuteCore/Sources/MinuteCore/Services/ServiceProtocols.swift
- [X] T009 Update LlamaLibrarySummarizationService to accept languageProcessing in MinuteCore/Sources/MinuteLlama/Services/LlamaLibrarySummarizationService.swift
- [X] T010 [P] Update MockSummarizationService signatures for languageProcessing in MinuteCore/Sources/MinuteCore/Services/MockServices.swift
- [X] T011 Update prompt generation to apply LanguageProcessingProfile deterministically in MinuteCore/Sources/MinuteCore/Summarization/Prompts/PromptFactory.swift
- [X] T012 [P] Add deterministic prompt test coverage for languageProcessing in MinuteCore/Tests/MinuteCoreTests/PromptFactoryLanguageProcessingTests.swift
- [X] T013 Refactor MeetingPipelineCoordinator to thread languageProcessing through execute() in MinuteCore/Sources/MinuteCore/Pipeline/MeetingPipelineCoordinator.swift
- [X] T014 Update MeetingPipelineViewModel.makePipelineContext to include languageProcessing in Minute/Sources/ViewModels/MeetingPipelineViewModel.swift
- [X] T015 Add cancelRecording() to AudioServicing protocol in MinuteCore/Sources/MinuteCore/Services/ServiceProtocols.swift
- [X] T016 Implement cancelRecording() cleanup in MinuteCore/Sources/MinuteCore/Services/DefaultAudioService.swift
- [X] T017 [P] Update MockAudioService cancelRecording() in MinuteCore/Sources/MinuteCore/Services/MockServices.swift

**Checkpoint**: Core models + stores exist; pipeline context carries meetingType + languageProcessing; audio cancellation is available.

---

## Phase 3: User Story 1 — Record from the Stage (Priority: P1) 🎯 MVP

**Goal**: Set up and start/stop/cancel a recording from the main view with clear status + elapsed time, while keeping Stage controls editable during recording.

**Independent Test**: Launch app with no meeting selected → adjust Stage controls → start recording → observe status/timer/levels → stop recording and confirm normal processing; start again and cancel and confirm no meeting outputs created.

### Tests for User Story 1 (REQUIRED)

- [X] T018 [P] [US1] Add MeetingPipelineAction.cancelRecording in MinuteCore/Sources/MinuteCore/Domain/MeetingPipelineTypes.swift and cover decoding/Sendable compilation in MinuteCore/Tests/MinuteCoreTests/MinuteCoreTests.swift
- [X] T019 [P] [US1] Add MeetingPipelineCoordinator languageProcessing plumbing test in MinuteCore/Tests/MinuteCoreTests/MeetingPipelineCoordinatorLanguageProcessingTests.swift
- [X] T020 [P] [US1] Add StagePreferencesStore default-migration test (no existing keys) in MinuteCore/Tests/MinuteCoreTests/StagePreferencesStoreMigrationTests.swift
- [X] T021 [US1] Add app-level cancel-session behavior test (no enqueue / no state .recorded) in MinuteTests/MeetingPipelineViewModelCancelSessionTests.swift

### Implementation for User Story 1

- [X] T022 [US1] Load persisted StagePreferences into MeetingPipelineViewModel on init in Minute/Sources/ViewModels/MeetingPipelineViewModel.swift
- [X] T023 [US1] Persist meetingType + languageProcessing on change in Minute/Sources/ViewModels/MeetingPipelineViewModel.swift
- [X] T024 [US1] Add MeetingPipelineAction.cancelRecording handling to MeetingPipelineViewModel.send(_:) in Minute/Sources/ViewModels/MeetingPipelineViewModel.swift
- [X] T025 [US1] Implement cancelSessionIfAllowed() to stop capture, clear screen/audio monitoring, and return to .idle with no enqueue in Minute/Sources/ViewModels/MeetingPipelineViewModel.swift
- [X] T026 [US1] Ensure cancel session removes temp session directory via AudioServicing.cancelRecording() in MinuteCore/Sources/MinuteCore/Services/DefaultAudioService.swift
- [X] T027 [US1] Replace idle DailyBriefingView with a centered Stage card container in Minute/Sources/Views/ContentView.swift
- [X] T028 [US1] Add Meeting Type selector to Stage card (binds to model.meetingType) in Minute/Sources/Views/ContentView.swift
- [X] T029 [US1] Add Language Processing selector to Stage card (binds to model.languageProcessing) in Minute/Sources/Views/ContentView.swift
- [X] T030 [US1] Replace AudioModeControl with independent mic/system toggles in Minute/Sources/Views/ContentView.swift
- [X] T031 [US1] Wire mic/system toggles to model.setMicrophoneCaptureEnabled and model.setSystemAudioCaptureEnabled in Minute/Sources/Views/ContentView.swift
- [X] T032 [US1] Add screen/window selection control and current selection display in Minute/Sources/Views/ContentView.swift
- [X] T033 [US1] Ensure Stage controls remain enabled during recording per spec in Minute/Sources/Views/ContentView.swift
- [X] T034 [US1] Add “session in progress” message below header while recording in Minute/Sources/Views/ContentView.swift
- [X] T035 [US1] Add input-level indicator semantics (isListening + levels) to RecordingStageView in Minute/Sources/Views/ContentView.swift
- [X] T036 [US1] Update FloatingControlBar to show status label + elapsed timer in Minute/Sources/Views/ContentView.swift
- [X] T037 [US1] Add Cancel Session affordance to FloatingControlBar when recording in Minute/Sources/Views/ContentView.swift
- [X] T038 [US1] Route Cancel Session button to model.send(.cancelRecording) in Minute/Sources/Views/ContentView.swift
- [X] T039 [US1] Ensure start/stop/cancel trigger tactile feedback on macOS in Minute/Sources/Views/ContentView.swift

**Checkpoint**: US1 is complete when start/stop/cancel works end-to-end from Stage and tests pass.

---

## Phase 4: User Story 2 — Import audio from the Stage (Priority: P2)

**Goal**: When not recording, show an obvious drop zone in the Stage card that accepts supported audio (and existing supported media) and starts processing.

**Independent Test**: With no meeting selected and not recording, drag a supported file over the Stage → drop → pipeline moves to importing/recorded/processing states.

### Tests for User Story 2 (REQUIRED)

- [X] T040 [P] [US2] Add supported-media validation tests for Stage drop handler in MinuteTests/StageDropValidationTests.swift

### Implementation for User Story 2

- [X] T041 [US2] Add explicit upload/drop zone view in the Stage card (idle only) in Minute/Sources/Views/ContentView.swift
- [X] T042 [US2] Visually highlight the drop zone when isDropTargeted is true in Minute/Sources/Views/ContentView.swift
- [X] T043 [US2] Ensure drop zone is replaced by live visualizer while recording in Minute/Sources/Views/ContentView.swift
- [X] T044 [US2] Show concise unsupported-file error (no transcript leakage) in Minute/Sources/Views/ContentView.swift
- [X] T045 [US2] Ensure Stage upload button continues to invoke fileImporter path in Minute/Sources/Views/ContentView.swift

**Checkpoint**: US2 is complete when import is discoverable from Stage and unsupported files show a concise error.

---

## Phase 5: User Story 3 — View selected meeting (no regressions) (Priority: P3)

**Goal**: Preserve existing meeting detail experience when a meeting is selected.

**Independent Test**: Select an existing meeting from the sidebar → overlay/detail behaves exactly as before; analysis actions still work.

### Tests for User Story 3

- [X] T046 [P] [US3] Add smoke test covering “select meeting shows overlay” flow in MinuteTests/MeetingDetailNoRegressionSmokeTests.swift

### Implementation for User Story 3

- [X] T047 [US3] Verify MainStageView vs MarkdownViewerOverlay switching remains unchanged in Minute/Sources/Views/ContentView.swift

---

## Phase 6: Polish & Cross-Cutting Concerns

- [X] T048 [P] Audit accessibility labels/focus order for Stage controls + FloatingControlBar in Minute/Sources/Views/ContentView.swift
- [X] T049 Ensure privacy-safe logging: avoid logging raw transcript content in Minute/Sources/ViewModels/MeetingPipelineViewModel.swift and MinuteCore/Sources/MinuteCore/Pipeline/MeetingPipelineCoordinator.swift
- [ ] T050 Validate cancellation behavior does not leave stray files in temp or vault (manual QA) per specs/008-main-ui-refactor/quickstart.md
- [X] T051 Run quickstart test commands and ensure green: specs/008-main-ui-refactor/quickstart.md

---

## Dependencies & Execution Order

- Phase 1 (Setup) blocks Phase 2
- Phase 2 (Foundational) blocks all user stories
- US1 (P1) should be implemented first as MVP
- US2 (P2) can follow once Stage UI exists (or be parallelized after Phase 2)
- US3 (P3) is a verification pass and can run anytime after US1 UI refactor is underway

### User Story Dependencies

- US1 depends on Phase 2 (preferences + language plumbing + cancel recording)
- US2 depends on US1 Stage card shell (or can start once the Stage card exists)
- US3 depends on US1 changes being in place to verify no regressions

---

## Parallel Execution Examples

### After Foundational (Phase 2)

Example parallel picks:

T019 [US1] MeetingPipelineCoordinator languageProcessing plumbing test in MinuteCore/Tests/MinuteCoreTests/MeetingPipelineCoordinatorLanguageProcessingTests.swift
T021 [US1] MeetingPipelineViewModel cancel-session behavior test in MinuteTests/MeetingPipelineViewModelCancelSessionTests.swift
T040 [US2] Stage drop validation tests in MinuteTests/StageDropValidationTests.swift

---

## Implementation Strategy

- Implement Phase 1–2 first to establish the domain/store/pipeline plumbing safely.
- Deliver MVP as US1 only (Stage card + floating bar + start/stop/cancel) and stop to validate.
- Add US2 drop zone and UX polish.
- Finish with US3 no-regressions verification and cross-cutting accessibility/privacy checks.
