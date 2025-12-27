# Media Import Solution Design

## Goal
Allow users to drop or choose an existing audio/video file in the main UI and run it through the same local pipeline (convert to contract WAV → transcribe → summarize → write to vault), without recording.

## Non-goals
- Live ingest while a file is still being written.
- Streaming transcription for long files.
- Remote or cloud processing of any kind.

## Constraints (from AGENT.md and docs)
- macOS 14+ native SwiftUI app.
- No outbound network calls except model downloads.
- Audio pipeline remains local and produces mono, 16 kHz, 16-bit PCM WAV.
- Summarization remains JSON-only with deterministic Markdown rendering.
- Pipeline must handle multilingual meetings (e.g., Swedish + English) without forcing translation.
- Errors should degrade gracefully; pipeline should fail cleanly with a concise message.

## Proposed Architecture
Add a media import path that produces the same `recorded` pipeline state as the recorder.

### Screen Context (Video Imports)
If the imported file contains video, optionally sample frames and run the same screen-context extraction pipeline used for live capture:
- Extract frames at low FPS (e.g., 0.5–1 fps) with change detection.
- Run OCR (Vision) and heuristics to produce a compact `ScreenContextSummary`.
- Feed the summary into the summarization prompt (text-only mode), keeping output JSON-only.
- Never store frames; only the aggregated text summary is retained in memory for summarization.
- Opt-in toggle for “Enhance notes with video frames.”

### New Service (MinuteCore)
`MediaImportService`
- Input: source file URL (audio or video).
- Output: `MediaImportResult` containing:
  - `wavURL` (contract WAV in temp)
  - `duration` (seconds)
  - `suggestedStartDate` (best-effort from file metadata, fallback to now)

Implementation details:
- Use `AVURLAsset` to probe tracks.
- If the asset has video tracks, export audio to `.m4a` using `AVAssetExportSession`.
- Convert the audio (source or extracted) to contract WAV via `AudioWavConverter`.
- Verify contract WAV with `ContractWavVerifier`.
- Use `AVMetadataItem` with `commonKey == .creationDate` for `suggestedStartDate`, fallback to file creation/modification date.

### Pipeline Integration (Minute)
- Add a pipeline action `.importFile(URL)` and a state `.importing`.
- When import starts:
  - Cancel any in-flight task.
  - Set state to `.importing`.
  - Run `MediaImportService.importMedia(from:)` in a task.
- On success:
  - Set state to `.recorded(audioTempURL, durationSeconds, startedAt, stoppedAt)` using the suggested start date.
- On failure:
  - Set state to `.failed` with a concise error.

### UI Integration (Minute)
- Add a drop zone to the main pipeline screen:
  - Accepts `.audio` and `.movie` files.
  - Visual highlight on hover.
  - Calls `.importFile(url)` when a valid URL is dropped.
- Add a “Choose File…” button using `fileImporter` with the same type filters.
- Keep recording controls available; import is an alternative entry point.

## Error Handling
- If the file has no audio track or export/conversion fails:
  - Surface `MinuteError.audioExportFailed` in the UI.
  - Provide debug details in the expandable debug section.
- If import is cancelled:
  - Return to `.idle`.

## Performance Considerations
- Export and conversion run off the UI thread in async tasks.
- Use temporary directories for intermediate files.
- Leave temp files in place for the pipeline to consume; cleanup can be added later.

## Testing Plan
- Unit tests:
  - `MediaImportService` with a small audio fixture.
  - Verify `ContractWavVerifier` still passes for imported files.
- Manual QA:
  - Drop an audio file → verify pipeline writes 3 artifacts.
  - Drop a video file → verify audio extraction + pipeline output.

## Risks and Mitigations
- Large file import can be slow: show “Importing” status and allow cancel.
- Unsupported codecs: fail fast with a clear error, continue to allow recording.

## Open Questions
- Should import be a separate mode (hide recording) or a parallel option?
- Should the import flow allow trimming or segment selection?
