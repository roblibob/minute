# Feature Specification: Speaker Diarization & Identification

**Feature Branch**: `006-speaker-diarization`  
**Created**: 2026-02-07  
**Status**: Draft  
**Input**: User description: "Epic new feature: Speaker diarization and identification. Spec Prefix 005. Improve diarization and speaker identification using FluidAudio’s offline diarization pipeline; consider a small local embeddings database for known speakers; normalize loudness for mic recordings; provide subtle UI to manually identify speakers (potentially via meeting note frontmatter participants)."

## Clarifications

### Session 2026-02-07

- Q: Where should per-meeting speaker naming be persisted to satisfy the 3-file vault contract? → A: Store `participants` + `speaker_map` only in the meeting note YAML frontmatter; optionally update transcript speaker headings only on explicit user action (no automatic rewrites).
- Q: What loudness normalization approach should be used for analysis audio? → A: Use bundled `ffmpeg` `loudnorm` with a pinned preset and deterministic 2-pass flow (target `I=-16`, `TP=-1.5`, `LRA=11`, `linear=true`, `print_format=json`).
- Q: What is the canonical source of speaker embeddings for cross-meeting suggestions? → A: Use OfflineDiarizer embedding export to the meeting working directory (temporary, non-vault), then aggregate deterministically per speaker and persist profiles in app-owned storage.
- Q: How does a user enroll a “known speaker” profile ("Save as Known Speaker…") if embeddings are temporary? → A: Enrollment MUST be an explicit user action; the app MUST either retain a small app-owned cache of per-meeting aggregated speaker embeddings long enough for enrollment, or require a user-initiated reprocess to make enrollment possible later.
- Q: Should cross-meeting known-speaker suggestions be enabled by default? → A: Default OFF; user must explicitly enable “Known speaker suggestions” in Settings.
- Q: What deterministic ordering should be used when rendering speakers/segments? → A: Order speakers by total speaking duration (descending), tie-break by earliest segment start time (ascending), then by stable internal speaker identifier.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Speaker-labeled transcript is accurate and readable (Priority: P1)

As a user reviewing a processed meeting, I want the transcript to clearly separate who spoke when, so I can attribute statements correctly and skim the meeting quickly.

**Why this priority**: Speaker attribution is foundational to meeting usefulness.

**Independent Test**: Process a multi-speaker meeting and verify the transcript contains stable, speaker-labeled segments without requiring any manual naming.

**Acceptance Scenarios**:

1. **Given** a meeting audio recording with multiple speakers, **When** processing completes, **Then** the transcript is partitioned into speaker-labeled segments that cover the full meeting (no gaps due to attribution logic).
2. **Given** the same meeting processed twice with identical inputs and settings, **When** the transcript output is compared, **Then** segmentation order and speaker label assignment are consistent.

---

### User Story 2 - Quiet / far speakers remain intelligible for analysis (Priority: P2)

As a user, I want quiet speakers (far from the microphone) to be represented in the transcript and diarization quality, so the meeting record isn’t dominated by whoever sat closest to the mic.

**Why this priority**: Real-world meetings frequently have uneven distance-to-mic, and current outcomes miss or mis-attribute quieter speakers.

**Independent Test**: Process a recording with intentionally uneven loudness and verify improved transcription coverage of quiet passages and fewer diarization failures.

**Acceptance Scenarios**:

1. **Given** a meeting recording with large loudness differences between speakers, **When** analysis preprocessing is applied, **Then** far/quiet speech is more consistently detected and included in the transcript.
2. **Given** a recording that is already balanced, **When** analysis preprocessing is applied, **Then** transcript quality does not regress (no systematic word loss introduced).

---

### User Story 3 - Subtle manual speaker naming while viewing a meeting (Priority: P3)

As a user viewing a meeting, I want a subtle UI that lets me rename speakers to participant names, so the transcript becomes personally meaningful without clutter.

**Why this priority**: Automatic diarization can label speakers but cannot reliably assign real names; manual naming should be fast and non-obstructive.

