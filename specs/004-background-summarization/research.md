# Research — Background Summarization for Back-to-Back Meetings

**Date**: 2026-02-06  
**Feature**: [spec.md](spec.md)

This document consolidates design research and decisions needed to implement background meeting processing while preserving recording reliability and good UX.

## v1 simplification note

The implementation plan for v1 intentionally avoids a general-purpose job system. Instead, it uses:

- a minimal “single active + optional single pending” orchestrator, and
- a lightweight “processing busy” gate to defer *first screen inference* while processing is running.

v1 scope reminders:
- At most one meeting processes at a time.
- At most one additional meeting is kept as “pending next”. If the pending slot is already full, additional meetings require a manual action (e.g., retry/process later).
- “Background” means while Minute is running (no daemon/agent promises).

The sections below capture the original broader design space; items explicitly marked “Future” are not required for v1.

## Decision 1: Serialize processing with a minimal orchestrator (Swift Concurrency `actor`)

**Decision (v1)**: Add a MinuteCore-owned orchestrator (`actor`) that runs at most one meeting processing pipeline at a time, with an optional single pending meeting.

**Rationale**:
- A single worker prevents overlapping heavy stages (transcription/summarization/writing) while still allowing the UI to start a new recording immediately.
- Keeping orchestration in MinuteCore preserves the “UI stays thin” constitution principle and avoids `@MainActor` accidental CPU work.
- Matches the existing `MeetingPipelineCoordinator.execute(context:)` design (a unit of work that can be scheduled).

**Alternatives considered**:
- Run processing directly in `MeetingPipelineViewModel` as today: rejected because current state machine enforces one-at-a-time and `processingTask` cancellation would interfere with back-to-back.
- Allow multiple processing tasks concurrently: rejected due to performance/thermal/memory contention and increased risk of recording instability.

## Decision 2: Defer first screen inference while processing is busy

**Decision (v1)**: Use a small explicit “processing busy” gate so that while meeting processing is running, the first screen inference for a new recording session is deferred.

**Rationale**:
- On Apple Silicon, concurrent ML tasks can collide via unified memory bandwidth, Metal contention, and thermal throttling, producing latency spikes that can harm real-time capture.
- The feature explicitly requires deferring the first screen context inference of Meeting B until Meeting A processing is complete.
- A shared gate is simpler and more deterministic than adaptive throttling for v1.

**Future**: If we later need broader cross-workload serialization (e.g., multiple ML entry points), we can introduce a generalized `ComputeGate`/permit.

## Decision 3: Split “capture state” from “processing state” in the user-facing model

**Decision**: Replace the single, mutually-exclusive `MeetingPipelineState` concept (idle vs recording vs processing) with two orthogonal pieces of state exposed to the UI:
- Capture/Recording state (idle/recording)
- Background processing state (none/running/waiting/completed/failed for one or more meetings)

**Rationale**:
- Current `MeetingPipelineState.canStartRecording` only allows recording in `.idle`, which blocks the back-to-back workflow.
- Users need visibility into background work (P2) without losing the ability to start/stop recording.
- Allows the record button to be governed by capture state only, while processing continues independently.

**Alternatives considered**:
- Expand the existing single enum with combined states (e.g., `.recordingWhileProcessing`): rejected because it scales poorly as background work gains more states (waiting, multiple jobs, retry, etc.).

## Decision 4: Background processing scope (v1): while app is running; be interruption-tolerant

**Decision**: v1 “background” means processing continues while the user records another meeting and navigates elsewhere in the app, as long as Minute remains running. For interruptions (sleep/quit/crash), processing should fail safely and be resumable.

**Rationale**:
- macOS does not guarantee background execution after app termination unless you build additional components (daemons/agents), which is out of scope for a v1 feature.
- The product requirement is primarily “back-to-back meetings without waiting”, not “process after quit”.
- Interruption tolerance aligns with edge cases and reduces data loss.

**Alternatives considered**:
- Build a background agent/daemon: rejected as too complex for v1 and likely impacts packaging/signing.

## Decision 5: Progress/status delivery

**Decision (v1)**: Report processing status at a coarse granularity suitable for SwiftUI without flooding updates.

**Rationale**:
- SwiftUI can be overwhelmed by frequent updates; throttling and coalescing prevents UI jank.
- A structured event stream maps cleanly to queued/started/stage/progress/finished/canceled.

**Future**: A job event stream (throttled) can be added if we expand beyond a single pending meeting and need richer history.
