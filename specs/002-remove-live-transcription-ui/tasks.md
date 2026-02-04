# Tasks: Remove Live Transcription UI

**Spec**: [specs/002-remove-live-transcription-ui/spec.md](spec.md)
**Status**: Completed

## Phase 1: Setup

- [x] T001 Verify project builds clean before changes

## Phase 2: Foundational

None.

## Phase 3: User Story 1 - Clean Recording Interface

**Goal**: Remove the distracting and non-functional live transcription UI and its underlying logic.

### Tests
- [x] T002 [US1] Remove any unit tests in `MinuteTests` or `MinuteCoreTests` that specifically test the live transcription logic (if they exist).

### Implementation
- [x] T003 [US1] Remove `StreamingTranscriptView` struct and its usage from `Minute/ContentView.swift`. Remove "Live transcription updates below" text from `RecordingHeaderView`.
- [x] T004 [US1] Remove `liveTranscriptionLine` and `liveTranscriptionTickerTask` properties and their usage (start/cancellation) from `Minute/Pipeline/MeetingPipelineViewModel.swift`. Remove `LiveAudioStreamMixer` property.
- [x] T005 [US1] Remove `LiveAudioStreamMixer.swift` and `LiveAudioTranscriptionQueue.swift` from `MinuteCore` if no longer referenced.
- [x] T006 [US1] Remove `LiveTranscriptionSession.swift` from `MinuteCore` if no longer referenced.
- [x] T007 [US1] Remove `WhisperXPCLiveTranscriptionService.swift` and `FluidAudioLiveTranscriptionService.swift` from `MinuteCore` if no longer referenced.

## Final Phase: Polish

- [x] T008 [P] Verify application builds and runs successfully.
- [x] T009 [P] Manually verify recording UI is clean and errors don't occur during recording start/stop.

## Dependencies

- All US1 tasks are effectively parallelizable, but T003/T004 should probably be done before T005-T007 to ensure references are gone.
