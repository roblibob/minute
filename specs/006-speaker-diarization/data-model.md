# Data Model — Speaker Diarization & Identification

**Feature**: [spec.md](spec.md)
**Date**: 2026-02-07

This document defines entities, fields, relationships, and validation rules.

## Entities

### SpeakerSegment
Represents diarization output for a single contiguous segment.

- `speakerId` (String or Int-like String)
  - Validation: non-empty; stable within a meeting.
- `startSeconds` (Double)
  - Validation: `>= 0`.
- `endSeconds` (Double)
  - Validation: `> startSeconds`.
- `text` (String)
  - Validation: may be empty for non-speech segments if produced; UI should handle gracefully.
- `embedding` (optional `[Float]`)
  - Validation: if present, length 256 and L2-normalized.

### MeetingSpeakerMap
Stores per-meeting mapping from diarization speaker labels to user-facing participant names.

- `meetingId` (String)
  - Validation: stable identifier derived from meeting output file base name or internal meeting UUID.
- `speakerToParticipant` (Dictionary<String, String>)
  - Key: `speakerId`.
  - Value: participant name (or participant id if we introduce ids).
  - Validation: participant name non-empty.
- `participants` ([String])
  - Validation: unique (case-insensitive) after normalization.
- `updatedAt` (Date)

### SpeakerProfile
Represents a known speaker for cross-meeting suggestions.

- `id` (String)
  - Validation: stable, unique; safe for filenames (if stored per-profile).
- `name` (String)
  - Validation: non-empty.
- `embedding` ([Float])
  - Validation: length 256, L2-normalized.
- `enrollmentStats` (object)
  - `effectiveDurationSeconds` (Double)
  - `segmentsUsed` (Int)
  - `meanSimilarityToCentroid` (Double)
  - `stddevSimilarityToCentroid` (Double)
- `embeddingModelVersion` (String)
  - Validation: required to handle future embedding model changes.
- `createdAt` (Date)
- `updatedAt` (Date)
- `isPermanent` (Bool)

### MeetingParticipantFrontmatter
The subset of meeting note frontmatter owned by Minute for participant data.

- `participants` ([String])
- `speaker_map` (Dictionary<String, String>)

Validation rules:
- Must be deterministic when written.
- Must not break existing frontmatter fields.
- Ordering must be deterministic (FR-002a): when emitting `participants` and `speaker_map`, order speakers by total speaking duration (desc), tie-break by earliest segment start (asc), then by stable internal speaker identifier.

## Relationships

- A Meeting has many `SpeakerSegment`.
- A Meeting has one `MeetingSpeakerMap`.
- A `MeetingSpeakerMap` references many `Participant` names.
- A `SpeakerProfile` can be suggested for one or more meeting speakers based on embedding similarity.

## State transitions

### Speaker naming

- `Unlabeled speakerId` → `Named participant` when user assigns a name.
- `Named participant` → `Renamed participant` when user edits.
- `Named participant` → `Removed` when user clears mapping.

### Profile suggestions (optional)

- `Unknown speaker` → `Suggested known speaker` when embedding match under threshold.
- `Suggested` → `Confirmed` when user accepts.
- `Confirmed` → `Enrolled/Updated profile` when user chooses to save the mapping.
