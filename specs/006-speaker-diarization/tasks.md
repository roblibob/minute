# Tasks: Speaker Diarization & Identification

**Input**: Design documents in `specs/006-speaker-diarization/` (plan.md, spec.md, research.md, data-model.md, contracts/openapi.yaml, quickstart.md)

**Tests**: REQUIRED (Swift Testing) per spec + repo constitution. Any renderer/frontmatter/pipeline change MUST be deterministic and test-gated in `MinuteCore/Tests/MinuteCoreTests/`.

**Organization**: Tasks are grouped by user story (US1–US4) so each story is independently implementable and testable.

## Phase 1: Setup (Shared Infrastructure)

- [x] T001 Add diarization/speaker fixture helpers in MinuteCore/Tests/MinuteCoreTests/Helpers/SpeakerDiarizationTestData.swift
- [x] T002 [P] Add transcript golden fixtures for speaker headings in MinuteCore/Tests/MinuteCoreTests/Fixtures/Transcript/speaker_headings.md
- [x] T003 [P] Add meeting-note frontmatter fixtures for participant metadata in MinuteCore/Tests/MinuteCoreTests/Fixtures/Frontmatter/participants_and_speaker_map.md

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Shared primitives and safe file-editing utilities used across stories (determinism + “do not overwrite user edits”).

- [x] T004 Define participant + speaker-map domain models in MinuteCore/Sources/MinuteCore/Domain/MeetingParticipantFrontmatter.swift
- [x] T005 Implement deterministic YAML frontmatter encode/decode helpers in MinuteCore/Sources/MinuteCore/Rendering/YAMLFrontmatterCodec.swift
- [x] T006 Implement “update only owned frontmatter keys” editor in MinuteCore/Sources/MinuteCore/Rendering/MeetingFrontmatterEditor.swift
- [x] T007 [P] Add unit tests for frontmatter editor preserving body/unrelated keys in MinuteCore/Tests/MinuteCoreTests/MeetingFrontmatterEditorTests.swift
- [x] T008 Add meeting-note speaker-map persistence service (frontmatter-only; no extra vault files) in MinuteCore/Sources/MinuteCore/Services/MeetingSpeakerNamingService.swift
- [x] T009 [P] Add atomic write + determinism tests for MeetingSpeakerNamingService in MinuteCore/Tests/MinuteCoreTests/MeetingSpeakerNamingServiceTests.swift
- [x] T010 Add deterministic speaker ordering utility (FR-002a) in MinuteCore/Sources/MinuteCore/Utilities/SpeakerOrdering.swift

**Checkpoint**: Frontmatter edits are deterministic, atomic, and preserve user content.

---

## Phase 3: User Story 1 — Speaker-labeled transcript is accurate and readable (Priority: P1) 🎯 MVP

**Goal**: Use FluidAudio offline VBx diarization for meeting processing and produce stable, speaker-labeled transcript segmentation deterministically.

**Independent Test**: With mocked diarization + transcript segments, verify attributed transcript markdown is byte-for-byte identical across two runs.

### Tests for US1 (write first)

- [x] T011 [P] [US1] Add speaker attribution determinism tests in MinuteCore/Tests/MinuteCoreTests/SpeakerAttributionDeterminismTests.swift
- [x] T012 [P] [US1] Add transcript renderer tests for speaker-labeled output in MinuteCore/Tests/MinuteCoreTests/TranscriptMarkdownRendererSpeakerLabelsTests.swift
- [x] T013 [P] [US1] Add pipeline test that writes speaker-attributed transcript deterministically in MinuteCore/Tests/MinuteCoreTests/MeetingPipelineCoordinatorSpeakerTranscriptTests.swift

### Implementation for US1

