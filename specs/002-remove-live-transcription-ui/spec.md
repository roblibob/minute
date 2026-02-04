# Feature Specification: Remove Live Transcription UI

**Feature Branch**: `002-remove-live-transcription-ui`  
**Created**: 2026-02-04  
**Status**: Draft  
**Input**: User description: "Remove the live transcription functionality that is showing in the UI during recording. It is only for show and has no functional purpose."

## User Scenarios & Testing

### User Story 1 - Clean Recording Interface (Priority: P1)

As a user, when I am recording a meeting, I want a clean interface without distracting fake transcription text, so that I can focus on the meeting status and audio levels.

**Why this priority**: P1. This is the primary goal of the feature request. The current "live transcription" is non-functional ("only for show") and misleading.

**Independent Test**:
1. Start a recording in the app.
2. Observe the recording UI.
3. Verify that NO streaming text or "Live transcription updates below" message appears.
4. Verify that the audio waveform and timer still function correctly.

**Acceptance Scenarios**:

1. **Given** the app is idle, **When** I start a recording, **Then** the "Recording in progress" header appears WITHOUT the "Live transcription updates below." subtitle.
2. **Given** the app is recording, **When** audio is detected (waveform moves), **Then** NO text is streamed to the bottom of the window.

---

### Edge Cases

- **Recording Recovery**: Determine if removing the live transcription state affects recovery (unlikely, as it was "for show", but good to check).
  - *Expectation*: Recovery works as normal; this state was ephemeral.
- **Transcript Generation**: Ensure the *actual* post-meeting transcription still works.
  - *Expectation*: Post-processing transcription is separate and unaffected.

## Requirements

### Functional Requirements

- **FR-001**: The system MUST NOT display any transcription preview text during the recording phase.
- **FR-002**: The `StreamingTranscriptView` component MUST be removed from the recording stage.
- **FR-003**: The "Live transcription updates below" instructional text MUST be removed.
- **FR-004**: The underlying `liveTranscriptionLine` state and associated "ticker" tasks MUST be removed from the ViewModel to prevent wasted CPU cycles.

### Non-Functional Requirements

- **NFR-001**: Performance SHOULD improve slightly during recording by removing the string manipulation and timer task.
- **NFR-002**: Existing functional requirements for audio recording `NFR-001` (local only) and `NFR-003` (cancellable) MUST remain intact.

### Key Entities

- **MeetingPipelineViewModel**: Needs cleanup of `liveTranscription*` properties.
- **ContentView**: Needs cleanup of `StreamingTranscriptView` usage.

## Success Criteria

### Measurable Outcomes

- **SC-001**: Zero occurrences of "StreamingTranscriptView" in the active UI hierarchy during recording.
- **SC-002**: `liveTranscriptionLine` property is completely removed from the codebase.
