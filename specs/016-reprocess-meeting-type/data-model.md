# Data Model: Reprocess Meeting Type

This feature introduces no new vault artifacts. It extends how an existing processed meeting is represented for transcript-driven reprocessing and screen-context persistence.

## Entities

### ProcessedMeeting

Represents a meeting already written to the vault and visible in the meeting notes browser.

**Fields**:
- `meetingId: String`
  - Stable identifier derived from the meeting note relative path.
- `title: String`
- `recordingDate: Date?`
- `noteURL: URL`
- `transcriptURL: URL?`
- `audioURL: URL?`
- `currentMeetingTypeId: String?`
- `hasTranscript: Bool`

**Validation**:
- `transcriptURL` must exist and be readable before reprocessing can begin.
- `currentMeetingTypeId` may be absent for older notes; if absent, the browser still may allow reprocessing as long as the user selects a valid explicit target type.

### TranscriptTimelineEntry

Represents one ordered entry in the transcript artifact.

**Fields**:
- `kind: TranscriptTimelineEntryKind`
  - Enum: `speakerSegment | screenContext`
- `timestampStartSeconds: Double`
- `timestampEndSeconds: Double?`
- `displayLabel: String`
- `text: String`
- `speakerId: Int?`
- `windowTitle: String?`

**Validation**:
- `timestampStartSeconds >= 0`
- `timestampEndSeconds == nil || timestampEndSeconds >= timestampStartSeconds`
- `kind == screenContext` requires `displayLabel == "Screen Context"`
- `kind == speakerSegment` requires `speakerId != nil`
- Empty or whitespace-only `text` entries are discarded before rendering.

### ReprocessRequest

Represents the internal command to regenerate a meeting note from an existing transcript.

**Fields**:
- `meetingId: String`
- `noteURL: URL`
- `transcriptURL: URL`
- `targetMeetingTypeId: String`
- `currentMeetingTypeId: String?`
- `overwriteConfirmed: Bool`

**Validation**:
- `targetMeetingTypeId` must be an explicit meeting type and must not equal `autodetect`.
- `targetMeetingTypeId` must differ from `currentMeetingTypeId` when `currentMeetingTypeId` is known.
- `overwriteConfirmed` must be true before the note write step proceeds.

### ReprocessAvailability

Represents the browser/view-model decision about whether reprocessing can start.

**Fields**:
- `meetingId: String`
- `canReprocess: Bool`
- `blockingReason: ReprocessBlockingReason?`
  - Enum: `missingTranscript | unreadableTranscript | sameMeetingType | invalidTargetType`
- `allowedTargetTypeIds: [String]`
- `requiresOverwriteConfirmation: Bool`

**Validation**:
- `allowedTargetTypeIds` excludes `autodetect`.
- `canReprocess == false` when `blockingReason != nil`.

## Relationships

- `ProcessedMeeting` owns exactly one note artifact, one optional transcript artifact, and one optional audio artifact under the existing three-file contract.
- `ProcessedMeeting` has zero or more `TranscriptTimelineEntry` values parsed from its transcript artifact.
- `ReprocessRequest` targets one `ProcessedMeeting` and uses its transcript as source.
- `ReprocessAvailability` is derived from `ProcessedMeeting` metadata and the selected target type.

## State Transitions

### Reprocess flow

1. `viewing` -> `checkingAvailability`
2. `checkingAvailability` -> `blocked`
3. `checkingAvailability` -> `readyToReprocess`
4. `readyToReprocess` -> `confirmingOverwrite`
5. `confirmingOverwrite` -> `cancelled`
6. `confirmingOverwrite` -> `reprocessing`
7. `reprocessing` -> `completed`
8. `reprocessing` -> `failed`

### Transcript timeline rules

1. Raw speaker segments and screen context events are normalized into `TranscriptTimelineEntry` values.
2. Entries are sorted by `timestampStartSeconds` ascending.
3. Ties are broken deterministically by entry kind ordering: speaker segment first, then screen context, then stable original index.
4. Rendered transcript markdown must round-trip back into the same ordered timeline entry set for supported entry forms.
