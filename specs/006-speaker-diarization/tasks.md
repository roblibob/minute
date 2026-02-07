# Tasks: Speaker Diarization & Identification

**Input**: Design documents in `specs/006-speaker-diarization/` (plan.md, spec.md, research.md, data-model.md, contracts/openapi.yaml, quickstart.md)

**Tests**: REQUIRED (Swift Testing). All rendering/frontmatter changes must be deterministic and covered by golden/contract tests in `MinuteCore/Tests/MinuteCoreTests/`.

**Organization**: Tasks are grouped by user story (US1/US2/US3) to enable independent implementation and testing.

## Phase 1: Setup (Shared Infrastructure)

- [x] T001 Add diarization/speaker fixtures helpers in MinuteCore/Tests/MinuteCoreTests/Helpers/SpeakerDiarizationTestData.swift
- [x] T002 [P] Add transcript golden fixtures for speaker headings in MinuteCore/Tests/MinuteCoreTests/Fixtures/Transcript/speaker_headings.md
- [x] T003 [P] Add meeting-note frontmatter fixtures for participant metadata in MinuteCore/Tests/MinuteCoreTests/Fixtures/Frontmatter/participants_and_speaker_map.md

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Shared primitives and safe file-editing utilities used across stories (determinism + “do not overwrite user edits”).

- [x] T004 Define participant + speaker-map domain models in MinuteCore/Sources/MinuteCore/Domain/MeetingParticipantFrontmatter.swift
- [x] T005 Implement deterministic YAML frontmatter encode/decode helpers in MinuteCore/Sources/MinuteCore/Rendering/YAMLFrontmatterCodec.swift
- [x] T006 Implement “update only owned frontmatter keys” editor in MinuteCore/Sources/MinuteCore/Rendering/MeetingFrontmatterEditor.swift
- [x] T007 Add unit tests for frontmatter editor preserving body/unrelated keys in MinuteCore/Tests/MinuteCoreTests/MeetingFrontmatterEditorTests.swift
- [x] T008 Add meeting-note speaker-map persistence service (frontmatter-only; no extra vault files) in MinuteCore/Sources/MinuteCore/Services/MeetingSpeakerNamingService.swift
- [x] T009 Add atomic write + determinism tests for MeetingSpeakerNamingService in MinuteCore/Tests/MinuteCoreTests/MeetingSpeakerNamingServiceTests.swift


**Checkpoint**: Frontmatter edits are deterministic, atomic, and preserve user content.

---

## Phase 3: User Story 1 — Speaker-labeled transcript is accurate and readable (Priority: P1) MVP

**Goal**: Switch meeting diarization to FluidAudio offline pipeline and produce stable, speaker-labeled transcript segmentation deterministically.

**Independent Test**: Process a meeting with mocked diarization + transcript segments and verify deterministic attributed transcript output (same inputs -> same transcript markdown).

### Tests for US1 (write first)

- [x] T010 [P] [US1] Add speaker attribution determinism tests in MinuteCore/Tests/MinuteCoreTests/SpeakerAttributionDeterminismTests.swift
- [x] T011 [P] [US1] Add transcript renderer tests for speaker-labeled output in MinuteCore/Tests/MinuteCoreTests/TranscriptMarkdownRendererSpeakerLabelsTests.swift
- [x] T012 [P] [US1] Add pipeline test that writes speaker-attributed transcript deterministically in MinuteCore/Tests/MinuteCoreTests/MeetingPipelineCoordinatorSpeakerTranscriptTests.swift

### Implementation for US1

- [x] T013 [US1] Add OfflineDiarizer wrapper protocol for testability in MinuteCore/Sources/MinuteCore/Services/OfflineDiarizerManaging.swift
- [x] T014 [US1] Implement FluidAudio offline diarization service using OfflineDiarizerManager in MinuteCore/Sources/MinuteCore/Services/FluidAudioOfflineDiarizationService.swift
- [x] T015 [US1] Add deterministic speaker ordering utility (FR-002a: duration desc, tie-break earliest start, then stable id) in MinuteCore/Sources/MinuteCore/Utilities/SpeakerOrdering.swift
- [x] T016 [US1] Wire offline diarization into live pipeline in Minute/Sources/ViewModels/MeetingPipelineViewModel.swift (replace FluidAudioDiarizationService.meetingDefault())
- [x] T017 [US1] Ensure pipeline keeps producing transcript even if diarization fails (no crash) in MinuteCore/Sources/MinuteCore/Pipeline/MeetingPipelineCoordinator.swift

**Checkpoint**: US1 tests pass; transcript segmentation and labels are deterministic.

---

## Phase 4: User Story 2 — Quiet / far speakers remain intelligible for analysis (Priority: P2)

**Goal**: Normalize loudness for analysis inputs (diarization/transcription) without changing the vault WAV output contract.

