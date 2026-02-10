# Implementation Plan: Main UI Refactor (Recording Stage)

**Branch**: `008-main-ui-refactor` | **Date**: 2026-02-09 | **Spec**: [specs/008-main-ui-refactor/spec.md](spec.md)
**Input**: Feature specification from [specs/008-main-ui-refactor/spec.md](spec.md)

**Note**: This template is filled in by the `/speckit.plan` command. See `.specify/templates/commands/plan.md` for the execution workflow.

## Summary

Refactor the main content area when no meeting is selected into a centered “Recording Stage” with prominent configuration controls, input-level visualization, and a floating bottom control bar. Preserve existing meeting detail behavior and the deterministic 3-file vault output contract.

Key additions beyond layout:
- Persist last-used Stage preferences (Meeting Type + Language Processing + capture toggles).
- Add a “Cancel Session” action during recording that discards the session and produces no vault output.

## Technical Context

<!--
  ACTION REQUIRED: Replace the content in this section with the technical details
  for the project. The structure here is presented in advisory capacity to guide
  the iteration process.
-->

**Language/Version**: Swift 5.9 (Xcode 15.x)  
**Primary Dependencies**: SwiftUI, AVFoundation, ScreenCaptureKit, MinuteCore  
**Storage**: Files (vault outputs + app support) + UserDefaults for preferences  
**Testing**: Swift Testing (preferred) + XCTest where necessary for integration  
**Target Platform**: macOS 14+  
**Project Type**: Native macOS app + Swift Package (MinuteCore)
**Performance Goals**: Responsive UI during recording; smooth timer/visualization updates; no UI-thread blocking during capture/processing  
**Constraints**: Local-only processing; deterministic note rendering; atomic vault writes; cancellable long-running tasks  
**Scale/Scope**: Single-user desktop app; refactor limited to “no selection” main area + recording controls

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

- Output contract unchanged or updated docs/tests included.
- Local-only processing preserved; no outbound network calls beyond model downloads.
- Deterministic Markdown rendering maintained for any note changes.
- MinuteCore tests added/updated for new behavior (renderer, file contracts, JSON validation).
- Pipeline state machine and cancellation support respected for long-running work.

**Gate evaluation (pre-design)**: PASS

- Output contract: unchanged (no path or renderer rule changes planned).
- Local-only: unchanged.
- Determinism: unchanged; any new “language processing” option must remain deterministic.
- Tests: required for new cancel-recording behavior + preference persistence and any core behavior.
- Pipeline/cancellation: new cancel behavior must fit the state machine.

## Project Structure

### Documentation (this feature)

```text
specs/[###-feature]/
├── plan.md              # This file (/speckit.plan command output)
├── research.md          # Phase 0 output (/speckit.plan command)
├── data-model.md        # Phase 1 output (/speckit.plan command)
├── quickstart.md        # Phase 1 output (/speckit.plan command)
├── contracts/           # Phase 1 output (/speckit.plan command)
└── tasks.md             # Phase 2 output (/speckit.tasks command - NOT created by /speckit.plan)
```

```text
specs/008-main-ui-refactor/
├── plan.md
├── research.md
├── data-model.md
├── quickstart.md
├── contracts/
│   └── openapi.yaml
└── checklists/
  └── requirements.md
```

### Source Code (repository root)
```text
Minute/                         # App target (SwiftUI UI + orchestration)
├── Sources/
│   ├── Views/                  # Stage + control bar UI (expected touchpoints)
│   ├── ViewModels/             # MeetingPipelineViewModel (expected touchpoint)
│   └── App/
└── Components/

MinuteCore/                     # Swift package (non-UI logic)
├── Sources/MinuteCore/
│   ├── Services/               # recording/import/summarization services
│   ├── Domain/                 # meeting types, pipeline context
│   └── Utilities/
└── Tests/                      # core tests (Swift Testing)

MinuteTests/                    # App-level tests
```

**Structure Decision**: Native macOS app (Minute) with core logic in MinuteCore; Stage refactor lives in Minute views/view-model wiring, and cancel-recording + new preferences live in MinuteCore-facing state/actions.

## Complexity Tracking

> **Fill ONLY if Constitution Check has violations that must be justified**

| Violation | Why Needed | Simpler Alternative Rejected Because |
|-----------|------------|-------------------------------------|
| [e.g., 4th project] | [current need] | [why 3 projects insufficient] |
| [e.g., Repository pattern] | [specific problem] | [why direct DB access insufficient] |

No constitution violations are expected for this feature.

## Phase 0 — Research (complete)

Outputs:
- [specs/008-main-ui-refactor/research.md](research.md)

Key resolutions:
- Located current recording UI and pipeline wiring.
- Confirmed Meeting Type exists and impacts prompts.
- Confirmed “Language Processing” needs a new persisted domain value.
- Confirmed import and screen-context selection touchpoints.

## Phase 1 — Design & Contracts (complete)

Outputs:
- [specs/008-main-ui-refactor/data-model.md](data-model.md)
- [specs/008-main-ui-refactor/contracts/openapi.yaml](contracts/openapi.yaml)
- [specs/008-main-ui-refactor/quickstart.md](quickstart.md)

Design notes:
- Add a persisted Stage preference bundle that includes Meeting Type and Language Processing.
- Introduce a cancel-recording action distinct from stop-recording.
- Keep selected-meeting detail behaviors unchanged.

**Constitution re-check (post-design)**: PASS

- Output contract: explicitly preserved; cancel-recording must ensure no vault outputs.
- Local-only + privacy: unchanged.
- Determinism: any language-processing setting must result in deterministic prompts/renderer inputs.
- Tests: plan requires new tests for cancel-recording and preference persistence.

## Phase 2 — Implementation Planning (next step)

Proceed with `/speckit.tasks` to generate a task breakdown for:
- UI refactor of Stage card + floating bottom bar
- Preference persistence wiring
- Cancel-recording action end-to-end and tests
