# Research: Main UI Refactor (Recording Stage)

**Branch**: 008-main-ui-refactor  
**Date**: 2026-02-09

## Goals

- Refactor the main content area when **no meeting is selected** into a centered “Stage” for setup + recording.
- Bring core recording controls into the Stage (and floating bottom control bar).
- Preserve product constraints: local-only, deterministic output contract (3 files per processed meeting), atomic writes.
- Keep selected-meeting functionality **as-is** (no behavior changes).

## Findings (current code)

### Recording controls + pipeline wiring

- Current UI already has a floating control bar and a Stage-like main panel that changes in `.recording` state.
- Recording start/stop is routed through a central pipeline view model; UI derives timer from `RecordingSession.startedAt`.
- There is **no explicit “cancel recording and discard”** path today; cancellation exists for background processing, not for active capture.

### Meeting Type

- `MeetingType` exists, is surfaced in UI, and is already part of pipeline context.
- Autodetect is resolved during summarization classification.
- Meeting type affects prompt strategy selection deterministically.

### “Language Processing”

- No first-class user setting named “Language Processing” exists today.
- Current behavior resembles a default “Auto → English” summarization output.

### Import + screen context

- Drag/drop + file importer exist and already perform sandbox-safe access and WAV contract conversion/verification.
- Screen/window selection exists but currently uses a list-style picker (no thumbnail grid).

## Decisions

### Decision 1: Reuse existing pipeline state + view model, refactor Stage presentation

- **Decision**: Treat this feature as a UI refactor over existing recording pipeline behavior and state types.
- **Rationale**: Minimizes risk to core processing contract and keeps UX predictable.
- **Alternatives considered**:
  - Rebuild a parallel “Stage-only” recording pipeline (rejected: high risk, duplicates state machine).

### Decision 2: Add an explicit “Cancel Session” recording action

- **Decision**: Introduce a distinct “Cancel Session” action during active recording that discards the in-progress recording and produces **no vault output**.
- **Rationale**: Matches the mockup’s bottom-bar affordance; makes it clear “stop” vs “cancel” are different.
- **Alternatives considered**:
  - Map “Cancel” to “Stop” (rejected: violates user expectation; would create meeting outputs).
  - Cancel only post-recording processing (rejected: mockup shows cancel during recording).

### Decision 3: Persist Meeting Type and “Language Processing” as Stage preferences

- **Decision**: Persist both controls as user preferences (last-used) and use them for subsequent recordings/imports.
- **Rationale**: Spec requires persistence and “post-processing” usage.
- **Alternatives considered**:
  - Session-only settings (rejected: violates spec FR-005).

### Decision 4: Define “Language Processing” as a minimal, deterministic profile

- **Decision**: Introduce a new domain value (e.g., `LanguageProcessingProfile`) with a small initial set of options. Default MUST preserve current behavior.
- **Rationale**: The app needs a concrete persisted value to drive post-recording processing, but must avoid scope explosion.
- **Alternatives considered**:
  - Re-label existing backend/model settings as “Language Processing” (rejected: mismatched semantics to mockup).

## Risks / gotchas

- Recording cancellation must ensure no partial/stray vault files are produced.
- Some capture capabilities depend on OS permissions; UX must represent these states clearly.
- Adding a new persisted setting requires careful defaulting so existing users see unchanged behavior.

## Concrete code locations (for implementation planning)

- Recording controls and floating bar: `Minute/Sources/.../FloatingControlBar.swift`, `Minute/Sources/.../RecordControlButton.swift`, `Minute/Sources/.../ContentView.swift`
- Stage main panel: `Minute/Sources/.../MainStageView.swift` (recording state presentation)
- Pipeline routing: `Minute/Sources/.../MeetingPipelineViewModel.swift`
- Import: `MinuteCore/Sources/.../DefaultMediaImportService.swift`, `Minute/Sources/.../PipelineContentView.swift`
- Screen picker + capture: `Minute/Sources/.../ScreenContextPickerView.swift`, `MinuteCore/Sources/.../ScreenContextCaptureService.swift`

(Exact paths/symbols to be confirmed during implementation; this doc captures the architectural touchpoints.)