- [x] T014 [P] [US1] Add OfflineDiarizer wrapper protocol for testability in MinuteCore/Sources/MinuteCore/Services/OfflineDiarizerManaging.swift
- [x] T015 [P] [US1] Implement FluidAudio offline diarization service using OfflineDiarizerManager in MinuteCore/Sources/MinuteCore/Services/FluidAudioOfflineDiarizationService.swift
- [x] T016 [US1] Wire offline diarization into pipeline context creation in Minute/Sources/ViewModels/MeetingPipelineViewModel.swift
- [x] T017 [US1] Ensure pipeline keeps producing transcript even if diarization fails (no crash) in MinuteCore/Sources/MinuteCore/Pipeline/MeetingPipelineCoordinator.swift

**Checkpoint**: US1 tests pass; transcript segmentation and labels are deterministic.

---

## Phase 4: User Story 2 — Quiet / far speakers remain intelligible for analysis (Priority: P2)

**Goal**: Normalize loudness for analysis inputs (diarization/transcription) without changing the vault WAV output contract.

**Independent Test**: With normalization enabled, verify `analysisAudioURL` differs from `audioTempURL` and is used for analysis only, while the vault WAV output remains unchanged.

### Tests for US2 (write first)

- [x] T018 [P] [US2] Add loudness normalization command/params determinism tests in MinuteCore/Tests/MinuteCoreTests/AudioLoudnessNormalizerTests.swift
- [x] T019 [P] [US2] Add pipeline test verifying analysis-audio URL differs from vault WAV when enabled in MinuteCore/Tests/MinuteCoreTests/MeetingPipelineCoordinatorAnalysisAudioTests.swift

### Implementation for US2

- [x] T020 [P] [US2] Add bundled ffmpeg locator + error mapping in MinuteCore/Sources/MinuteCore/Services/FFmpegLocator.swift
- [x] T021 [P] [US2] Implement analysis loudness normalization service (ffmpeg loudnorm 2-pass, pinned params) in MinuteCore/Sources/MinuteCore/Services/AudioLoudnessNormalizer.swift
- [x] T022 [US2] Extend PipelineContext to carry a separate analysisAudioURL in MinuteCore/Sources/MinuteCore/Pipeline/PipelineTypes.swift
- [x] T023 [US2] Update MeetingPipelineCoordinator to use analysisAudioURL for transcription+diarization only in MinuteCore/Sources/MinuteCore/Pipeline/MeetingPipelineCoordinator.swift
- [x] T024 [US2] Add UI setting + defaults key for analysis loudness normalization in Minute/Sources/Views/Settings/GeneralSettingsSection.swift and Minute/Sources/Views/Settings/AppDefaults.swift
- [x] T025 [US2] Plumb the setting into PipelineContext construction in Minute/Sources/ViewModels/MeetingPipelineViewModel.swift
- [x] T026 [US2] Ensure normalization step is cancellable and cleans up temp artifacts in MinuteCore/Sources/MinuteCore/Pipeline/MeetingPipelineCoordinator.swift

**Checkpoint**: US2 tests pass; output contract unchanged (still exactly 3 meeting files).

---

## Phase 5: User Story 3 — Subtle manual speaker naming while viewing a meeting (Priority: P3)

**Goal**: Provide a subtle in-meeting UI to rename speakers and persist the mapping in meeting-note frontmatter (Obsidian-friendly) without clobbering user edits.

**Independent Test**: Rename a speaker, verify the meeting note frontmatter updates deterministically (`participants` + `speaker_map`) and the app transcript view uses participant names.

### Tests for US3 (write first)

- [x] T027 [P] [US3] Add deterministic meeting-note frontmatter rendering tests in MinuteCore/Tests/MinuteCoreTests/MarkdownRendererParticipantFrontmatterTests.swift
- [x] T028 [P] [US3] Add integration tests for updating `speaker_map` in-place without altering note body in MinuteCore/Tests/MinuteCoreTests/MeetingSpeakerNamingPersistenceTests.swift
- [x] T029 [P] [US3] Add transcript “display name mapping” tests in MinuteCore/Tests/MinuteCoreTests/TranscriptSpeakerDisplayNameTests.swift
- [x] T030 [P] [US3] Add tests for transcript heading rewrite (Minute-formatted only, explicit user action) in MinuteCore/Tests/MinuteCoreTests/TranscriptSpeakerHeadingRewriterTests.swift

