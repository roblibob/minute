# Feature Specification: Main UI Refactor (Recording Stage)

**Feature Branch**: `008-main-ui-refactor`  
**Created**: 2026-02-09  
**Status**: Draft  
**Input**: Refactor the main UI by moving recording/setup controls into the main view, introducing a “Stage” (setup/recording) experience and a floating bottom control bar, without changing selected-meeting functionality.

## Clarifications

### Session 2026-02-09

- Q: During an active recording session, which Stage controls are allowed to change and take effect immediately? → A: All Stage controls remain editable and apply immediately (Meeting Type, Language Processing, audio channels, window/screen source) because Meeting Type/Language Processing are used post-recording during processing.

## User Scenarios & Testing *(mandatory)*

<!--
  IMPORTANT: User stories should be PRIORITIZED as user journeys ordered by importance.
  Each user story/journey must be INDEPENDENTLY TESTABLE - meaning if you implement just ONE of them,
  you should still have a viable MVP (Minimum Viable Product) that delivers value.
  
  Assign priorities (P1, P2, P3, etc.) to each story, where P1 is the most critical.
  Think of each story as a standalone slice of functionality that can be:
  - Developed independently
  - Tested independently
  - Deployed independently
  - Demonstrated to users independently
-->

### User Story 1 - Record from the Stage (Priority: P1)

As a user, I can set up and start/stop a recording directly from the main view without hunting for controls, and I can always see my recording status and elapsed time. While a session is in progress, I can understand that changes to controls may affect the recording.

**Why this priority**: Recording is the core workflow; the UI refactor must make it faster and clearer.

**Independent Test**: Can be fully tested by launching the app, staying on the default main view, starting a recording, observing status/timer/visual feedback, and stopping the recording.

**Acceptance Scenarios**:

1. **Given** no meeting is selected, **When** I view the main area, **Then** I see the Stage state with setup controls and a primary record action.
2. **Given** the Stage state, **When** I start recording, **Then** the UI clearly indicates recording status and shows an always-visible elapsed timer.
3. **Given** I am recording, **When** I stop recording, **Then** recording ends and the app proceeds with the existing meeting processing pipeline.
4. **Given** the Stage state, **When** the app window is resized, **Then** the Stage content remains usable and the primary start/stop action remains accessible.
5. **Given** the Stage state, **When** I start or stop recording, **Then** I receive tactile feedback confirming the action.
6. **Given** I am recording, **When** I view the Stage controls, **Then** I see a “session in progress” message that communicates adjustments may affect the recording.
7. **Given** I am recording, **When** I toggle an audio source on or off, **Then** the UI reflects the new state immediately and the change takes effect for the ongoing session as soon as possible.
8. **Given** I am recording, **When** I choose “Cancel Session”, **Then** the session is discarded and no meeting output is produced for that canceled session.
9. **Given** I am recording, **When** I change Meeting Type or Language Processing, **Then** the UI updates immediately and the new settings are used for processing the session after recording stops.

---

### User Story 2 - Import audio from the Stage (Priority: P2)

As a user, when I’m not recording, I can drag-and-drop an audio file into the main view to create and process a meeting.

**Why this priority**: Audio import is a key alternative entry point and should be discoverable in the default view.

**Independent Test**: Can be fully tested by dropping a supported audio file into the Stage and verifying the app begins processing it as a meeting.

**Acceptance Scenarios**:

1. **Given** the Stage state and I am not recording, **When** I drag a supported audio file over the upload area, **Then** the UI indicates the drop target is active.
2. **Given** the upload area is active, **When** I drop the file, **Then** the app accepts it and begins meeting processing without requiring navigation to another screen.
3. **Given** the upload area is visible, **When** I drop an unsupported or invalid file, **Then** I see a concise error explaining what file types are supported.

---

### User Story 3 - View selected meeting (no regressions) (Priority: P3)

As a user, when I select a meeting from the sidebar, I can continue to use the existing meeting detail experience without regressions while the recording UI is refactored.

**Why this priority**: The recording-area refactor must not break existing meeting viewing/analysis.

**Independent Test**: Can be fully tested by selecting an existing meeting and confirming the detail experience behaves as it did before the refactor.

**Acceptance Scenarios**:

1. **Given** a meeting is selected, **When** I view the main area, **Then** the existing meeting detail content is shown.
2. **Given** a meeting is selected, **When** I use existing analysis actions, **Then** they behave as they did before this refactor.

---

[Add more user stories as needed, each with an assigned priority]

### Edge Cases

<!--
  ACTION REQUIRED: The content in this section represents placeholders.
  Fill them out with the right edge cases.
-->

- No audio inputs are available, muted, or disconnected.
- Permissions are missing/denied for audio capture or window/screen selection.
- Window/screen list is empty (no eligible sources) or changes while the picker is open.
- User tries to start recording with no enabled audio source.
- User drops an unsupported file type or a corrupted audio file.
- User resizes the window very small; Stage controls must remain usable (with graceful reflow/scrolling) and status/timer must remain clear.
- User switches selected meeting while an analysis action is in progress; results must not appear under the wrong meeting.
- User cancels an in-progress session after recording has started.
- User changes Meeting Type / Language Processing mid-session.
- User disables all audio sources during a session.
- Dark mode and high-contrast mode readability.

## Requirements *(mandatory)*

<!--
  ACTION REQUIRED: The content in this section represents placeholders.
  Fill them out with the right functional requirements.
-->

### Functional Requirements

- **FR-001**: When no meeting is selected, the main content area MUST show the “Stage” state for setup and recording.
- **FR-002**: The Stage state MUST communicate readiness vs recording via a prominent header and status indicator.
- **FR-003**: While recording, the Stage state MUST display a short “session in progress” message indicating that changing controls may affect the recording.

