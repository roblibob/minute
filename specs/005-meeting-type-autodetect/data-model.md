# Data Model: Meeting Type Autodetect Calibration

This feature does not introduce new persisted entities. It refines how the system derives a `MeetingType` from a transcript snippet when the user selects Autodetect.

## Entities

### MeetingType

**Description**: The meeting-type category used to choose a summarization strategy.

**Allowed Values**:
- `general`
- `standup`
- `design_review`
- `one_on_one`
- `presentation`
- `planning`

**Notes**:
- `autodetect` is a UI/user selection, not a derived meeting-type result.
- The derived meeting type must always be one of the six non-autodetect values.

### ClassificationInput

**Description**: The text used to classify meeting type.

**Fields**:
- `transcriptSnippet: String`
  - Derived from the meeting transcript.
  - May be truncated for performance.

**Validation Rules**:
- If `transcriptSnippet` is too short / low-information, classification should yield `general`.

### ClassificationResult

**Description**: The derived meeting type used by summarization.

**Fields**:
- `meetingType: MeetingType`

**Validation Rules**:
- Must be exactly one allowed meeting type.
- If the classifier output is invalid, ambiguous, or cannot be mapped, the system defaults to `general`.

## State / Transitions

- **User selection**: `autodetect`
- **Derived state**: `autodetect` → `meetingType = {general|standup|design_review|one_on_one|presentation|planning}`
- **Fallback**: any uncertainty/ambiguity/invalid output → `meetingType = general`