### Implementation for US3

- [x] T031 [P] [US3] Extend MarkdownRenderer to include `participants` + `speaker_map` frontmatter in MinuteCore/Sources/MinuteCore/Rendering/MarkdownRenderer.swift
- [x] T032 [P] [US3] Extend TranscriptMarkdownRenderer to support optional speaker display names in MinuteCore/Sources/MinuteCore/Rendering/TranscriptMarkdownRenderer.swift
- [x] T033 [US3] Add UI “Speakers” affordance (button/popover) in Minute/Sources/Views/MeetingNotes/MarkdownViewerOverlay.swift
- [x] T034 [US3] Add view model state + actions for renaming speakers + persisting to vault in Minute/Sources/Views/MeetingNotes/MeetingNotesBrowserViewModel.swift
- [x] T035 [US3] Implement transcript heading rewriter (explicit action; preserves stable speaker IDs) in MinuteCore/Sources/MinuteCore/Rendering/TranscriptSpeakerHeadingRewriter.swift

**Checkpoint**: US3 tests pass; renames persist in meeting note frontmatter and the app shows participant names.

---

## Phase 6: User Story 4 — Enroll a “known speaker” from a meeting (Priority: P3, optional)

**Goal**: Provide an explicit enrollment flow to create/update known speaker profiles from a meeting’s diarized speakers, with an embedding availability policy (cache vs reprocess) and non-destructive suggestion behavior.

**Independent Test**: Process meeting 1, enroll a speaker, process meeting 2 with suggestions enabled, and verify meeting 2 surfaces a suggestion without overwriting any existing `speaker_map` entries.

### Tests for US4 (write first)

- [x] T036 [P] [US4] Add tests for profile store CRUD determinism in MinuteCore/Tests/MinuteCoreTests/SpeakerProfileStoreTests.swift
- [x] T037 [P] [US4] Ensure embedding matcher determinism coverage in MinuteCore/Tests/MinuteCoreTests/SpeakerProfileStoreTests.swift
- [x] T038 [P] [US4] Add tests for offline embedding export decoding + deterministic aggregation in MinuteCore/Tests/MinuteCoreTests/OfflineDiarizerEmbeddingExportTests.swift
- [x] T039 [P] [US4] Add tests for pipeline non-destructive suggestions insertion in MinuteCore/Tests/MinuteCoreTests/KnownSpeakerSuggestionsPipelineTests.swift
- [x] T040 [P] [US4] Add tests for enrollment availability policy (embeddings present vs missing) in MinuteCore/Tests/MinuteCoreTests/SpeakerProfileEnrollmentPolicyTests.swift
- [x] T041 [P] [US4] Add tests for enrollment create/update determinism in MinuteCore/Tests/MinuteCoreTests/SpeakerProfileEnrollmentServiceTests.swift

### Implementation for US4