- **FR-004**: The Stage state MUST provide two prominent configuration controls: (1) Meeting Type and (2) Language Processing.
- **FR-005**: The chosen Meeting Type and Language Processing settings MUST persist as user preferences and be used for the next recording/import unless changed.

- **FR-006**: The Stage state MUST provide clear, independently togglable audio source controls for (a) microphone input and (b) system audio.
- **FR-007**: The audio source controls MUST use a strong visual active/inactive treatment so users can tell at a glance what will be captured.

- **FR-008**: The Stage state MUST provide a control for choosing an optional window/screen source and MUST show the current selection (or “None”).
- **FR-009**: The window/screen selection control MUST clearly indicate whether it is enabled/selected (e.g., “Screen Record” vs “None”).

- **FR-010**: When not recording, the Stage state MUST show an upload/drop zone that accepts supported audio files via drag-and-drop.
- **FR-011**: When recording, the Stage state MUST replace the upload/drop zone with a live audio activity visualizer.
- **FR-012**: The Stage state MUST show an “input levels” indicator while recording, including whether the app is actively listening.

- **FR-013**: The Stage state MUST include a floating bottom control bar containing: (a) recording status label, (b) elapsed timer, and (c) the primary start/stop action.
- **FR-014**: Starting/stopping a recording from the bottom control bar MUST provide immediate, clear feedback and MUST also provide tactile feedback.
- **FR-015**: The bottom control bar MUST provide a “Cancel Session” action during recording.
- **FR-016**: Canceling a session MUST discard it (no meeting output is created for the canceled session) and MUST not leave partial/stray files in the vault.

- **FR-017**: While recording, the configuration controls (Meeting Type, Language Processing, audio sources, and window/screen source) MUST remain visible and MUST remain adjustable.
- **FR-018**: Changing Meeting Type or Language Processing during recording MUST update the pending session’s processing settings immediately and MUST apply to post-recording processing without requiring a restart of the recording.
- **FR-019**: Changing audio sources or window/screen source during recording MUST take effect for capture as soon as possible and MUST clearly indicate the new active state in the UI.

- **FR-020**: Selecting a meeting from the sidebar MUST continue to show the existing meeting detail experience (no functional changes required by this feature).
- **FR-021**: This feature MUST NOT introduce new meeting analysis UI behaviors; any changes in the meeting detail area are out of scope beyond layout/styling regressions.

- **FR-022**: The UI refactor MUST NOT change the meeting output contract (including file counts, paths, and deterministic rendering rules).
- **FR-023**: User-visible errors for recording/import/analysis MUST be concise, actionable, and MUST NOT expose sensitive transcript content by default.

- **FR-024**: The Stage presentation MUST use a single, centered “stage card” container that visually groups the setup/recording controls.
- **FR-025**: The Stage presentation MUST keep the stage card centered and readable as the window resizes, while keeping the bottom control bar accessible.

### Non-Functional Requirements *(mandatory)*

- **NFR-001**: System MUST preserve local-only processing and avoid outbound
  network calls except model downloads.
- **NFR-002**: System MUST maintain deterministic output for any note rendering
  or contract changes.
- **NFR-003**: Long-running operations MUST support cancellation and avoid
  blocking the UI thread.
- **NFR-004**: UX changes MUST align with the pipeline state machine and
  provide clear user status/errors without leaking internal details.

- **NFR-005**: The UI MUST use semantic/system-aware colors and remain legible in light mode, dark mode, and increased-contrast settings.
- **NFR-006**: Core controls MUST remain accessible via keyboard navigation and assistive technologies (labels, roles, and predictable focus order).
- **NFR-007**: The Stage layout MUST gracefully adapt to window resizing without losing access to the primary start/stop action.

### Key Entities *(include if feature involves data)*

- **Meeting Type**: A user-selected classification that influences how the meeting is processed and summarized.
- **Language Processing**: A user-selected processing profile that influences transcription/summarization behavior.
- **Recording Sources**: User choices for microphone input, system audio input, and optional window/screen context.
- **Meeting Detail View State**: The currently selected meeting, its transcript, and the set of available analysis outputs.

### Assumptions & Dependencies

- The app already supports creating and selecting meetings from a sidebar.
- A finite, user-facing list of Meeting Types and Language Processing options exists (or will exist) and is appropriate for selection.
- The operating system may require permissions for audio capture and window/screen selection; the app can request these permissions and surface denial states.
- Hardware availability varies (e.g., no microphone connected); the UI must handle “no available inputs” gracefully.

## Success Criteria *(mandatory)*

<!--
  ACTION REQUIRED: Define measurable success criteria.
  These must be technology-agnostic and measurable.
-->

### Measurable Outcomes

- **SC-001**: In a usability test, at least 90% of users can start and stop a recording from the Stage without assistance on their first attempt.
- **SC-002**: In a usability test, at least 80% of users can successfully import an audio file via drag-and-drop within 30 seconds of reaching the Stage.
- **SC-003**: When a recording action is triggered (start/stop/cancel), the UI shows a corresponding state change (status/timer/controls) within 1 second in 95% of attempts.
- **SC-004**: The refactor introduces no regressions to the meeting output contract (still exactly three vault files per processed meeting, with unchanged paths and deterministic Markdown rendering).

- **SC-005**: In a usability test, at least 90% of users correctly identify which audio channels are active (mic/system) while recording, without toggling any controls.
- **SC-006**: In a usability test, at least 80% of users successfully cancel an in-progress session within 10 seconds of being asked, and confirm the session was discarded.
