# Implementation Plan: Background Summarization for Back-to-Back Meetings

**Branch**: `004-background-summarization` | **Date**: 2026-02-06 | **Spec**: [spec.md](spec.md)  
**Input**: Feature specification from `specs/004-background-summarization/spec.md`

## Summary

Enable a “back-to-back meetings” workflow by allowing Meeting A to keep processing (including summarization) in the background while the user immediately starts recording Meeting B.

To preserve performance and recording reliability, defer Meeting B’s **first screen context inference** until Meeting A’s processing is complete.

High-level approach:
- Keep a single MinuteCore source-of-truth orchestrator state and expose derived UI projections for capture/recording and background processing.
- Run meeting processing as a background task that is not tied to a particular view/screen.
- Add a lightweight “processing busy” gate that defers the first screen inference while a meeting is processing.
- Keep v1 intentionally simple: at most one processing run active at a time, with (optionally) a single pending meeting that auto-starts when the current run completes.

## Technical Context

**Language/Version**: Swift 5.9 (Xcode 15.x)  
**Primary Dependencies**: SwiftUI (app), MinuteCore (SPM), MinuteLlama (llama XCFramework + CLI), FluidAudio (ASR/diarization), AVFoundation, ScreenCaptureKit  
**Storage**: Filesystem (vault outputs + temp dirs) + UserDefaults (settings, security-scoped bookmarks)  
**Testing**: Swift Testing in `MinuteCore/Tests/MinuteCoreTests` (Xcode scheme `MinuteCore`), plus app-level tests in `MinuteTests`  
**Target Platform**: macOS 14+ (Apple Silicon focus)  
**Project Type**: Native macOS app + Swift Package for core logic  
**Performance Goals**: Recording start within 3 seconds after stopping a prior meeting; UI interactions complete within 1 second p95 during background processing  
**Constraints**: Local-only processing; atomic vault writes; long-running operations cancellable; avoid UI thread blocking; preserve the “exactly three files per processed meeting” output contract  
**Scale/Scope**: Single-user desktop workload; typical processing is < 1 minute, so v1 optimizes for the common “one meeting processing while another records” case rather than building a general-purpose job system

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

- Output contract unchanged or updated docs/tests included. **PASS** (no path/note contract changes planned)
- Local-only processing preserved; no outbound network calls beyond model downloads. **PASS**
- Deterministic Markdown rendering maintained for any note changes. **PASS** (no renderer changes required)
- MinuteCore tests added/updated for new behavior (renderer, file contracts, JSON validation). **PASS (planned)** (queue/gating/state tests will be added)
- Pipeline state machine and cancellation support respected for long-running work. **PASS (planned)** (serial queue + cancellation propagation)

Update for v1 simplification:
- We still serialize processing (one at a time), but we do not introduce a generalized “job queue” abstraction unless needed to support a single pending meeting.

## Project Structure

### Documentation (this feature)

```text
specs/004-background-summarization/
├── spec.md
├── plan.md
├── research.md
├── data-model.md
├── quickstart.md
└── checklists/
  └── requirements.md
```

### Source Code (repository root)
```text
Minute/                              # SwiftUI app
└── Sources/
  ├── ViewModels/
  │   └── MeetingPipelineViewModel.swift
  └── Views/
    └── ContentView.swift

MinuteCore/                          # Core logic (SPM)
└── Sources/MinuteCore/
  ├── Domain/
  │   └── MeetingPipelineTypes.swift
  ├── Pipeline/
  │   └── MeetingPipelineCoordinator.swift
  └── Services/
    ├── ScreenContextCaptureService.swift
    └── ServiceProtocols.swift

MinuteCore/Tests/MinuteCoreTests/     # Swift Testing
└── MeetingPipelineCoordinatorTests.swift
```

**Structure Decision**: Native macOS app (SwiftUI) with business logic and orchestration in MinuteCore (SPM). UI remains thin.

## Complexity Tracking

> **Fill ONLY if Constitution Check has violations that must be justified**

| Violation | Why Needed | Simpler Alternative Rejected Because |
|-----------|------------|-------------------------------------|

No constitution violations are required for this feature.

## Phase 0 — Research (completed)

See [research.md](research.md).

Key conclusions:
- Serialize heavy work to avoid overlapping compute.
- Add a small, explicit gate to coordinate “meeting processing” vs “first screen inference”.
- Split capture state from processing state for UX clarity.

## Phase 1 — Design & Contracts (completed)

- Data model: [data-model.md](data-model.md)
- Validation steps: [quickstart.md](quickstart.md)

## Phase 2 — Implementation Plan

### 1) MinuteCore: Single active processing run (+ optional single pending)

- Keep `MeetingPipelineCoordinator` as the core pipeline executor.
- Introduce a minimal orchestrator (likely an `actor`) that owns:
  - whether a meeting is currently processing
  - cancellation for the current processing task
  - (optional) a single pending meeting to run next
- Policy for v1:
  - never run more than one meeting processing pipeline concurrently
  - if a meeting completes recording while processing is active, mark it “pending processing” and auto-start it when the current run finishes
  - if a meeting completes recording while one meeting is already pending processing (pending slot full), keep the existing pending meeting (FIFO) and require a manual “Process” action later for additional meetings

### 2) MinuteCore: Processing-busy gate for first screen inference

- Add a lightweight shared gate (not a full compute-permit system) that answers:
  - “Is meeting processing currently active?”
  - “Wait until processing is idle” (async)
- Use this gate in screen inference so that:
  - recording continues
  - screen capture may continue
  - the *first* screen inference attempt (for any selected window) is deferred until processing completes

### 3) App model: decouple recording from processing

- Refactor `MeetingPipelineViewModel` to expose two independent concepts:
  - recording/capture state (what governs record/stop)
  - background processing job status (what governs cancel/retry, progress, and “waiting”)
- Preserve a clean single source-of-truth for each concept and avoid `@MainActor` CPU work.

### 4) Screen context inference deferral (UX + performance)

- Ensure recording can start immediately even if processing is active.
- While processing is active, defer the first screen inference for the new meeting:
  - capture can continue (frames/screenshots) but inference must not start until compute is free
  - once free, inference begins and status updates reflect “waiting → running”

### 5) UX: status and controls

- Add/adjust UI affordances to make background work understandable:
  - show “Processing” and stage for the prior meeting
  - show “Waiting” (deferred inference) for the current meeting when applicable
  - provide cancel + retry for the background job

### 6) Tests (MinuteCore, Swift Testing)

TDD policy (v1): write tests first (compile failures count as “red”), then implement the minimum production code to compile + pass.

Add or update tests to keep behavior deterministic and regression-resistant:
- Processing orchestrator: only one processing run at a time; cancellation works; pending meeting auto-starts after completion.
- Inference deferral gate: first inference waits while processing is active.
- View-model-facing state mapping: recording remains startable while processing is active.

### 7) Performance/QA

- Run the manual scenarios in [quickstart.md](quickstart.md).
- Use Instruments (System Trace/Energy Log) to validate no recording regressions during background processing.
