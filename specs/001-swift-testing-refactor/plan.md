# Implementation Plan: Swift Testing Refactor and Coverage

**Branch**: `001-swift-testing-refactor` | **Date**: 2026-02-03 | **Spec**: `specs/001-swift-testing-refactor/spec.md`
**Input**: Feature specification from `/specs/001-swift-testing-refactor/spec.md`

## Summary

Migrate all existing automated tests across targets to the Swift Testing
framework and expand coverage, with clear targets for overall and critical-path
coverage plus a readable default coverage summary and optional machine-readable
output.

## Technical Context

**Language/Version**: Swift 5.9 (Xcode 15.x)  
**Primary Dependencies**: SwiftUI, AVFoundation, ScreenCaptureKit, MinuteCore,
Fluidaudio, llama  
**Storage**: Files (Obsidian vault output, app support directories)  
**Testing**: Swift Testing (migration from existing tests)  
**Target Platform**: macOS 14+  
**Project Type**: single (macOS app + Swift Package)  
**Performance Goals**: Full test suite completes in <= 10 minutes on a
reasonable developer machine  
**Constraints**: Local-only processing; no outbound network calls except model
weights; deterministic output contract must remain intact  
**Scale/Scope**: Single app + shared core library; tests span all targets

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

- Output contract unchanged or updated docs/tests included. ✅ (no contract
  changes planned; tests updated)
- Local-only processing preserved; no outbound network calls beyond model
  downloads. ✅
- Deterministic Markdown rendering maintained for any note changes. ✅ (no note
  changes planned)
- MinuteCore tests added/updated for new behavior (renderer, file contracts,
  JSON validation). ✅ (migration + coverage expansion)
- Pipeline state machine and cancellation support respected for long-running
  work. ✅ (not modified)

Post-design re-check: ✅ (research, data model, contracts, and quickstart align)

## Project Structure

### Documentation (this feature)

```text
specs/001-swift-testing-refactor/
├── plan.md              # This file (/speckit.plan command output)
├── research.md          # Phase 0 output (/speckit.plan command)
├── data-model.md        # Phase 1 output (/speckit.plan command)
├── quickstart.md        # Phase 1 output (/speckit.plan command)
├── contracts/           # Phase 1 output (/speckit.plan command)
└── tasks.md             # Phase 2 output (/speckit.tasks command)
```

### Source Code (repository root)

```text
Minute/                         # App target (SwiftUI)
MinuteCore/                     # Swift Package (non-UI logic, services)
MinuteWhisperService/           # XPC helper for transcription
Vendor/                         # Bundled binaries (e.g., ffmpeg)
scripts/                        # Release/notarization tooling
docs/                           # Product + release docs
```

**Structure Decision**: Single macOS app with a Swift Package core; tests live
alongside their respective targets (Minute, MinuteCore, services) and are
migrated to Swift Testing.

## Complexity Tracking

No constitution violations identified.
