# Implementation Plan: Remove Live Transcription UI

**Branch**: `002-remove-live-transcription-ui` | **Date**: 2026-02-04 | **Spec**: [specs/002-remove-live-transcription-ui/spec.md](spec.md)
**Input**: Feature specification from `/specs/002-remove-live-transcription-ui/spec.md`

## Summary

Keep the recording UI clean by removing the non-functional "live transcription" text. This involves stripping the `liveTranscriptionLine` and ticker logic from `MeetingPipelineViewModel` and removing the `StreamingTranscriptView` and related text from `ContentView`.

## Technical Context

**Language/Version**: Swift 5.9 (Xcode 15.x)
**Primary Dependencies**: SwiftUI, Combine
**Storage**: N/A (UI cleanup)
**Testing**: Manual verification, Unit tests (compilation check)
**Target Platform**: macOS 14+
**Project Type**: Native macOS App

## Constitution Check

- Output contract unchanged.
- Local-only processing preserved (actually improved by removing a fake process).
- Deterministic Markdown rendering maintained.
- Core logic tests: This is a UI/ViewModel cleanup; existing tests should pass, though we might need to remove any tests covering this fake functionality if they exist (unlikely given it's "show only").
- Pipeline state machine respected.

## Project Structure

### Documentation (this feature)

```text
specs/002-remove-live-transcription-ui/
├── plan.md
├── spec.md
├── research.md (N/A - simple cleanup)
└── tasks.md
```

### Source Code

```text
Minute/
├── ContentView.swift  # UI component to clean up
└── Pipeline/
    └── MeetingPipelineViewModel.swift # ViewModel to clean up
```

## Complexity Tracking
None. This cuts code, reducing complexity.
