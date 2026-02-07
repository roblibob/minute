# Research — Speaker Diarization & Identification

**Feature**: [spec.md](spec.md)
**Date**: 2026-02-07

This document resolves planning unknowns and records key technical decisions.

## Decision: Use FluidAudio offline diarization for post-meeting processing

- Decision: Use `OfflineDiarizerManager` for meeting (batch) diarization.
- Rationale:
  - Highest accuracy offline pipeline (powerset segmentation + VBx clustering).
  - API supports file-based processing (`process(url)`) and model preparation (`prepareModels()`).
  - Aligns with app constraints: meetings are processed after recording (not real-time).
- Alternatives considered:
  - Keep current `DiarizerManager.performCompleteDiarization(samples)` (streaming pipeline): simpler, but lower accuracy for batch use and more sensitive to parameter tuning.

## Decision: Speaker identification across meetings cannot rely on SpeakerManager + OfflineDiarizerManager

- Fact (from FluidAudio docs): `SpeakerManager` is compatible with `DiarizerManager` (streaming) only. `OfflineDiarizerManager` uses VBx clustering.
- Decision: Split “speaker identification” into two tiers:
  1) **Per-meeting naming**: always supported via manual naming and persisted mapping.
  2) **Cross-meeting suggestions** (optional): implemented via a local speaker profile store and embedding-based matching, without requiring `SpeakerManager`.
- Rationale:
  - Meets user value immediately (manual naming) even if automatic identification needs iteration.
  - Keeps the offline pipeline as the diarization source of truth for segments.
- Alternatives considered:
  - Switch back to streaming pipeline to use `SpeakerManager`: would forfeit offline VBx quality.
  - Run both pipelines: offline for segments, streaming for identity propagation. This increases runtime and complexity and should be gated behind user preference if adopted.

## Decision: How to obtain embeddings for cross-meeting matching

- Decision: When “Known speaker suggestions” is enabled, source embeddings from the offline diarization pipeline and (only then) enable offline embedding export to the meeting working directory (temporary, non-vault) for deterministic ingestion.
- Rationale:
  - FluidAudio’s offline pipeline produces 256-d L2-normalized embeddings and exposes them in-memory via `DiarizationResult.speakerDatabase`.
  - The offline manager can also export per-embedding payloads to a JSON file when `OfflineDiarizerConfig.embeddingExportPath` is set, and the exported schema is stable and easy to parse.
  - Matching can be performed deterministically via cosine similarity with deterministic aggregation rules.
- Export schema (offline embedding JSON):
  - JSON array; each element includes: `chunkIndex`, `speakerIndex`, `startFrame`, `endFrame`, `startTime`, `endTime`, `embedding256` (Float[256]), `rho128` (Double[128]), `cluster` (Int).
  - `cluster` is the offline cluster assignment (0-based) and is sufficient to group embeddings per speaker.
- Alternatives considered:
  - Use only in-memory `speakerDatabase` without exporting JSON: simpler and faster, but does not match the clarified “export to working directory” requirement.
  - Run a separate embedding extractor: unnecessary duplication given offline pipeline already extracts embeddings.

## Decision: Loudness normalization for analysis audio (not vault audio)

- Decision: Normalize loudness for **analysis inputs** (diarization/transcription) without changing the archived vault WAV file.
- Rationale:
  - Preserves the audio contract (vault WAV remains canonical) while improving far-speaker detection.
  - Allows safe iteration on normalization strategy.
- Preferred approach (pinned 2-pass `ffmpeg loudnorm`):
  - Pass 1 (measure):
    - `loudnorm=I=-16:TP=-1.5:LRA=11:print_format=json`
    - Capture stderr and extract the loudnorm JSON block.
  - Pass 2 (apply linear):
    - `loudnorm=I=-16:TP=-1.5:LRA=11:linear=true:measured_I=...:measured_TP=...:measured_LRA=...:measured_thresh=...:offset=...`
    - Use the measured fields from pass-1 JSON.
  - Determinism knobs for stable outputs:
    - Force single-threaded processing: `-threads 1 -filter_threads 1 -filter_complex_threads 1`
    - Disable interactive input/log noise: `-nostdin -hide_banner -nostats`
    - Explicitly control resample/format when writing a temp WAV: append `aresample=16000:resampler=soxr:precision=20:dither_method=none,aformat=sample_fmts=s16:channel_layouts=mono`
- Alternatives considered:
  - Modify the vault WAV: violates expectations and complicates reproducibility.

## Decision: Local-only speaker profile persistence

- Decision: Persist a small local database of known speaker profiles (name + 256-d embedding + metadata) in app-owned storage.
- Rationale:
  - Enables suggestions for known speakers while remaining private and removable.
  - Avoids outbound networking and avoids external accounts.
- Alternatives considered:
  - Core Data / SQLite: likely unnecessary initially (data size is tiny). Start with an atomic JSON file and upgrade later if needed.

## Decision: Meeting participant metadata format

- Decision: Store participant info in the meeting note frontmatter, with a stable schema that supports:
  - `participants`: list of participant names
  - `speaker_map`: mapping from diarization `speakerId` to participant name (or participant ID)
- Rationale:
  - Obsidian-friendly: users can inspect and edit.
  - Deterministic rendering: frontmatter generation can be a pure function of (meeting id + mapping + participants).

## UX Research: Subtle speaker naming affordance

- Decision: Provide an inline/secondary UI affordance (e.g., a compact “Speakers” button or popover) in the meeting viewer.
- Rationale:
  - Keeps meeting reading experience uncluttered.
  - Still discoverable for users who want to name speakers.

## Risks

- Offline/streaming identity mismatch: if both pipelines are used, speaker IDs may not align. Any hybrid approach must define a stable canonical mapping.
- Embedding versioning: changes in embedding model/version may degrade matching; the store needs version metadata and “re-enroll” UX.
- Determinism: any note/frontmatter updates must be deterministic and covered by golden tests.

## Additional Clarified Defaults

- “Known speaker suggestions” is opt-in and disabled by default (stored in app settings, not in vault).
- Any ordering of `participants` / `speaker_map` output must follow the deterministic ordering rule captured in the spec (FR-002a).
