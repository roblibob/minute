# Implementation Plan: Reprocess Meeting Type

**Branch**: `016-reprocess-meeting-type` | **Date**: 2026-03-20 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `/specs/016-reprocess-meeting-type/spec.md`

**Note**: This template is filled in by the `/speckit.plan` command. See `.specify/templates/commands/plan.md` for the execution workflow.

## Summary

Add an explicit recovery flow that lets users reprocess an already processed meeting to a different explicit meeting type using the saved transcript as the durable source. Persist screen context into the transcript as clearly labeled timeline entries, then reuse the existing summarization and deterministic note-rendering path to regenerate only the meeting note while keeping the transcript and audio artifacts unchanged.

## Technical Context

**Language/Version**: Swift 6.2 tools for `MinuteCore`; Swift/SwiftUI macOS app target on Xcode 15.x conventions  
**Primary Dependencies**: SwiftUI, Combine, `MinuteCore`, `MinuteLlama`, FluidAudio, AVFoundation, ScreenCaptureKit  
**Storage**: Local vault files (meeting note/audio/transcript), temporary processing artifacts, security-scoped bookmarks and settings in `UserDefaults`  
**Testing**: Swift Testing in `MinuteCore/Tests/MinuteCoreTests` plus app-facing tests in `MinuteTests`  
**Target Platform**: macOS 14+ (Apple Silicon focus)
**Project Type**: Native macOS app (`Minute/`) with core business logic in Swift Package (`MinuteCore/`)  
**Performance Goals**: Reprocess availability checks should complete immediately from local metadata; reprocessing should skip retranscription/audio export and stay materially faster than full processing; transcript rendering with screen context must remain deterministic  
**Constraints**: Preserve the exact three-file vault contract; local-only processing only; transcript/audio MUST remain unchanged during reprocess; Autodetect cannot be a reprocess target; edited-note overwrite must require explicit confirmation; long-running work remains cancellable  
**Scale/Scope**: Single-user desktop workflow scoped to processed-meeting browsing, transcript rendering/parsing, and note-only regeneration for one meeting at a time

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

- Output contract unchanged or updated docs/tests included. ✅ Unchanged three-file contract; plan updates docs/spec artifacts and adds contract-oriented tests.
- Local-only processing preserved; no outbound network calls beyond model downloads. ✅ Preserved; all reprocessing uses local transcript and local summarization.
- Deterministic Markdown rendering maintained for any note changes. ✅ Preserved; note and transcript remain renderer-driven.
- MinuteCore tests added/updated for new behavior (renderer, file contracts, JSON validation). ✅ Planned for transcript rendering/parsing, reprocess orchestration, and note overwrite behavior.
- Pipeline state machine and cancellation support respected for long-running work. ✅ Planned; reprocessing routes through MinuteCore orchestration with cancellation.

**Gate Status**: PASS (no justified violations)

## Project Structure

### Documentation (this feature)

```text
specs/016-reprocess-meeting-type/
├── plan.md
├── research.md
├── data-model.md
├── quickstart.md
├── contracts/
│   └── openapi.yaml
└── tasks.md
```

### Source Code (repository root)

```text
Minute/
└── Sources/
    ├── ViewModels/
    │   └── MeetingPipelineViewModel.swift
    └── Views/
        └── MeetingNotes/
            └── MeetingNotesBrowserViewModel.swift

MinuteCore/
├── Sources/
│   ├── MinuteCore/
│   │   ├── Domain/
│   │   │   ├── MeetingExtraction.swift
│   │   │   └── ScreenContext.swift
│   │   ├── Pipeline/
│   │   │   ├── MeetingPipelineCoordinator.swift
│   │   │   └── PipelineTypes.swift
│   │   ├── Rendering/
│   │   │   ├── MarkdownRenderer.swift
│   │   │   ├── MeetingNoteParsing.swift
│   │   │   ├── TranscriptMarkdownRenderer.swift
│   │   │   └── YAMLFrontmatterCodec.swift
│   │   └── Services/
│   │       ├── MeetingSpeakerNamingService.swift
│   │       ├── ResolvedPromptBundleResolver.swift
│   │       └── VaultMeetingNotesBrowser.swift
│   └── MinuteLlama/
│       └── Services/
│           └── LlamaLibrarySummarizationService.swift
└── Tests/
    └── MinuteCoreTests/
        ├── TranscriptMarkdownRendererTests.swift
        ├── VaultMeetingNotesBrowserTests.swift
        └── [new reprocessing + transcript timeline tests]

MinuteTests/
└── [new meeting notes browser reprocessing tests]
```

**Structure Decision**: Keep business logic in `MinuteCore` and use the existing meeting-notes browser in `Minute/` as the user-facing trigger. Rendering, transcript parsing, and orchestration changes stay in `MinuteCore`; UI validation and confirmation state stay in `MeetingNotesBrowserViewModel`.

