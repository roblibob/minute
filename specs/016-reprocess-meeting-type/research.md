# Research: Reprocess Meeting Type

**Feature Branch**: `016-reprocess-meeting-type`  
**Date**: 2026-03-20  
**Spec**: [spec.md](spec.md)

## Decision 1: Persist screen context inside the transcript artifact

**Decision**: Extend transcript rendering so screen context is written as explicit, timestamped `Screen Context` timeline entries inside the existing transcript markdown file.

**Rationale**:
- The spec makes the transcript the durable source for reprocessing.
- `PipelineContext` already carries `screenContextEvents`, but today those events are only fed into summarization and are not written durably.
- `TranscriptMarkdownRenderer` is the existing deterministic boundary for transcript output, so extending it preserves the current file contract and keeps note/transcript generation aligned.

**Alternatives considered**:
- Store screen context in a fourth vault file: rejected because it violates the three-file contract.
- Store screen context only in the meeting note: rejected because reprocessing depends on the transcript as the durable source and the note is the artifact being regenerated.
- Continue using screen context only as transient summarization input: rejected because reprocessing would lose contextual evidence after the original run.

## Decision 2: Implement reprocessing as a note-only orchestration path

**Decision**: Add a dedicated MinuteCore reprocessing path that reuses transcript parsing, prompt resolution, summarization, and note rendering, but writes only the meeting note.

**Rationale**:
- `MeetingPipelineCoordinator` already owns prompt resolution, summarization, deterministic note rendering, and vault writes.
- Reprocessing does not need transcription, WAV export, or transcript rewrite, so a smaller note-only path is both faster and safer than replaying the full pipeline.
- Keeping the orchestration in `MinuteCore` preserves thin UI boundaries and makes contract tests possible.

**Alternatives considered**:
- Re-run the full pipeline, including audio/transcript writes: rejected because the spec explicitly keeps transcript/audio unchanged and this adds unnecessary work.
- Implement reprocessing entirely in the app view model: rejected because it would duplicate business logic and weaken testability.
- Rewrite the transcript during reprocessing: rejected because the transcript is the durable source and must stay unchanged once used for regeneration.

## Decision 3: Preserve participant frontmatter during note regeneration

**Decision**: Load existing Minute-owned participant frontmatter from the current note and pass it back into the note renderer during reprocessing.

**Rationale**:
- Existing speaker naming already persists via owned frontmatter keys handled by `MeetingSpeakerNamingService`, `MeetingFrontmatterEditor`, and `YAMLFrontmatterCodec`.
- Reprocessing overwrites the note, so it must not silently discard speaker metadata that the app already owns.
- Reusing the existing frontmatter utilities avoids expanding scope into a generalized note parser.

**Alternatives considered**:
- Drop participant frontmatter on reprocess: rejected because it would regress existing user data.
- Parse and preserve arbitrary user-authored note sections semantically: rejected for this iteration because it adds a broad note-diff problem outside the feature scope.
- Move participant metadata into the transcript: rejected because current ownership and UI flows already depend on note frontmatter.

## Decision 4: Use a conservative overwrite confirmation gate for the managed note

**Decision**: Require explicit user confirmation before overwriting the existing managed note during reprocessing; do not add a save-as-new path in this feature.

**Rationale**:
- The clarified spec requires overwrite protection when edited notes are involved.
- The current codebase does not store a durable edit fingerprint or alternate-note artifact for safe copy creation.
- A confirmation gate protects user content without violating the three-file contract or adding a fourth artifact.

**Alternatives considered**:
- Save a copy as a new note before overwrite: rejected because the feature explicitly excludes creating additional vault notes.
- Block reprocessing whenever any note changes are present: rejected because it would make recovery too rigid for the primary user story.
- Add hidden hash metadata to detect exact edits in this feature: rejected because it changes the note contract and is not required to deliver the core recovery flow.
