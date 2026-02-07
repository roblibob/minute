# Quickstart — Speaker Diarization & Identification

**Feature**: [spec.md](spec.md)

## Goal
Improve diarization accuracy using FluidAudio’s offline pipeline, normalize loudness for analysis, and add a subtle UI + metadata schema for manual speaker naming, with optional local known-speaker suggestions.

## Repo entry points

- Meeting pipeline: `MinuteCore/Sources/MinuteCore/Pipeline/MeetingPipelineCoordinator.swift`
- Diarization service (offline VBx): `MinuteCore/Sources/MinuteCore/Services/FluidAudioOfflineDiarizationService.swift`
- Transcription service: `MinuteCore/Sources/MinuteCore/Services/FluidAudioTranscriptionService.swift`
- Audio conversion foundation (bundled ffmpeg): `MinuteCore/Sources/MinuteCore/Services/DefaultMediaImportService.swift`
- Meeting note rendering (frontmatter): `MinuteCore/Sources/MinuteCore/Rendering/MarkdownRenderer.swift`
- Transcript rendering: `MinuteCore/Sources/MinuteCore/Rendering/TranscriptMarkdownRenderer.swift`

Planned additions (this feature):
- Offline diarizer adapter (VBx): `MinuteCore/Sources/MinuteCore/Services/FluidAudioOfflineDiarizationService.swift`
- Analysis-only loudness normalization: `MinuteCore/Sources/MinuteCore/Services/AudioLoudnessNormalizer.swift`
- Speaker naming frontmatter types/store: `MinuteCore/Sources/MinuteCore/Domain/MeetingParticipantFrontmatter.swift`

## Development workflow

- Update plan artifacts live in `specs/006-speaker-diarization/`.
- Follow TDD per constitution: write Swift Testing tests first (MinuteCore), confirm red → implement → refactor.

## Suggested local commands

- Run package tests:
  - `cd MinuteCore && swift test`
- Run Xcode tests (if needed):
  - `xcodebuild -workspace Minute.xcworkspace -scheme MinuteCore -configuration Debug test -destination 'platform=macOS'`

## Manual QA checklist (future)

- Process a multi-speaker meeting twice; verify deterministic speaker segmentation and stable note rendering.
- Rename speakers; verify transcript labels and meeting note frontmatter update.
- Enable known-speaker suggestions; enroll a speaker; verify suggestion appears in a subsequent meeting.
- Confirm no extra files are written beyond the 3-file meeting contract.