## Phase 0 — Research (completed)

See [research.md](research.md).

Key conclusions:
- Persist screen context inside the transcript artifact as explicit, labeled timeline entries so the transcript becomes the durable reprocess source.
- Implement reprocessing as a note-only orchestration path that reuses summarization and deterministic note rendering while leaving transcript/audio untouched.
- Reuse existing frontmatter/speaker utilities so reprocessing preserves app-owned participant metadata rather than discarding it.
- Use a conservative overwrite confirmation gate before rewriting an existing managed note rather than introducing a save-as-new path or a fourth artifact.

## Phase 1 — Design & Contracts (completed)

- Data model: [data-model.md](data-model.md)
- Internal contracts: [contracts/openapi.yaml](contracts/openapi.yaml)
- Validation and QA flow: [quickstart.md](quickstart.md)

## Phase 2 — Implementation Plan

### 1) Persist screen context in the transcript artifact

- Extend `TranscriptMarkdownRenderer` to render screen context as a first-class timeline entry with a distinct label such as `Screen Context` and deterministic ordering.
- Extend `MeetingPipelineCoordinator.writeOutputsToVault(...)` to pass `context.screenContextEvents` into the transcript renderer.
- Keep transcript frontmatter stable and deterministic while interleaving speaker segments and screen context events chronologically.

### 2) Add transcript timeline parsing utilities

- Extend `MeetingNoteParsing` with helpers to parse transcript timeline entries, including both speaker segments and screen context entries.
- Preserve existing speaker-heading parsing behavior for the transcript viewer while adding screen context extraction for reprocessing.
- Ensure parsing tolerates transcripts without screen context and ignores malformed screen context entries safely.

### 3) Introduce a note-only reprocessing orchestration path in MinuteCore

- Add an explicit `ReprocessMeetingRequest` internal contract in `PipelineTypes` (or adjacent reprocessing types) with note URL, transcript URL, current type, target explicit type, and overwrite confirmation state.
- Add a coordinator entry point that:
  - loads the saved transcript artifact,
  - reconstructs the summarization source text from transcript timeline entries,
  - resolves the prompt bundle for the explicit target meeting type,
  - reuses the existing summarization + deterministic note rendering path,
  - writes only the note atomically.
- Preserve transcript/audio URLs and the existing file paths when regenerating the meeting note.

### 4) Preserve note metadata and overwrite safety

- Load existing app-owned participant frontmatter from the current note before re-rendering so speaker metadata survives reprocessing.
- Route edited-note protection through an explicit overwrite confirmation step in the meeting-notes flow before the coordinator writes a replacement note.
- Do not introduce a save-as-new behavior or any additional vault artifact in this feature.

### 5) Add meeting-notes browser reprocess UX state

- Extend `MeetingNotesBrowserViewModel` with:
  - reprocess availability checks based on transcript presence and current meeting type,
  - explicit target type selection that excludes `Autodetect`,
  - overwrite/cancel confirmation state,
  - progress/error surface for the reprocess action.
- Add the user-facing reprocess entry points in the existing meeting action surfaces:
  - the row `contextMenu` in `MeetingNotesSidebarView`
  - the existing meatball `Menu` in `MarkdownViewerOverlay`
- Keep `Resummarize as…` colocated with the existing `Reveal in Finder` and `Delete` actions, with disabled state driven by the same view-model availability checks.
- Keep the UI thin by delegating note regeneration and transcript parsing to `MinuteCore`.

### 6) Test plan (TDD, contract-first)

- Add `MinuteCore` tests for transcript timeline rendering/parsing with screen context entries.
- Add `MinuteCore` orchestration tests for note-only reprocessing, explicit type enforcement, cancellation, and unchanged transcript/audio artifacts.
- Add `MinuteCore` contract/file tests ensuring reprocessing preserves the three-file contract and atomic note writes.
- Add `MinuteTests` coverage for meeting-notes browser validation, transcript-required blocking, explicit-type selection, and overwrite confirmation behavior.

## Post-Design Constitution Re-check

- Output contract: unchanged; reprocessing rewrites only the managed note while transcript/audio remain stable ✅
- Local-only and privacy: preserved; no new network behavior and no raw transcript logging requirement introduced ✅
- Determinism: transcript entries and note regeneration remain renderer/parser-driven with stable ordering ✅
- Test-gated core logic: plan adds `MinuteCore` tests for transcript timeline + note-only reprocessing and app tests for browser validation ✅
- State machine/cancellation: reprocessing is an explicit long-running action routed through existing cancellable orchestration paths ✅

## Complexity Tracking

No constitution violations are required for this feature.

