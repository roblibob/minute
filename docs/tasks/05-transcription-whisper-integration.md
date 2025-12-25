# 05 — Transcription (whisper.cpp) Integration
---
Status: Planned, not implemented.
---

## Goal
Integrate `whisper.cpp` to produce an in-memory transcript from the WAV file, with deterministic behavior, robust error handling, and clean cancellation.

Approach:
- **Library integration** — call whisper via the XCFramework, hosted in an XPC helper to avoid ggml symbol conflicts.

## Deliverables
- `TranscriptionService` that:
  - Accepts a WAV URL
  - Returns transcript as `String`
  - Supports cancellation
  - Provides debug output on failure

Note: The transcript is persisted as its own Markdown file in the vault in phase 08 (output contract + vault writing).

## Bundling strategy
Build `whisper.cpp` as an XCFramework and host it in an XPC helper target so the main app avoids symbol conflicts.
Keep models out of the app bundle; they are downloaded to Application Support (phase 09).

## Deterministic invocation
Choose a fixed whisper command line.
Examples of concerns to address:
- Force language (English) if appropriate to reduce variability.
- Disable timestamps if you only need text.
- Use consistent threading settings (optional).

The exact arguments should be documented in code comments and kept stable.

## Transcript normalization
After capturing output, normalize to reduce downstream prompt noise:
- Trim leading/trailing whitespace
- Collapse excessive blank lines
- If whisper outputs progress lines, filter them out (regex-based)

## Error handling
Map failures into domain errors:
- service missing → `MinuteError.whisperMissing`
- inference failure → `MinuteError.whisperFailed(exitCode:output:)`
- timeout (optional) → `MinuteError.whisperTimeout`

Log full stdout/stderr to debug output, but never write it to the vault.

## Cancellation
- Wrap process execution inside `withTaskCancellationHandler`.
- On cancel, terminate the running `Process`.
- Ensure pipe readers are also stopped.

## Testing approach
- Unit test: transcript normalization and parsing of whisper output
- Integration test: mock `ProcessRunner` to return recorded sample output

## Exit criteria checklist
- [ ] Whisper runs and returns a transcript from a known WAV
- [ ] Cancel reliably terminates whisper
- [ ] Non-zero exit codes surface as actionable errors
- [ ] Transcript output is stable enough to be written as Markdown and linked from the meeting note (phase 08)

