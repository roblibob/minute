# Feature Specification: Reprocess Meeting Type

**Feature Branch**: `016-reprocess-meeting-type`  
**Created**: 2026-03-20  
**Status**: Draft  
**Input**: User description: "Sometimes users use auto detect meeting type and gets wrong meeting. They then want to reprocess the meeting. As a user I would like to reprocess a meeting to another meeting type. For this to happen the transcript needs to exist. And we should also save the screen inference to the transcript at the appropriate time stamps. Mark it clear as Screen context so it doesn't get confused as something someone said."

## Clarifications

### Session 2026-03-20

- Q: Which existing meeting artifacts may reprocessing overwrite? → A: Reprocessing overwrites only the meeting note; transcript and audio remain unchanged and serve as the durable source.
- Q: Can reprocessing target Autodetect, or only explicit meeting types? → A: Reprocessing can target only explicit meeting types; Autodetect is not allowed as a reprocess target.
- Q: How should reprocessing handle meetings whose note has user edits? → A: If user edits are detected, the app prompts the user to overwrite or cancel; save-as-new is not part of this feature.
- Q: Where should the reprocess action appear in the UI? → A: Add `Resummarize as…` to the meeting row context menu in the notes list and to the meatball menu in the summary/transcript overlay, alongside the existing reveal/delete actions.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Reprocess a misclassified meeting (Priority: P1)

As a user who notices that Autodetect chose the wrong meeting type, I want to reprocess the meeting using a different explicit meeting type, so I can regenerate the note in the right format without recording the meeting again.

**Why this priority**: Wrong meeting type selection directly reduces trust in the output and creates avoidable rework. A recovery path is needed for already-processed meetings.

**Independent Test**: Open a processed meeting that already has a transcript, choose a different explicit meeting type, run reprocessing, and verify the meeting note is regenerated for the selected type without requiring a new recording.

**Acceptance Scenarios**:

1. **Given** a processed meeting with an existing transcript and a current meeting type, **When** the user chooses a different explicit meeting type and confirms reprocessing, **Then** the system regenerates the meeting note using the newly selected type.
2. **Given** a processed meeting that was originally summarized with Autodetect, **When** the user explicitly reprocesses it as a specific meeting type, **Then** the regenerated note reflects the selected type rather than the original autodetected type.
3. **Given** a processed meeting with an existing transcript, **When** reprocessing completes, **Then** the meeting remains associated with the same recording session, updates only the meeting note, and does not create duplicate meeting artifacts.
4. **Given** a processed meeting appears in the notes list or in the summary/transcript overlay, **When** the user opens the existing action menu, **Then** they can access `Resummarize as…` from the same action group as reveal/delete.

---

### User Story 2 - Screen context survives into transcript-based reprocessing (Priority: P2)

As a user who recorded screen context during a meeting, I want that context preserved inside the transcript timeline, so reprocessing uses the same contextual evidence and I can distinguish screen-derived context from spoken words.

**Why this priority**: Reprocessing will only be trustworthy if it uses the same evidence that was available during the original processing pass. Screen context must remain durable and readable after the meeting ends.

**Independent Test**: Process a meeting with screen context enabled, inspect the transcript, and verify that time-aligned screen context entries are present, clearly labeled, and still available when the meeting is later reprocessed to a different type.

**Acceptance Scenarios**:

1. **Given** a meeting where screen context is captured during recording, **When** the transcript is written, **Then** the transcript includes time-aligned entries for that context in chronological order.
2. **Given** a transcript containing both spoken content and persisted screen context, **When** the user reviews the transcript, **Then** each screen-derived entry is clearly labeled as Screen Context and is not presented as dialogue.
3. **Given** a meeting that is reprocessed from its saved transcript, **When** screen context entries exist, **Then** they are included as part of the source material used for reprocessing.

---

### User Story 3 - Reprocess availability is explicit and safe (Priority: P3)

As a user, I want the app to clearly tell me when a meeting can or cannot be reprocessed, so I understand what is missing and do not lose confidence in the meeting record.

**Why this priority**: Reprocessing depends on durable artifacts. If the transcript is missing, the app needs an actionable explanation rather than a silent failure or a misleading option.

**Independent Test**: Attempt to reprocess one meeting with a transcript and one without; verify the first succeeds and the second shows a clear explanation that transcript-based reprocessing is unavailable.

**Acceptance Scenarios**:

1. **Given** a processed meeting whose transcript artifact is missing or unreadable, **When** the user tries to reprocess the meeting, **Then** the system prevents reprocessing and explains that the transcript is required.
2. **Given** a meeting whose transcript does not contain any screen context entries, **When** the user reprocesses it, **Then** reprocessing still succeeds using the spoken transcript alone.
3. **Given** a user selects the same meeting type the meeting already uses, **When** they open the reprocess flow, **Then** the system makes it clear that a different explicit target meeting type is required to run reprocessing.
4. **Given** the meeting note contains user edits after the original processing pass, **When** the user starts reprocessing, **Then** the system prompts the user to overwrite the managed note or cancel reprocessing.
5. **Given** a meeting is missing its transcript artifact, **When** the user opens either reprocess menu surface, **Then** the `Resummarize as…` action is visible but disabled.

### Edge Cases

