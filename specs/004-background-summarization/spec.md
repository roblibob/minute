# Feature Specification: Background Summarization for Back-to-Back Meetings

**Feature Branch**: `004-background-summarization`  
**Created**: 2026-02-06  
**Status**: Draft  
**Input**: User description: "As a user I want the summarization to run in background so I can start recording a new meeting back to back. This means delaying the first screen context inference until the previous meeting is done, to make sure the computer can handle the compute. User experience and performance should both be in focus."

## Clarifications

### Session 2026-02-06

- Q: How should we satisfy the constitution’s “single pipeline state machine” while allowing recording + background processing concurrently? → A: Keep a single MinuteCore source-of-truth pipeline/orchestrator state, and expose derived UI projections for capture/recording state and background processing status.
- Q: What should happen if a second meeting finishes while one meeting is already pending processing (v1 pending slot full)? → A: Keep the existing pending meeting (FIFO) and require manual processing for additional finished meetings (do not silently replace the pending slot).
- Q: What is the definition of “first screen context inference” for deferral and testing? → A: The first inference *attempt* during a recording session (for any selected window).
- Q: While the first inference is deferred, should Minute keep capturing frames or pause capture entirely? → A: Keep capturing frames for UX (e.g., latest preview), but pause inference until the previous meeting’s processing is done.
- Q: Should implementation tasks follow strict TDD (tests first) even for new types? → A: Yes—write tests first (compile failures count as “red”), then implement the minimum code to reach “green”.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Record Back-to-Back While Previous Meeting Processes (Priority: P1)

When I finish recording a meeting, I want Minute to continue processing that meeting (including summarization) in the background so that I can immediately start recording the next meeting without waiting.

If the computer is already busy finishing the previous meeting, Minute should delay the first screen context inference for the new meeting until the previous meeting’s processing is complete, so performance remains stable.

**Why this priority**: This enables the core “back-to-back meetings” workflow and prevents missed recordings.

**Independent Test**: Can be fully tested by completing Meeting A, immediately starting Meeting B, and confirming Meeting B records successfully while Meeting A continues processing.

**Acceptance Scenarios**:

1. **Given** Meeting A has ended and is still processing, **When** I start Meeting B, **Then** Meeting B begins recording successfully without requiring me to wait for Meeting A to finish.
2. **Given** Meeting A is processing, **When** I start Meeting B, **Then** the first screen context inference for Meeting B is deferred until Meeting A processing completes, while recording continues.
3. **Given** I record Meeting A and Meeting B back-to-back, **When** processing completes, **Then** both meetings have their expected outputs produced and the app clearly reflects the correct status for each meeting.

---

### User Story 2 - Understand and Control Background Work (Priority: P2)

When processing is happening in the background, I want clear status and progress so I understand what’s happening and what, if anything, is waiting.

I also want safe controls (at minimum: cancel the current processing task) so I can recover if I accidentally start a heavy task at the wrong time.

**Why this priority**: Transparency and control reduce frustration and increase trust, especially when performance is impacted.

**Independent Test**: Can be fully tested by starting background processing, verifying status visibility, then canceling processing and confirming the app returns to a stable state.

**Acceptance Scenarios**:

1. **Given** a previous meeting is processing in the background, **When** I view the app, **Then** I can see that processing is in progress and whether new work is waiting.
2. **Given** background processing is running, **When** I cancel processing, **Then** the app stops the background work and shows a clear outcome (canceled) without corrupting existing outputs.

---

### User Story 3 - Recover Gracefully From Delays or Failures (Priority: P3)

If the computer cannot keep up, or processing fails for a meeting, I want Minute to fail safely: my recordings remain available, the issue is clearly explained, and I can retry processing later.

**Why this priority**: Back-to-back workflows are stressful; failures must be recoverable without data loss.

**Independent Test**: Can be tested by simulating a processing failure and verifying the user can retry later while still recording new meetings.

**Acceptance Scenarios**:

1. **Given** processing fails for a meeting, **When** I return to the app, **Then** I see a clear error state and an option to retry processing.
2. **Given** processing is delayed due to the computer being busy, **When** I start another recording, **Then** the app remains responsive and the delay does not block recording.

---

### Edge Cases

