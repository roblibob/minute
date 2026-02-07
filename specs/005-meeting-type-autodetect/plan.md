# Implementation Plan: Meeting Type Autodetect Calibration

**Branch**: `005-meeting-type-autodetect` | **Date**: 2026-02-07 | **Spec**: [specs/005-meeting-type-autodetect/spec.md](spec.md)
**Input**: Feature specification from `/specs/005-meeting-type-autodetect/spec.md`

**Note**: This template is filled in by the `/speckit.plan` command. See `.specify/templates/commands/plan.md` for the execution workflow.

## Summary

Improve meeting-type Autodetect so it stops over-committing to the wrong type. If classification is uncertain, ambiguous, or invalid, the system must default to `General`.

Approach: tighten the meeting-type classification prompt to be conservative (explicit default-to-General rule, clear definitions, anti-signals, and a small set of few-shot examples), and harden parsing/validation so ambiguous outputs resolve to `General`. Add a deterministic offline evaluation set (unit tests) to prevent regressions.

## Technical Context

<!--
  ACTION REQUIRED: Replace the content in this section with the technical details
  for the project. The structure here is presented in advisory capacity to guide
  the iteration process.
-->

**Language/Version**: Swift 5.9 (Xcode 15.x)  
**Primary Dependencies**: MinuteCore (Swift Package), local llama.cpp XCFramework integration (`MinuteLlama`), SwiftUI app target  
**Storage**: N/A (classification is derived from transcript text; no new persisted entities required)  
**Testing**: Swift Testing in `MinuteCore/Tests` (TDD per constitution)  
**Target Platform**: macOS 14+ (Apple Silicon focus)
**Project Type**: Native macOS app (`Minute/`) + core logic in Swift package (`MinuteCore/`)  
**Performance Goals**: Classification should complete quickly (goal: <1s on typical transcripts; bounded tokens) and not meaningfully extend overall processing time  
**Constraints**: Local-only, deterministic behavior at boundaries, privacy-safe logging (no raw transcript), no changes to vault output contract  
**Scale/Scope**: Small feature scoped to meeting-type classification prompt + parsing + tests; no UI changes required

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

- Output contract unchanged or updated docs/tests included. ✅ Unchanged
- Local-only processing preserved; no outbound network calls beyond model downloads. ✅ Preserved
- Deterministic Markdown rendering maintained for any note changes. ✅ No note format changes
- MinuteCore tests added/updated for new behavior (renderer, file contracts, JSON validation). ✅ Add classifier-focused tests in MinuteCore
- Pipeline state machine and cancellation support respected for long-running work. ✅ No new long-running work; keep cancellation checks in inference path

**Gate Status**: PASS (no justified violations)

## Project Structure

### Documentation (this feature)

```text
specs/005-meeting-type-autodetect/
├── plan.md              # This file (/speckit.plan command output)
├── research.md          # Phase 0 output (/speckit.plan command)
├── data-model.md        # Phase 1 output (/speckit.plan command)
├── quickstart.md        # Phase 1 output (/speckit.plan command)
├── contracts/           # Phase 1 output (/speckit.plan command)
└── tasks.md             # Phase 2 output (/speckit.tasks command - NOT created by /speckit.plan)
```

### Source Code (repository root)
```text
Minute/                         # SwiftUI app target (UI + orchestration)
MinuteCore/                     # Swift Package (business logic, contracts, tests)
├── Sources/
│   └── MinuteCore/
│       └── Summarization/
│           └── Services/
│               └── MeetingTypeClassifier.swift
└── Tests/
    └── MinuteCoreTests/
        └── Summarization/
            └── MeetingTypeClassifierTests.swift

MinuteCore/Sources/MinuteLlama/  # llama library integration used for classification+summarization
```

**Structure Decision**: Implement the behavior in `MinuteCore` so it is testable and keeps UI thin. Any prompt changes live in `MinuteCore` (prompt builder/classifier), and tests live in `MinuteCore/Tests`.

## Implementation Approach (Phase 2 plan)

1. **Add a deterministic evaluation set (tests-first)**
  - Create a small set of transcript snippets covering:
    - clear positives for each type
    - “keyword traps” (should be `General`)
    - mixed/hybrid meetings (should be `General`)
    - low-information short snippets (should be `General`)
  - Write tests asserting the classifier returns the expected `MeetingType`.

2. **Update the classification prompt to be conservative**
  - Explicit rule: if uncertain/ambiguous, output `General`.
  - Add crisp definitions and “strong signals” per type.
  - Add anti-signals to prevent keyword overfitting.
  - Add a small number of few-shot examples (including ambiguous → `General`).
  - Keep output contract strict: exactly one allowed label; no extra text.

3. **Harden parsing/validation to avoid accidental matches**
  - Treat outputs containing multiple labels, punctuation/explanations, or no exact match as invalid → `General`.
  - Avoid substring matches that cause false positives.

4. **(Optional, if supported) tighten inference settings for classification**
  - Use low temperature (ideally 0), fixed seed, and small max tokens.
  - Ensure no transcript is logged; keep logs to lengths/attempt counts only.

5. **Re-run evaluation tests; adjust prompt examples as needed**
  - Optimize for precision on non-General types (conservative selection) while maintaining good coverage for “clear” examples.

## Post-Design Constitution Re-check

- Output contract: unchanged ✅
- Local-only and privacy: unchanged ✅
- Determinism: prompt+parse changes are deterministic; tests lock behavior ✅
- Test-gated logic: add `MinuteCore` tests for classifier behavior ✅

## Complexity Tracking

No constitution violations; nothing to justify.
