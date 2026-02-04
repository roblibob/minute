# Implementation Plan: Meeting Type Prompts

**Branch**: `003-meeting-type-prompts` | **Date**: 2026-02-04 | **Spec**: [specs/003-meeting-type-prompts/spec.md](specs/003-meeting-type-prompts/spec.md)
**Input**: Feature specification from `/specs/003-meeting-type-prompts/spec.md`

**Note**: This template is filled in by the `/speckit.plan` command. See `.specify/templates/commands/plan.md` for the execution workflow.

## Summary

Implement user-selectable meeting types (Presentation, Standup, etc.) that drive tailored AI prompts for summarization. The feature includes a UI picker (with Autodetect default), persistence in meeting metadata, and a backend strategy pattern for prompt generation. Autodetect functionality involves a two-pass classification system.

## Technical Context

<!--
  ACTION REQUIRED: Replace the content in this section with the technical details
  for the project. The structure here is presented in advisory capacity to guide
  the iteration process.
-->

**Language/Version**: Swift 5.9
**Primary Dependencies**: SwiftUI, Combine, AVFoundation, MinuteCore (Internal), Llama (Internal C++ wrapper)
**Storage**: JSON file-based metadata (Obsidian vault + internal app support)
**Testing**: XCTest (Unit & UI Tests)
**Target Platform**: macOS 14+
**Project Type**: Native macOS App
**Performance Goals**: Prompt generation < 10ms; Autodetect pass < 30s (depends on model speed)
**Constraints**: Local-only processing; Strict JSON schema adherence for output
**Scale/Scope**: ~6 new prompt templates, 1 new UI control, 1 data migration (optional, for default)

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

- Output contract unchanged or updated docs/tests included.
- Local-only processing preserved; no outbound network calls beyond model downloads.
- Deterministic Markdown rendering maintained for any note changes.
- MinuteCore tests added/updated for new behavior (renderer, file contracts, JSON validation).
- Pipeline state machine and cancellation support respected for long-running work.

## Project Structure

### Documentation (this feature)

```text
specs/003-meeting-type-prompts/
├── plan.md              # This file (/speckit.plan command output)
├── research.md          # Phase 0 output (/speckit.plan command)
├── data-model.md        # Phase 1 output (/speckit.plan command)
├── quickstart.md        # Phase 1 output (/speckit.plan command)
├── contracts/           # Phase 1 output (/speckit.plan command)
└── tasks.md             # Phase 2 output (/speckit.tasks command - NOT created by /speckit.plan)
```

### Source Code (repository root)

```text
Minute/
├── Sources/
│   ├── App/
│   ├── ViewModels/
│   │   └── RecorderViewModel.swift    # Update: Add meeting type state
│   └── Views/
│       └── RecorderView.swift         # Update: Add MeetingTypePicker
MinuteCore/
├── Sources/MinuteCore/
│   ├── Domain/
│   │   └── MeetingType.swift          # New: Enum definition
│   └── Summarization/
│       ├── Prompts/
│       │   ├── PromptStrategy.swift   # New: Protocol
│       │   ├── GeneralPrompt.swift    # New: Concrete strategy
│       │   ├── StandupPrompt.swift    # New: Concrete strategy
│       │   └── ...                    # New: Other strategies
│       └── SummarizationService.swift # Update: Use specific strategy
├── Tests/
│   └── MinuteCoreTests/
│       └── PromptTests.swift          # New: Test prompt generation
```

**Structure Decision**: Adopts the existing `Minute` (UI) and `MinuteCore` (Logic) separation. New prompt logic encapsulates specifically within `MinuteCore/Summarization/Prompts` to keep the main service clean.