- A meeting finishes recording while a previous meeting is still processing.
- Multiple meetings are recorded back-to-back, but processing is usually short (< 1 minute) so any backlog is typically limited.
- The user starts a new meeting while a previous meeting is still generating outputs.
- The user cancels background processing while output files are being produced.
- The app is closed or the computer sleeps while background processing is running.
- The computer becomes resource constrained (thermal throttling, low battery mode, low free disk space).
- Background processing completes while a new meeting is actively recording.
- A meeting finishes recording before its first screen context inference has run.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: System MUST allow the user to start recording a new meeting even while a previous meeting is still processing in the background.
- **FR-002**: System MUST continue processing a completed meeting in the background without requiring the user to keep the app in a specific foreground screen.
- **FR-003**: System MUST prevent overlapping compute-intensive processing that would degrade recording reliability by deferring the first screen context inference for a new meeting until the previous meeting processing has completed.
  - Definition (v1): “first screen context inference” means the first inference attempt during the current recording session (for any selected window). When deferred, Minute MUST make no inference attempts until the previous meeting’s processing completes.
  - While deferred, Minute SHOULD continue lightweight screen capture for UX (e.g., showing the latest frame/preview), but MUST NOT run inference.
- **FR-004**: System MUST run at most one meeting “processing pipeline” at a time (v1), prioritizing recording reliability.
- **FR-005**: If the user finishes recording a meeting while another meeting is processing, the newly finished meeting MUST enter a clear “pending processing” state and MUST be processed automatically once the current processing completes (v1: at most one pending meeting is auto-started).
  - If a meeting is already pending processing (pending slot is full), v1 MUST keep the existing pending meeting (FIFO) and MUST NOT silently replace it. Additional finished meetings MUST remain recorded and require a manual “Process” action later.
- **FR-006**: System MUST clearly communicate when background processing is in progress, when a meeting is pending processing, and when screen inference is deferred.
- **FR-007**: System MUST ensure each meeting’s outputs are produced exactly once per successful processing run, and reflect the correct meeting identity and time.
- **FR-008**: System MUST allow the user to cancel background processing for a meeting, and cancellation MUST leave the app in a stable state with clear user-facing status.
- **FR-009**: System MUST allow the user to retry processing for a meeting that failed or was canceled, without impacting the ability to record additional meetings.

### Non-Functional Requirements *(mandatory)*

- **NFR-001**: System MUST preserve local-only processing and avoid outbound
  network calls except model downloads.
- **NFR-002**: System MUST maintain deterministic output for any note rendering
  or contract changes.
- **NFR-003**: Long-running operations MUST support cancellation and avoid
  blocking the UI thread.
- **NFR-004**: UX changes MUST provide clear, consistent user status and
  error messages without leaking internal details.

### Key Entities *(include if feature involves data)*

- **Meeting**: A recorded session with a title, start/end time, and associated outputs (note, audio, transcript, summary).
- **Background Processing**: The single active pipeline run that turns a completed meeting recording into outputs.
- **Deferred Screen Inference**: A per-recording flag meaning “we intentionally have not run the first screen context inference yet” until compute is free.
- **Processing State**: A user-visible status for a meeting (e.g., recording, processing, pending processing, completed, failed, canceled).

## Assumptions & Dependencies

### Assumptions

- Users may record meetings back-to-back with little to no gap.
- Users prefer recording reliability over immediate availability of screen context-derived insights.
- Users expect clear status when work is deferred or running in the background.

### Dependencies

- Sufficient free disk space is available to store recordings and outputs for multiple meetings.
- Required on-device models are available (downloaded) or can be downloaded before processing begins.
- The selected Obsidian vault location remains accessible while background processing completes.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Users can start recording a new meeting within 3 seconds of ending the previous meeting, even if the previous meeting is still processing.
- **SC-002**: In back-to-back usage, recording reliability is maintained (no user-visible recording failures attributable to background processing in at least 99% of sessions).
- **SC-003**: The app remains responsive during background processing (primary UI actions complete within 1 second for at least 95% of interactions).
- **SC-004**: For a meeting whose screen context inference is deferred, users can still complete the meeting recording successfully and later receive the finished outputs without manual intervention in at least 95% of cases.
- **SC-005**: 90% of users can correctly explain “what is happening” (processing vs waiting vs completed) after viewing the status UI once.

---

## Background Processing Scope (v1)

- Processing runs “in the background” meaning it continues while Minute is running (even if the app is not frontmost), and it is not tied to a specific UI screen.
- v1 does **not** promise processing will continue if the user quits the app, force-quits, or reboots.

Implementation note: this feature keeps a single source-of-truth pipeline/orchestrator state in `MinuteCore`. The UI may show separate “Recording/Capture” and “Background Processing” sections, but those are derived projections of the underlying state (not independent state machines).

More detailed macOS lifecycle considerations (sleep/wake, throttling, resume strategy) are captured in [research.md](research.md) so the spec stays focused on user-visible behavior.