**Independent Test**: Given a deliberately unbalanced input waveform, verify the analysis-audio path is normalized and used for transcription/diarization, while the vault WAV remains unchanged.

### Tests for US2 (write first)

- [x] T018 [P] [US2] Add loudness normalization command/params determinism tests in MinuteCore/Tests/MinuteCoreTests/AudioLoudnessNormalizerTests.swift
- [x] T019 [P] [US2] Add pipeline test verifying analysis-audio URL differs from vault WAV when enabled in MinuteCore/Tests/MinuteCoreTests/MeetingPipelineCoordinatorAnalysisAudioTests.swift

### Implementation for US2

- [x] T020 [US2] Add bundled ffmpeg locator + error mapping in MinuteCore/Sources/MinuteCore/Services/FFmpegLocator.swift
- [x] T021 [US2] Implement analysis loudness normalization service (ffmpeg loudnorm 2-pass, pinned params) in MinuteCore/Sources/MinuteCore/Services/AudioLoudnessNormalizer.swift
- [x] T021a [US2] Pin pass-1 filter: `loudnorm=I=-16:TP=-1.5:LRA=11:print_format=json` and parse stderr JSON to obtain `measured_I`, `measured_TP`, `measured_LRA`, `measured_thresh`, `offset`.
- [x] T021b [US2] Pin pass-2 filter: `loudnorm=I=-16:TP=-1.5:LRA=11:linear=true:measured_I=...:measured_TP=...:measured_LRA=...:measured_thresh=...:offset=...`.
- [x] T021c [US2] Ensure deterministic processing flags in Process invocation: `-nostdin -hide_banner -nostats -threads 1 -filter_threads 1 -filter_complex_threads 1`.
- [x] T022 [US2] Extend PipelineContext to carry a separate analysisAudioURL in MinuteCore/Sources/MinuteCore/Pipeline/PipelineTypes.swift
- [x] T023 [US2] Update MeetingPipelineCoordinator to use analysisAudioURL for transcription+diarization only in MinuteCore/Sources/MinuteCore/Pipeline/MeetingPipelineCoordinator.swift
- [x] T024 [US2] Add UI setting + defaults key for analysis loudness normalization in Minute/Sources/Views/Settings/GeneralSettingsSection.swift and Minute/Sources/Views/Settings/AppDefaults.swift
- [x] T025 [US2] Plumb the setting into PipelineContext construction in Minute/Sources/ViewModels/MeetingPipelineViewModel.swift
- [x] T026 [US2] Ensure normalization step is cancellable and cleans up temp artifacts in MinuteCore/Sources/MinuteCore/Pipeline/MeetingPipelineCoordinator.swift

**Checkpoint**: US2 tests pass; output contract unchanged (still exactly 3 meeting files).

---

## Phase 5: User Story 3 — Subtle manual speaker naming while viewing a meeting (Priority: P3)

**Goal**: Provide a subtle in-meeting UI to rename speakers and persist the mapping in meeting-note frontmatter (Obsidian-friendly) without clobbering user edits.

**Independent Test**: Rename a speaker, verify the meeting note frontmatter updates deterministically (participants + speaker_map) and the app transcript view uses the participant names.

### Tests for US3 (write first)

- [x] T027 [P] [US3] Add deterministic meeting-note frontmatter rendering tests (participants + speaker_map) in MinuteCore/Tests/MinuteCoreTests/MarkdownRendererParticipantFrontmatterTests.swift
- [x] T028 [P] [US3] Add integration tests for updating speaker_map in-place without altering note body in MinuteCore/Tests/MinuteCoreTests/MeetingSpeakerNamingPersistenceTests.swift
- [x] T029 [P] [US3] Add transcript “display name mapping” tests in MinuteCore/Tests/MinuteCoreTests/TranscriptSpeakerDisplayNameTests.swift

### Implementation for US3

- [x] T030 [US3] Extend MarkdownRenderer to optionally include participants + speaker_map frontmatter in MinuteCore/Sources/MinuteCore/Rendering/MarkdownRenderer.swift
- [x] T031 [US3] Extend TranscriptMarkdownRenderer to support optional speaker display names in MinuteCore/Sources/MinuteCore/Rendering/TranscriptMarkdownRenderer.swift
- [x] T032 [US3] Add MinuteCore service API for meeting speaker map load/save (local-only) in MinuteCore/Sources/MinuteCore/Services/MeetingSpeakerNamingService.swift
- [x] T033 [US3] Add subtle “Speakers” UI affordance (button/popover) in Minute/Sources/Views/MeetingNotes/MarkdownViewerOverlay.swift
- [x] T034 [US3] Add view model state + actions for renaming speakers and persisting to vault in Minute/Sources/Views/MeetingNotes/MeetingNotesBrowserViewModel.swift
- [x] T035 [US3] Add optional “Update transcript headings” action that only rewrites Minute-formatted speaker headings in MinuteCore/Sources/MinuteCore/Rendering/TranscriptSpeakerHeadingRewriter.swift
- [x] T036 [US3] Ensure speaker renaming counts as explicit user action (FR-010) and never bulk-regenerates the note/transcript body in Minute/Sources/Views/MeetingNotes/MeetingNotesBrowserViewModel.swift

