# Implementation Plan: Speaker Diarization & Identification

**Branch**: `006-speaker-diarization` | **Date**: 2026-02-07 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification in [spec.md](spec.md)

## Summary

Improve diarization quality by switching meeting processing to FluidAudio’s offline VBx pipeline (`OfflineDiarizerManager`), improve far/quiet speaker representation by applying deterministic loudness normalization for analysis inputs only (2-pass `ffmpeg loudnorm`), and add subtle UI + deterministic persistence of per-meeting speaker naming in the meeting note YAML frontmatter (`participants`, `speaker_map`).

Optionally (opt-in, default OFF), introduce local-only known speaker suggestions via embedding similarity using embeddings sourced from the offline diarizer (exported only to the meeting working directory; never to the vault).

Add an explicit user-facing enrollment action (“Save as Known Speaker…”) so users can create/update known speaker profiles from a meeting’s diarized speaker, with a clear embedding availability policy (retain a small app-owned cache long enough for enrollment, or require reprocessing when unavailable).

## Technical Context

**Language/Version**: Swift 5.9+ (Xcode 15.x), macOS 14+.

**Primary Dependencies**:
- SwiftUI app in `Minute/`
- Core logic in `MinuteCore/` (SPM)
- FluidAudio (SPM) for ASR/diarization
- Bundled `ffmpeg` (in app bundle; also overridable via `MINUTE_FFMPEG_BIN`) invoked via `Process`

**Existing pipeline touchpoints (current)**:
- Pipeline orchestration: `MinuteCore/Sources/MinuteCore/Pipeline/MeetingPipelineCoordinator.swift`
- Diarization abstraction: `DiarizationServicing` (implemented by `FluidAudioDiarizationService` today)
- Transcript attribution: `MinuteCore/Sources/MinuteCore/Utilities/SpeakerAttribution.swift`
- Meeting note rendering: `MinuteCore/Sources/MinuteCore/Rendering/MarkdownRenderer.swift` (deterministic YAML frontmatter)
- Transcript file rendering: `MinuteCore/Sources/MinuteCore/Rendering/TranscriptMarkdownRenderer.swift`

**Audio preprocessing foundation (current)**:
- `MinuteCore/Sources/MinuteCore/Services/DefaultMediaImportService.swift` already invokes bundled `ffmpeg` and throws `MinuteError.ffmpegMissing` when unavailable.

**Storage**:
- Vault output: exactly three files per meeting (note/audio/transcript) with atomic writes.
- App-owned storage: local-only known speaker profiles (atomic JSON in Application Support). User-removable.

**Settings**:
- “Known speaker suggestions” is opt-in (default OFF), stored in app settings (not in vault files).

**Testing**:
- Swift Testing in `MinuteCore/Tests/MinuteCoreTests/`.
- Golden tests for deterministic meeting note rendering when frontmatter changes.
- Contract tests for output paths and filename sanitization.

**Performance/Cancellation**:
- Meeting processing is long-running; tasks must check cancellation and avoid blocking the UI.

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

- Output contract preserved: exactly 3 vault files per processed meeting, with fixed paths.
- Local-only processing preserved; no outbound network calls beyond model downloads.
- Deterministic Markdown/frontmatter rendering preserved (JSON-only model output is unchanged).
- MinuteCore tests required for any renderer/frontmatter changes and diarization ordering behavior.
- Pipeline remains cancellable and UI remains thin.

Gate status: PASS.

## Project Structure

### Documentation (this feature)

