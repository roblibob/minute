# Feature Specification: Meeting Type Prompts

**Feature Branch**: `003-meeting-type-prompts`
**Created**: 2026-02-04
**Status**: Draft
**Input**: User description: "I'm working on a ai meeting note taking app. It has a system prompt (attached below). I now want the user to be able to choose meeting types during recording. Each meeting type will cater a system prompt that optimize for that type of meeting. For example if the meeting is a presentation or a talk, the meeting do not usually have decisions or actions and the summary should focus on what was presented. Construct system prompt for different variants of meetings that fits in a tech company setting."

## Clarifications
### Session 2026-02-04
- Q: When can the user select the meeting type? → A: Editable **anytime**: Before, During, and Post-recording (before processing starts).
- Q: What is the default reset behavior? → A: **Reset** to "Autodetect" automatically after each meeting completes.
- Q: How does the user input this choice? → A: **Standard Dropdown/Picker** near the record button, which includes an "Autodetect" option.
- Q: Where is the selection stored? → A: **Store** in the `Meeting` metadata JSON/struct instantly upon selection change.
- Q: How does "Autodetect" work? → A: **Two-pass strategy**. First pass classifies the transcript to a type; second pass maximizes the specific prompt.
- Q: What if autodetect classification fails? → A: **Fallback** to the "General" prompt strategy immediately.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Tailored Summaries via Meeting Type (Priority: P1)

As a user, I want the AI summary to be optimized for the specific type of meeting I held (e.g., Presentation, Standup) so that the notes are more relevant and useful.

**Why this priority**: Core value proposition of the feature.

**Independent Test**: Run the summarization service with a specific meeting type and a sample transcript, verifying the output style matches the requested type.

**Acceptance Scenarios**:

1. **Given** a transcript of a technical talk, **When** grouped with "Presentation" meeting type (or autodetected as such), **Then** the summary focuses on key takeaways and content presented, minimizing irrelevant action item fields vs "General".
2. **Given** a transcript of a daily standup, **When** grouped with "Standup" meeting type, **Then** the summary identifies individual updates and blockers clearly.
3. **Given** no specified meeting type (default "Autodetect"), **When** processed, **Then** the system first classifies the meeting and applies the corresponding optimized prompt, falling back to "General" if ambiguous.

### Edge Cases

- **Existing Data**: Old meetings without a type attribute must default to "General".
- **Ambiguous Content**: If a meeting type is "Presentation" but the content is a debate, the model should still attempt to follow the "Presentation" structure guidelines (e.g. focus on key points) but report facts truthfully.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: System MUST define a set of supported `MeetingType`s:
  - Autodetect (Default)
  - General (Fallback)
  - Standup
  - Design Review
  - One-on-One
  - Presentation
  - Planning
- **FR-002**: The summarization system MUST accept a `MeetingType` parameter when processing a recording.
- **FR-003**: The system MUST generate a distinct system prompt for each `MeetingType` to guide the AI model.
- **FR-008**: The system MUST allow the user to set or change the `MeetingType` at any time: before recording, during recording, or after recording completes (but before summarization begins).
- **FR-009**: The selected `MeetingType` MUST reset to "Autodetect" automatically for every new meeting recording session (no sticky preference).
- **FR-010**: The selected `MeetingType` MUST be persisted in the meeting's metadata immediately upon selection to ensure correct summarization even after app restart.
- **FR-011**: If `MeetingType` is "Autodetect", the system MUST perform a two-pass classification: first identifying the type using a subset or full transcript, then applying the specific prompt for that type.
- **FR-012**: If autodetect fails to identify a clear type or encounters an error, the system MUST fallback to the "General" meeting type prompt.
- **FR-004**: All meeting type prompts MUST produce valid JSON adhering strictly to the existing schema:
  - `title`, `date`, `summary`, `decisions`, `action_items`, `open_questions`, `key_points`.
- **FR-005**: "Presentation" prompt MUST prioritize `key_points` and a content-heavy `summary`.
- **FR-006**: "Standup" prompt MUST prioritize `action_items` (for blockers/follow-ups) and a `summary` reflecting progress.
- **FR-007**: "One-on-One" prompt MUST handle summaries discreetly, focusing on agreed `action_items` and `key_points` discussed.

### Non-Functional Requirements *(mandatory)*

- **NFR-001**: System MUST preserve local-only processing.
- **NFR-002**: JSON output MUST be parseable by the existing app logic (no schema changes).
- **NFR-003**: Architecture MUST use a strategy pattern with separate files for each meeting type prompt definition, likely inheriting from a base class or protocol to ensure ease of extension.

## Success Criteria

- 100% of supported meeting types produce valid structured output.
- "Presentation" summaries contain >0 key points for valid talks.
- "General" behavior remains unchanged (regression testing).

## Key Entities

- `MeetingType` (Domain Enum)