### Optional (within US3 scope): Known-speaker profiles (FR-008/FR-009)

- [x] T037 [P] [US3] Define SpeakerProfile + store schema with versioning in MinuteCore/Sources/MinuteCore/Domain/SpeakerProfile.swift
- [x] T038 [P] [US3] Implement atomic JSON speaker profile store under Application Support in MinuteCore/Sources/MinuteCore/Services/SpeakerProfileStore.swift
- [x] T039 [P] [US3] Add deterministic cosine-distance matcher + thresholds in MinuteCore/Sources/MinuteCore/Utilities/SpeakerEmbeddingMatcher.swift
- [x] T040 [P] [US3] Add tests for profile store CRUD and matching determinism in MinuteCore/Tests/MinuteCoreTests/SpeakerProfileStoreTests.swift
- [x] T041 [US3] Add UI for enabling suggestions + managing profiles (list/delete) in Minute/Sources/Views/Settings/GeneralSettingsSection.swift and Minute/Sources/Views/Settings/MainSettingsView.swift

### Optional continuation (within US3 scope): Suggestions wiring (FR-008a/FR-008b)

- [x] T041a [US3] Add FluidAudio offline embedding export decoder + deterministic aggregation in MinuteCore/Sources/MinuteCore/Utilities/OfflineDiarizerEmbeddingExport.swift
- [x] T041b [US3] Extend diarization protocols to accept embedding export URL and plumb into FluidAudio offline diarization service in MinuteCore/Sources/MinuteCore/Services/
- [x] T041c [US3] Wire known-speaker matching into pipeline (frontmatter-only; best-effort; opt-in) in MinuteCore/Sources/MinuteCore/Pipeline/MeetingPipelineCoordinator.swift
- [x] T041d [US3] Add MinuteCore tests for export aggregation + pipeline frontmatter insertion in MinuteCore/Tests/MinuteCoreTests/

Note: Known-speaker suggestions are opt-in and MUST default OFF (stored in app settings; never written into vault files).

**Checkpoint**: US3 tests pass; renames persist in meeting note frontmatter and the app shows participant names.

---

## Phase 6: Polish & Cross-Cutting Concerns

- [ ] T042 [P] Update docs for participant frontmatter schema in docs/overview.md (if schema becomes user-visible)
- [ ] T043 Add privacy audit to ensure no raw transcript logged by speaker features in MinuteCore/Sources/MinuteCore/Services/FluidAudioOfflineDiarizationService.swift and MinuteCore/Sources/MinuteCore/Services/AudioLoudnessNormalizer.swift
- [ ] T044 Add output-contract regression test coverage for speaker frontmatter keys in MinuteCore/Tests/MinuteCoreTests/OutputContractCoverageTests.swift
- [ ] T045 Add cancellation coverage tests for diarization+normalization path in MinuteCore/Tests/MinuteCoreTests/MeetingProcessingOrchestratorCancelTests.swift
- [ ] T046 Run quickstart validation steps and update specs/006-speaker-diarization/quickstart.md if wiring changes

---

## Dependencies & Execution Order

- Phase 1 -> Phase 2 -> US1/US2/US3 -> Polish
- US2 depends on US1 only for shared pipeline wiring, but should remain independently testable via mocked services.
- US3 can be developed after Phase 2 and in parallel with US2 once the frontmatter editor/store exists.

### Dependency Graph

Setup (Phase 1)
	-> Foundational (Phase 2)
		-> US1 (P1 diarization + speaker-labeled transcript)
		-> US2 (P2 loudness normalization for analysis) [can start after Phase 2; benefits from US1 wiring]
		-> US3 (P3 manual naming + persistence) [can start after Phase 2]
			-> Polish (Phase 6)

## Parallel Execution Examples

### US1 parallel work
- Run in parallel: T010, T011, T012 (tests in separate files)
- Run in parallel: T013 and T015 (new protocol + relabeler)

### US2 parallel work
- Run in parallel: T018 and T019 (tests)
- Run in parallel: T020 and T021 (ffmpeg locator + normalizer)

### US3 parallel work
- Run in parallel: T027, T028, T029 (tests)
- Run in parallel: T037, T038, T039 (domain + store + matcher)

## Implementation Strategy

**MVP scope**: Phases 1-2 + US1 only (offline diarization + deterministic speaker-labeled transcript generation).

Then deliver:
1) US2 (analysis-only loudness normalization)
2) US3 (manual naming + persistence) and optionally profiles (FR-008/FR-009) behind a preference.