- A meeting with a valid transcript but no captured screen context should still be reprocessable.
- A meeting with screen context entries near a spoken segment boundary should preserve chronological readability and avoid making screen context look like a speaker turn.
- Reprocessing must not produce duplicate notes, duplicate transcript files, or duplicate audio files for the same meeting.
- If a transcript has been removed, corrupted, or moved outside the expected vault path, the user should receive a clear explanation that reprocessing is unavailable.
- If the user has manually edited the meeting note after initial processing, the app should require an explicit overwrite confirmation before reprocessing continues.
- The reprocess action should behave consistently in both menu surfaces so users do not see different enablement rules in the sidebar and overlay.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The system MUST allow a user to explicitly reprocess a previously processed meeting using a different explicit meeting type.
- **FR-002**: Reprocessing MUST be available only when the meeting has an existing, readable transcript artifact for that meeting.
- **FR-003**: When the user confirms reprocessing with a different explicit meeting type, the system MUST regenerate the meeting note for the selected type without requiring the meeting to be recorded again.
- **FR-004**: Reprocessing MUST use the saved transcript artifact for that meeting as the durable source of truth for regenerated note content.
- **FR-005**: The system MUST persist captured screen context within the transcript artifact as chronological transcript entries tied to the relevant meeting timestamps.
- **FR-006**: Every persisted screen-derived transcript entry MUST be clearly labeled as Screen Context so it cannot be mistaken for spoken dialogue.
- **FR-007**: If no screen context was captured for a meeting, the system MUST still allow transcript-based reprocessing using spoken transcript content alone.
- **FR-008**: The system MUST preserve the existing output contract of exactly three files per processed meeting at the existing note, audio, and transcript paths.
- **FR-009**: Reprocessing a meeting MUST overwrite only the app-managed meeting note for that meeting and MUST NOT rewrite the transcript or audio artifacts.
- **FR-010**: The system MUST clearly communicate when reprocessing is unavailable because the transcript artifact is missing, unreadable, or no longer associated with the meeting.
- **FR-011**: The system MUST require the user to choose an explicit target meeting type that differs from the meeting’s current type before reprocessing begins.
- **FR-011a**: The system MUST NOT allow Autodetect to be selected as a reprocess target.
- **FR-012**: The system MUST make it clear to the user that reprocessing regenerates the app-managed meeting note for the selected meeting.
- **FR-012a**: If the system detects user edits in the meeting note, it MUST prompt the user to overwrite the managed note or cancel reprocessing before any note changes are written.
- **FR-012b**: This feature MUST NOT offer a save-as-new path that creates an additional vault note.
- **FR-013**: The system MUST expose `Resummarize as…` in the meeting row context menu within the notes list and in the meatball menu shown while viewing a summary or transcript.
- **FR-014**: The `Resummarize as…` action MUST be disabled in both menu surfaces when the meeting cannot be reprocessed because its transcript artifact is missing or unreadable.

### Non-Functional Requirements *(mandatory)*

- **NFR-001**: System MUST preserve local-only processing and avoid outbound network calls except model downloads.
- **NFR-002**: System MUST maintain deterministic output for note and transcript rendering so the same transcript source and meeting type produce the same regenerated note.
- **NFR-003**: Long-running reprocessing operations MUST support cancellation and avoid blocking the UI thread.
- **NFR-004**: UX changes MUST align with the pipeline state machine and provide clear user status and failure messages without exposing internal details.
- **NFR-005**: Transcript persistence and reprocessing flows MUST avoid presenting screen context as if it were spoken by a participant.
- **NFR-006**: Reprocessing safeguards for edited notes MUST remain explicit and non-destructive until the user confirms overwrite.
- **NFR-007**: Reprocess action labeling and enablement MUST remain consistent between the notes list context menu and the overlay meatball menu.

### Key Entities *(include if feature involves data)*

- **Processed Meeting**: A completed meeting record with a note, transcript, audio artifact, and associated meeting type.
- **Transcript Artifact**: The durable meeting transcript used as the source for viewing and later reprocessing, containing spoken content and any persisted screen context entries.
- **Screen Context Entry**: A timestamped, clearly labeled transcript entry that captures non-spoken context derived from the user’s selected screen content.
- **Reprocess Request**: An explicit user action that selects a different explicit meeting type and regenerates the app-managed note for an existing processed meeting.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: In usability testing, users can change a processed meeting to a different meeting type and start reprocessing in under 20 seconds without needing to rerecord the meeting.
- **SC-002**: At least 95% of processed meetings with an intact transcript artifact can be successfully reprocessed to a different meeting type on the first attempt.
- **SC-003**: In transcript review tests for meetings with screen context enabled, 100% of persisted screen-derived entries are visibly labeled as Screen Context and can be distinguished from spoken transcript lines.
- **SC-004**: Reprocessing does not increase the number of vault artifacts per meeting beyond the existing three-file contract in any release acceptance test.

## Assumptions

- Reprocessing is an explicit recovery action for already-processed meetings and is not part of the live recording flow.
- The transcript artifact is the durable input for later reprocessing; the feature does not require users to keep temporary processing artifacts.
- Screen context entries are persisted during normal meeting processing so they remain available for later transcript review and reprocessing.
- Reprocessing regenerates and overwrites the app-managed meeting note for the selected meeting but does not require creating a new meeting record.
- If user edits are detected in the meeting note, the system prompts for overwrite or cancel before continuing.

## Out of Scope

- Re-recording or re-capturing audio as part of reprocessing.
- Introducing additional vault files beyond the existing note, audio, and transcript artifacts.
- Creating a save-as-new copy of the meeting note during reprocessing.
- Real-time editing of screen context entries after the meeting has already been processed.