- [x] T042 [P] [US4] Define SpeakerProfile + schema/versioning in MinuteCore/Sources/MinuteCore/Domain/SpeakerProfile.swift
- [x] T043 [P] [US4] Implement atomic JSON speaker profile store in MinuteCore/Sources/MinuteCore/Services/SpeakerProfileStore.swift
- [x] T044 [P] [US4] Implement deterministic cosine similarity matcher + thresholds in MinuteCore/Sources/MinuteCore/Utilities/SpeakerEmbeddingMatcher.swift
- [x] T045 [US4] Add UI setting + manage profiles (toggle/list/delete) in Minute/Sources/Views/Settings/GeneralSettingsSection.swift and Minute/Sources/Views/Settings/MainSettingsView.swift
- [x] T046 [US4] Add offline embedding export decoder + deterministic per-speaker aggregation in MinuteCore/Sources/MinuteCore/Utilities/OfflineDiarizerEmbeddingExport.swift
- [x] T047 [US4] Extend diarization protocols to accept embedding export URL in MinuteCore/Sources/MinuteCore/Services/ServiceProtocols.swift and MinuteCore/Sources/MinuteCore/Services/OfflineDiarizerManaging.swift
- [x] T048 [US4] Plumb embedding export URL into FluidAudio offline diarization service in MinuteCore/Sources/MinuteCore/Services/FluidAudioOfflineDiarizationService.swift
- [x] T049 [US4] Wire known-speaker matching into pipeline (frontmatter-only; best-effort; opt-in; non-destructive) in MinuteCore/Sources/MinuteCore/Pipeline/MeetingPipelineCoordinator.swift
- [x] T050 [US4] Add app-owned per-meeting speaker embedding cache (bounded retention + user removal) in MinuteCore/Sources/MinuteCore/Services/MeetingSpeakerEmbeddingCache.swift
- [x] T051 [US4] Persist aggregated per-speaker embeddings to cache during processing (no new vault files) in MinuteCore/Sources/MinuteCore/Pipeline/MeetingPipelineCoordinator.swift
- [x] T052 [US4] Implement enrollment service (create/update SpeakerProfile from cached embeddings + name) in MinuteCore/Sources/MinuteCore/Services/SpeakerProfileEnrollmentService.swift
- [x] T053 [US4] Add “Save as Known Speaker…” UI entrypoint + wiring + user-facing errors in Minute/Sources/Views/MeetingNotes/MarkdownViewerOverlay.swift and Minute/Sources/Views/MeetingNotes/MeetingNotesBrowserViewModel.swift

**Checkpoint**: US4 tests pass; enrollment works when embeddings available; missing-embedding path is actionable.

---

## Phase 7: Polish & Cross-Cutting Concerns

- [x] T054 [P] Update participant frontmatter schema docs in docs/overview.md
- [x] T055 Add privacy audit (no raw transcript logging) in MinuteCore/Sources/MinuteCore/Services/FluidAudioOfflineDiarizationService.swift and MinuteCore/Sources/MinuteCore/Services/AudioLoudnessNormalizer.swift
- [x] T056 Add output-contract regression tests for speaker frontmatter keys in MinuteCore/Tests/MinuteCoreTests/OutputContractCoverageTests.swift
- [x] T057 Add cancellation coverage tests for diarization+normalization path in MinuteCore/Tests/MinuteCoreTests/MeetingProcessingOrchestratorCancelTests.swift
- [x] T058 Run quickstart validation steps and update specs/006-speaker-diarization/quickstart.md

---

## Dependencies & Execution Order

### User Story Completion Order

- Setup (Phase 1) → Foundational (Phase 2) → US1 (Phase 3) → US2 (Phase 4) → US3 (Phase 5) → US4 (Phase 6, optional) → Polish (Phase 7)

### Story Dependencies

- **US1 (P1)**: Depends on Phase 2 only.
- **US2 (P2)**: Depends on Phase 2 only; uses shared pipeline wiring from US1 but should remain independently testable via mocks.
- **US3 (P3)**: Depends on Phase 2 only.
- **US4 (P3, optional)**: Depends on US1 (for offline diarization + embeddings source) and US3 (for per-meeting speaker IDs + mapping UX).

---

## Parallel Execution Examples

### US1 parallel work

- Run in parallel: T011, T012, T013 (tests in separate files)
- Run in parallel: T014 and T015 (protocol + service)

### US2 parallel work

- Run in parallel: T018 and T019 (tests)
- Run in parallel: T020 and T021 (locator + normalizer)

### US3 parallel work

- Run in parallel: T027, T028, T029, T030 (tests)
- Run in parallel: T031 and T032 (renderer changes)

### US4 parallel work

- Run in parallel: T036, T037, T038, T039, T040, T041 (tests)
- Run in parallel: T042, T043, T044 (domain + store + matcher)

---

## Implementation Strategy

### Suggested MVP scope

1. Phase 1 + Phase 2
2. US1 (Phase 3)
3. Stop and validate determinism + contract tests

### Incremental delivery

1. Add US2 (analysis-only loudness normalization)
2. Add US3 (manual naming + persistence)
3. Add US4 (optional known-speaker suggestions + explicit enrollment)
