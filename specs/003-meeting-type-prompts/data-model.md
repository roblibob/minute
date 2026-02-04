# Data Model: Meeting Type Prompts

**Feature Branch**: `003-meeting-type-prompts`
**Date**: 2026-02-04

## 1. Domain Entities

### `MeetingType` (Enum)

Represents the user-selected or auto-detected category of the meeting.

```swift
public enum MeetingType: String, CaseIterable, Codable, Sendable {
    case general
    case standup
    case designReview = "design_review"
    case oneOnOne = "one_on_one"
    case presentation
    case planning
    case autodetect // UI-only state? Or persistable?
}
```

**Refinement on Autodetect**:
The `Meeting` struct should probably store the *resolved* type if autodetect ran, or the *user-selected* type?
Actually, the requirement says "Autodetect" is the default. If the user leaves it as "Autodetect", we persist "autodetect". When summarizing:
- If "autodetect" -> Run Pass 1 -> Get concrete type -> Run Pass 2.
- Should we update the stored type to the detected one? **Decision**: Yes, helpful for the user to see what it was classified as. But maybe keep a flag `wasAutodetected`.
For simplicity in V1:
- Store actual selection. If "autodetect", store "autodetect".
- Pipeline resolves it to a temporary concrete type for processing.

### `Meeting` (Extension)

We need to add the property to the existing Meeting model (logic likely in `MinuteCore`).

```swift
// Pseudo-code extension to existing model
public struct MeetingMetadata: Codable {
    // ... existing fields ...
    public var meetingType: MeetingType? // Optional for backward compatibility
}
```

## 2. Service Architecture

### `PromptStrategy` (Protocol)

```swift
public protocol PromptStrategy {
    var meetingType: MeetingType { get }
    func systemPrompt(meetingDate: Date) -> String
}
```

### `SummarizationService` (Updates)

New signature for usage:

```swift
func summarize(transcript: String, meetingDate: Date, type: MeetingType) async throws -> String
```

## 3. Storage Schema

**File**: `MeetingMetadata.json` (or equivalent internal representation)

**Changes**:
Add `"meeting_type": "string"` field.

**Example**:
```json
{
  "id": "uuid",
  "title": "Weekly Sync",
  "meeting_type": "standup",
  "...": "..."
}
```
