# Quickstart — Background Summarization for Back-to-Back Meetings

This quickstart is for developers implementing and validating feature 004.

## Prerequisites

- macOS 14+
- Xcode 15.x
- A configured Obsidian vault in Minute
- Models downloaded (or allow model downloads during processing)

## Build & Test

- Build the app:
  - `xcodebuild -project Minute.xcodeproj -scheme Minute -configuration Debug build`
- Run MinuteCore tests:
  - `xcodebuild -workspace Minute.xcworkspace -scheme MinuteCore -configuration Debug test -destination 'platform=macOS'`

## Manual Validation Scenarios (core)

### Scenario A: Back-to-back recording while Meeting A processes

1. Start recording **Meeting A**.
2. Stop **Meeting A**.
3. Immediately start recording **Meeting B**.

Expected:
- Meeting B starts recording without waiting.
- Meeting A continues processing in the background.
- While Meeting A is processing, Meeting B’s **first screen context inference** is deferred (no llama inference starts) until Meeting A completes.

### Scenario B: Status visibility

- While Meeting A is processing and Meeting B is recording:
  - UI indicates Meeting A is “Processing” (stage visible).
  - UI indicates Meeting B is “Recording”, and shows that first screen inference is deferred if screen context inference is enabled.
  - UI exposes a “Cancel” action while background processing is active.

### Scenario C: Cancel + retry

1. Start background processing for a meeting.
2. Cancel processing.
3. Retry processing.

Expected:
- Cancellation stops compute and leaves outputs uncorrupted.
- Retry succeeds without affecting ability to record.
- After cancellation (or a failure), UI offers a “Retry” action for the last failed/canceled background run.

## Performance/UX checks

- Start/stop recording remains responsive.
- No UI stalls noticeable when background processing starts.
- If the system is under load, app still records reliably.