**Independent Test**: Open a processed meeting, rename one speaker, and verify the rename persists and updates all visible segments for that speaker.

**Acceptance Scenarios**:

1. **Given** a processed meeting with generic speaker labels, **When** the user renames a label to a participant name, **Then** the transcript displays the participant name wherever that speaker appears.
2. **Given** the meeting note includes participant metadata, **When** the user renames a speaker, **Then** the participant metadata is updated accordingly (without creating any additional meeting output files).
3. **Given** the user has renamed speakers for a meeting, **When** they return later, **Then** the meeting still shows the same participant names.

---

### User Story 4 - Enroll a “known speaker” from a meeting (Priority: P3, optional)

As a user, I want to explicitly save a meeting’s speaker as a reusable “known speaker” profile, so future meetings can suggest names without me re-typing them.

**Why this priority**: This reduces repeated manual naming for recurring participants, while keeping privacy and user control.

**Independent Test**: Process two meetings with at least one recurring speaker, enroll that speaker as a known profile from meeting 1, then verify meeting 2 surfaces the suggestion without overwriting user edits.

**Acceptance Scenarios**:

1. **Given** a processed meeting with diarized speakers, **When** the user chooses “Save as Known Speaker…” for a speaker and provides a name, **Then** a local-only profile is created/updated and can be removed later.
2. **Given** a later meeting with a recurring speaker and known-speaker suggestions enabled, **When** the meeting is processed, **Then** the app surfaces a suggested participant mapping for that speaker without overwriting any existing user-provided mappings.
3. **Given** a processed meeting where speaker embeddings are not available (e.g., cache expired or artifacts removed), **When** the user attempts enrollment, **Then** the app provides an actionable path (e.g., “Reprocess to enable enrollment”) rather than silently failing.

### Edge Cases

- Single-speaker meetings should not prompt manual speaker identification.
- Very short interjections should not cause unreadable rapid speaker switching.
- Overlapping speech must not crash processing; representation may be best-effort but must remain readable.
- Background noise or music should not prevent producing a transcript.
- If speaker identification data is unavailable or corrupted, the system must fall back to generic speaker labels and allow manual naming.


## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: System MUST perform speaker diarization offline as part of meeting processing.
- **FR-002**: System MUST output a transcript that is segmented and labeled by speaker.
- **FR-002a**: Speaker label ordering in rendered views/files MUST be deterministic: order speakers by total speaking duration (descending), tie-break by earliest segment start time (ascending), then by a stable internal speaker identifier.
- **FR-003**: System MUST apply loudness normalization (or equivalent level-balancing) to audio used for analysis so that far/quiet speakers are less likely to be missed or mis-attributed.
- **FR-003a**: Loudness normalization MUST be deterministic and use bundled `ffmpeg` `loudnorm` with pinned targets (`I=-16`, `TP=-1.5`, `LRA=11`, `linear=true`) using a 2-pass flow (pass 1 emits JSON stats; pass 2 applies those stats).
- **FR-003b**: Loudness normalization MUST apply to analysis inputs only (diarization/transcription) and MUST NOT modify the archived vault WAV unless the user explicitly opts in.
- **FR-004**: System MUST preserve the existing meeting output contract: exactly three files are written per processed meeting at these paths:
  - `Meetings/YYYY/MM/YYYY-MM-DD HH.MM - <Title>.md`
  - `Meetings/_audio/YYYY-MM-DD HH.MM - <Title>.wav`
  - `Meetings/_transcripts/YYYY-MM-DD HH.MM - <Title>.md`
  - Speaker-related metadata MUST be stored within those files (not as extra files).
