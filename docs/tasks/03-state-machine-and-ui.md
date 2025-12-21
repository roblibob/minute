# 03 — State Machine and UI

## Goal
Implement the end-to-end UX flow and pipeline orchestration as a single source-of-truth state machine:

`idle → recording → recorded → processing(transcribe) → processing(summarize) → writing → done | failed`

This phase focuses on correctness of transitions, cancellation, progress reporting, and failure recovery, while services can still be mocked.

## Deliverables
- A SwiftUI screen with Start / Stop / Process actions
- A state machine driving all button enablement/disablement
- A pipeline coordinator that runs stages sequentially and supports cancellation
- Clear failure UI with a user-safe message and a debug details area (optional)

## UI structure (SwiftUI)
### Main screen
Recommended layout:
- Header: selected vault status + Settings button
- Primary controls:
  - Start Recording (enabled only when idle)
  - Stop (enabled only when recording)
  - Process (enabled only when recorded)
- Status area:
  - Current state label
  - Progress bar/spinner during processing
- Results area:
  - On success: show note path + audio path + “Reveal in Finder” buttons
  - On failure: show error + “Reset” and “Copy debug info”

### Settings
Use the Settings screen built in phase 02, reachable from menu/toolbar.

## State machine design
Keep the state machine in the app layer (UI target), but keep stage outputs and services in `MinuteCore`.

### State enum
Include explicit payloads so later stages have necessary inputs:
- `idle`
- `recording(session: RecordingSession)`
- `recorded(audioTempURL: URL, startedAt: Date, stoppedAt: Date)`
- `processing(stage: ProcessingStage, context: PipelineContext)`
- `writing(context: PipelineContext, extraction: MeetingExtraction)`
- `done(noteURL: URL, audioURL: URL)`
- `failed(error: MinuteError, debugOutput: String?)`

Where `PipelineContext` could include:
- vault configuration snapshot
- final audio destination URL
- meeting date/title (once known)
- temporary working directory

### Transition rules
Codify transitions in one place (e.g., reducer-like function):
- `startRecording` allowed only from `idle`
- `stopRecording` allowed only from `recording`
- `process` allowed only from `recorded`
- `cancelProcessing` allowed only from `processing` and `writing`
- `reset` allowed from `failed` and `done`

This avoids “button logic” scattered across views.

## Pipeline coordinator
Implement a coordinator that:
- Runs sequential stages on a background priority
- Emits state updates on the main actor
- Propagates cancellation correctly

Suggested approach:
- A `@MainActor` `AppViewModel` that holds state
- When processing begins, it launches a `Task` stored as `processingTask`
- Each stage is an `async throws` call into a service

### Cancellation
- When user cancels, call `processingTask.cancel()`
- In each stage wrapper, check `Task.isCancelled` and throw `CancellationError` when needed
- Ensure external processes (whisper/llama) are terminated on cancel

## Progress reporting
For v1, it can be coarse:
- 0–0.3 transcription
- 0.3–0.8 summarization/repair
- 0.8–1.0 writing

If whisper/llama expose progress, it can be wired later.

## Observability
- Use `OSLog` categories per stage
- Capture stdout/stderr from whisper/llama and store as debug output for failures (do not write to vault)

## Exit criteria checklist
- [ ] UI follows Start → Stop → Process and reflects all states
- [ ] Transitions are enforced (invalid actions are no-ops)
- [ ] Cancel works and returns to a stable state
- [ ] Errors show a user-facing message and optionally debug output
