# Data Model — Background Summarization for Back-to-Back Meetings

**Date**: 2026-02-06  
**Feature**: [spec.md](spec.md)  
**Research**: [research.md](research.md)

This describes the conceptual entities and state needed to support background meeting processing while allowing immediate back-to-back recording.

## Entities

### Meeting
Represents a recorded meeting session.

**Key fields**
- `id`: Stable identifier for the meeting session (UUID)
- `startedAt`, `stoppedAt`: Recording timestamps
- `audioTempURL`: Temporary audio artifact used for processing
- `audioDurationSeconds`: Duration of the captured audio
- `meetingType`: User-selected or inferred meeting type
- `screenContextEvents`: Captured context events (may be empty)
- `outputs`: Links to generated outputs (note URL, transcript URL, audio URL), if processing completed

**Validation rules**
- `startedAt < stoppedAt`
- `audioDurationSeconds > 0`
- `audioTempURL` must exist while processing is pending/running

### BackgroundProcessingState (v1)
Represents the minimal orchestration state required to support background processing without building a general job system.

**Key fields**
- `activeMeetingId`: The meeting currently being processed (or `nil` if idle)
- `activeStage`: Optional stage aligned with pipeline (`downloadingModels`, `transcribing`, `summarizing`, `writing`)
- `activeProgress`: Optional fraction 0...1 (coarse)
- `pendingMeetingId`: Optional “next meeting to process” slot (v1 allows at most one pending)
- `activeOutcome`: Optional last outcome for `activeMeetingId` (`completed`, `canceled`, `failed(error)`)

**Validation rules**
- At most one meeting may be processing at a time: `activeMeetingId` is a single value.
- v1 backlog is intentionally limited: `pendingMeetingId` is either `nil` or a single meeting.
- A meeting may transition to “processed” only after outputs are atomically written.

### FirstScreenInferenceState (v1)
Represents whether the first screen context inference for a recording session has run yet.

**Key fields**
- `meetingId`
- `status`: `ready` | `deferredDueToProcessing` | `executing` | `completed` | `skipped`

**Validation rules**
- The first inference must not begin while `BackgroundProcessingState.activeMeetingId` is non-`nil`.
- Deferral must never block recording; it only delays inference.

## Relationships

- Meeting `1 -> 0..1` BackgroundProcessingState.activeMeetingId (one meeting can be active at a time)
- Meeting `1 -> 0..1` BackgroundProcessingState.pendingMeetingId (v1: at most one pending)
- Meeting `1 -> 0..1` FirstScreenInferenceState (per meeting/session)

## State Transitions

### Background processing transitions (v1)
- `idle (activeMeetingId=nil) -> processing(meetingId=A, stage=downloadingModels)`
- `processing(A) -> processing(A, stage=transcribing) -> processing(A, stage=summarizing) -> processing(A, stage=writing)`
- `processing(A) -> idle (completed|canceled|failed)`
- `processing(A) + meeting B stops recording -> pendingMeetingId=B`
- `idle + pendingMeetingId=B -> processing(B) (auto-start)`

### First screen inference transitions (v1)
- `ready -> executing -> completed`
- `ready + active processing -> deferredDueToProcessing`
- `deferredDueToProcessing -> ready` (when `activeMeetingId` becomes `nil`)
- `ready|deferredDueToProcessing -> skipped` (if screen capture disabled or meeting ends before first inference is desired)