- **FR-005**: System MUST provide a subtle in-meeting UI to rename speakers while viewing a processed meeting.
- **FR-006**: System MUST persist user-provided speaker names per meeting and display them consistently across the transcript and meeting view.
- **FR-007**: System MUST write participant metadata into the meeting note in a machine-readable format that is easy to read and edit in Obsidian (e.g., as note frontmatter properties).
- **FR-007a**: Participant metadata MUST be stored ONLY in the meeting note YAML frontmatter (`participants`, `speaker_map`) and MUST NOT create any additional vault files.
- **FR-007b**: Updating transcript speaker headings (if supported) MUST be an explicit user action and MUST NOT automatically rewrite the transcript file during normal viewing.
- **FR-008**: System MUST support an optional local-only speaker profile capability that can suggest/auto-assign names for speakers in new meetings.
- **FR-008**: System MUST support an optional local-only speaker profile capability that can suggest participant names for speakers in new meetings.
- **FR-008a**: If speaker profiles are enabled, the system MUST source embeddings from the offline diarization pipeline (e.g., OfflineDiarizer embedding export) written only to the meeting working directory (temporary, non-vault).
- **FR-008b**: The system MUST deterministically aggregate per-segment embeddings into a per-speaker embedding before matching/storing (aggregation method defined in implementation and tested for determinism).
- **FR-008c**: Known-speaker suggestions MUST be opt-in and disabled by default; enabling/disabling MUST be controlled via a user setting.
- **FR-008d**: The system MUST provide an explicit user action to enroll a meeting speaker into a known speaker profile (create or update) without writing any additional vault files.
- **FR-008e**: The system MUST define and implement a user-friendly enrollment availability policy: if enrollment requires embedding data that is no longer available, the system MUST present an actionable recovery option (e.g., reprocess) and MUST NOT invent or guess a profile.
- **FR-009**: Users MUST be able to manage their known speaker profiles, including removing a profile.
- **FR-009a**: Profile enrollment MUST NOT overwrite or mutate meeting note frontmatter automatically; it only affects future suggestions unless the user explicitly applies a suggested mapping to the meeting.
- **FR-010**: System MUST not overwrite user edits to the meeting note or transcript unless the user explicitly requests a reprocess/regenerate action.
- **FR-010a**: Suggestions MUST NOT overwrite any existing non-empty user-provided `speaker_map` entries; they may only fill missing mappings or be presented as non-destructive suggestions.

### Non-Functional Requirements *(mandatory)*

- **NFR-001**: System MUST preserve local-only processing and avoid outbound
  network calls except model downloads.
- **NFR-002**: System MUST maintain deterministic output for any note rendering or contract changes.
- **NFR-003**: Long-running operations MUST support cancellation and avoid blocking the UI thread.
- **NFR-004**: UX changes MUST be clean and non-obstructive; speaker naming must not block reading the meeting.
- **NFR-005**: The system MUST avoid exposing sensitive meeting content in logs by default.
- **NFR-006**: Any local speaker profile data MUST be removable by the user.

### Key Entities *(include if feature involves data)*

- **Speaker Segment**: A contiguous portion of transcript attributed to one speaker label, including start/end time and text.
- **Speaker Label**: A stable identifier for a speaker within a single meeting.
- **Participant**: A user-facing person name that can be mapped to one or more speaker labels.
- **Speaker Profile**: A local-only representation of a known speaker used to suggest a participant name in future meetings.
- **Meeting Participant Metadata**: Machine-readable participant information stored inside the meeting note for Obsidian visibility/editing.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Users can rename all speakers in a typical meeting (up to 6 speakers) in under 30 seconds.
- **SC-002**: For recordings with clear near/far microphone placement, users report improved coverage of far/quiet speakers in at least 70% of tested meetings.
- **SC-003**: After manual naming, users can correctly attribute at least 80% of speaker-labeled segments in a 3+ speaker meeting (measured by user validation on a sample set).
- **SC-004**: When speaker profiles are enabled, the system suggests the correct known participant for at least 60% of recurring speakers (measured on-device with user confirmation).

## Assumptions

- Speaker diarization and speaker profile recognition run entirely offline.
- Loudness normalization is used to improve analysis quality (diarization/transcription) and does not require altering the archived meeting audio unless the user explicitly opts in.
- "Spec Prefix 005" is treated as a cross-reference to an internal initiative rather than the repository's branch/spec directory numbering.

## Out of Scope (for this iteration)

- Real-time diarization during recording.
- Cross-device synchronization of known speakers.
- Automatic naming from contacts or calendar attendees.
