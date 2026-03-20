# Quickstart: Reprocess Meeting Type

## Goal

Validate that a processed meeting can be reprocessed to a different explicit meeting type from its saved transcript, while preserving the three-file contract and persisting screen context into the transcript timeline.

## Preconditions

- A local vault is configured.
- A processed meeting exists in the meeting notes browser.
- At least one validation meeting was recorded with screen context enabled.
- The meeting’s transcript artifact exists under `Meetings/_transcripts/`.

## Validation Scenarios

### 1. Screen context is persisted into the transcript

1. Process a meeting with screen context enabled.
2. Open the transcript artifact from the meeting notes browser.
3. Verify the transcript contains timestamped `Screen Context` entries.
4. Verify the entries are visually distinct from speaker dialogue and appear in chronological order.

Expected result:
- The transcript remains a single file under the existing transcript path.
- Screen-derived lines are clearly labeled `Screen Context`.

### 2. Reprocess to a different explicit meeting type

1. Open a processed meeting that currently has a transcript.
2. Open `Resummarize as…` from the meeting row context menu in the notes list.
3. Confirm that `Autodetect` is not offered as a target type.
4. Select a different explicit meeting type and confirm overwrite.
5. Wait for reprocessing to complete.

Repeat the same validation from the meatball menu while viewing the meeting summary or transcript.

Expected result:
- Only the meeting note changes.
- The note frontmatter `meeting_type` reflects the newly selected type.
- The transcript and audio file paths remain unchanged.
- The `Resummarize as…` action is available from both menu surfaces.

### 3. Missing transcript blocks reprocessing

1. Remove or rename the transcript artifact for a processed meeting.
2. Open the meeting in the meeting notes browser.
3. Verify `Resummarize as…` is disabled in the notes list context menu.
4. Open the meeting summary or transcript overlay and verify `Resummarize as…` is also disabled in the meatball menu.

Expected result:
- Reprocessing is blocked.
- The UI explains that the transcript is required.
- Both menu surfaces show the same disabled state.

### 4. Edited note requires explicit overwrite confirmation

1. Open a processed meeting note and add a manual edit.
2. Start reprocessing for that meeting.
3. Verify the UI offers `Overwrite` or `Cancel` before any changes are written.
4. Choose `Cancel` once, then repeat and choose `Overwrite`.

Expected result:
- `Cancel` leaves the current note untouched.
- `Overwrite` proceeds with note regeneration.
- No additional note is created.

## Suggested Test Commands

Run MinuteCore tests:

```bash
swift test --package-path MinuteCore
```

Run app and integration tests:

```bash
xcodebuild -project Minute.xcodeproj -scheme Minute -configuration Debug test
```

## Validation Results

Validated on 2026-03-20.

- `swift test --package-path MinuteCore`
	- Passed: 303 tests across 95 suites
	- Reprocess-specific coverage included note-only overwrite behavior, overwrite-confirmation enforcement, transcript availability blocking, and screen-context timeline parsing/rendering.
- `xcodebuild -project Minute.xcodeproj -scheme Minute -configuration Debug test`
	- Passed: 64 tests across 24 suites
	- Reprocess UI coverage included `Resummarize as…` availability, transcript-missing/unreadable disabled messaging, explicit target selection, and cancel-before-overwrite behavior.

Notes:

- Swift Testing output is reported after an XCTest preamble that may still say `Executed 0 tests`; the authoritative result is the later Swift Testing summary lines above.
- The full app-suite run emitted expected test-environment log noise from screen-context and AVFoundation mocks, but the test session completed successfully with `** TEST SUCCEEDED **`.

## Focused Test Additions

- Transcript renderer tests for screen context timeline entries
- Transcript parsing tests for screen context extraction round-trip
- Reprocess coordinator tests for note-only regeneration
- Browser/view-model tests for transcript-required blocking and overwrite confirmation