```text
specs/006-speaker-diarization/
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
Minute/                       # App (SwiftUI)
MinuteCore/                   # Core logic (SPM)
├── Sources/MinuteCore/
│   ├── Pipeline/
│   │   └── MeetingPipelineCoordinator.swift
│   ├── Services/
│   │   ├── FluidAudioDiarizationService.swift           # current (streaming) diarizer adapter
│   │   ├── FluidAudioTranscriptionService.swift
│   │   ├── DefaultMediaImportService.swift              # bundled ffmpeg invocation foundation
│   │   └── ProcessRunner.swift
│   ├── Rendering/
│   │   ├── MarkdownRenderer.swift
│   │   └── TranscriptMarkdownRenderer.swift
│   └── Utilities/
│       ├── SpeakerAttribution.swift
│       └── StringNormalizer.swift
└── Tests/MinuteCoreTests/     # Swift Testing
Vendor/ffmpeg/
```

**Structure Decision**: Keep UI thin in `Minute/` and implement diarization, loudness normalization, speaker naming persistence, and known-speaker matching in `MinuteCore/` behind clear interfaces.

## Complexity Tracking

No constitution violations are required for this feature.

## Phase 0 — Research (complete)

Outputs:
- [research.md](research.md)

Key findings (validated against the FluidAudio package sources used by this repo):
- Offline VBx pipeline exists and is callable via `OfflineDiarizerManager.process(_ url: URL)` after `prepareModels()`.
- Offline results include per-speaker embeddings in-memory (`DiarizationResult.speakerDatabase`) and optional embedding export JSON via `OfflineDiarizerConfig.embeddingExportPath`.
- `SpeakerManager` is streaming-only and not compatible with the offline VBx pipeline.
- Deterministic loudness normalization can be done with `ffmpeg loudnorm` 2-pass and pinned targets.

## Phase 1 — Design & Contracts

Outputs:
- [data-model.md](data-model.md)
- [contracts/openapi.yaml](contracts/openapi.yaml)
- [quickstart.md](quickstart.md)

Design decisions:

1) Diarization pipeline
- Switch meeting processing from streaming diarization (`DiarizerManager`) to offline VBx diarization (`OfflineDiarizerManager`) for higher batch accuracy.
- Bridge diarizer speaker IDs to MinuteCore speaker labels deterministically; speaker list ordering is defined by FR-002a.

2) Loudness normalization (analysis-only)
- Implement a deterministic analysis-preprocess step using bundled `ffmpeg` 2-pass `loudnorm`:
  - Pass 1 emits JSON stats.
  - Pass 2 applies `linear=true` using the measured values.
- This step produces a temporary analysis audio artifact and never modifies the vault WAV unless explicitly opted in (FR-003b).

3) Speaker naming + persistence
- Persist per-meeting `participants` and `speaker_map` ONLY in the meeting note YAML frontmatter (FR-007a).
- Do not automatically rewrite transcript file speaker headings; any transcript rewrite is an explicit user action (FR-007b).

4) Optional known-speaker suggestions (opt-in)
- Local-only profiles stored in Application Support JSON with atomic writes.
- When enabled, derive per-speaker embeddings from the offline diarizer and match deterministically via cosine similarity.

5) Known-speaker enrollment (explicit user action)
- Provide an in-meeting action to enroll a diarized speaker into a known speaker profile (create/update).
- Define embedding availability: enrollment uses a per-meeting aggregated embedding sourced from offline diarization output; if unavailable, require an explicit user recovery path (e.g., reprocess).
- Enrollment never writes to the vault automatically; applying any suggested mapping to meeting frontmatter is always user-driven and non-destructive.

## Phase 1 — Agent context update

Run `.specify/scripts/bash/update-agent-context.sh copilot` to refresh agent context after plan artifacts are updated.

## Constitution Check (post-design)

- Output contract: unchanged (3 files per meeting), plus explicit “no extra vault files” for speaker metadata.
- Local-only: preserved.
- Determinism: speaker map/frontmatter ordering and rendering will be locked by golden tests.
- Tests: MinuteCore tests will cover ordering, YAML/frontmatter serialization, and profile matching determinism.
- Cancellation: preprocessing + diarization + summarization remain cancellable.

Gate status: PASS to proceed to Phase 2 tasks and then implementation.
