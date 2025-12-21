# 05 — Transcription (whisper.cpp) Integration

## Goal
Integrate `whisper.cpp` to produce an in-memory transcript from the WAV file, with deterministic behavior, robust error handling, and clean cancellation.

Preference order:
1. **Library integration** (preferred) — call whisper directly from Swift.
2. **Executable integration** (fallback) — bundle a `whisper.cpp` CLI and invoke it via `Process`.

## Deliverables
- `TranscriptionService` that:
  - Accepts a WAV URL
  - Returns transcript as `String`
  - Supports cancellation
  - Provides debug output on failure

Note: The transcript is persisted as its own Markdown file in the vault in phase 08 (output contract + vault writing).
- One of:
  - A bundled whisper **library** integrated into the app/Swift package, or
  - A bundled whisper **executable** invoked via `ProcessRunner`

## Bundling strategy
### Preferred: library
- Build `whisper.cpp` as a static library (or XCFramework) and expose a small C shim API suitable for Swift.
- Integrate via Swift Package (binary target or C target) so `MinuteCore` can call it.

Pros:
- No external process management
- Easier cancellation and progress reporting

Cons:
- Tooling complexity (CMake, C/C++ interop)

### Fallback: executable
For fast iteration (and if library integration becomes too costly):
- Build `whisper.cpp` outside Xcode and add the executable to the app target.
- Ensure it is code-signed as part of the app bundle.

Keep models out of the app bundle; they are downloaded to Application Support (phase 09).

## Process runner abstraction
Create a reusable `ProcessRunner` in `MinuteCore`:
- Inputs:
  - executable URL
  - arguments
  - environment (optional)
  - working directory (optional)
- Outputs:
  - combined output or separated stdout/stderr
  - exit status

Best practices:
- Use `Pipe()` for stdout/stderr.
- Read pipes asynchronously to avoid deadlocks.
- Impose a maximum output size to prevent runaway memory use.

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
- binary missing → `MinuteError.whisperMissing`
- non-zero exit code → `MinuteError.whisperFailed(exitCode:output:)`
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
