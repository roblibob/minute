# Speaker Diarization Solution Design

## Goal
Detect multiple speakers in a meeting recording and label the transcript with speaker turns, while keeping the pipeline offline and deterministic.

## Non-goals
- Identify real people or persist speaker identities across meetings.
- Live/streaming diarization during recording.
- Any cloud or network-based processing.

## Constraints (from AGENT.md and docs)
- macOS 14+ native app.
- No outbound network calls except model downloads.
- Audio pipeline remains local and produces mono, 16 kHz, 16-bit PCM WAV.
- Summarization remains JSON-only and deterministic at the renderer boundary.
- Errors should degrade gracefully; pipeline must not fail when diarization fails.

## Proposed Architecture
Add a diarization stage that runs locally on the same WAV file used for whisper transcription.

### New Services
- `DiarizationService` (MinuteCore)
  - Input: WAV URL
  - Output: `DiarizationResult` (speaker segments with timestamps)
- `SpeakerAlignmentService` (MinuteCore)
  - Input: whisper segments + diarization segments
  - Output: `AttributedTranscript` with speaker labels

### New Types
```
SpeakerSegment
- startSeconds: Double
- endSeconds: Double
- speakerId: Int

DiarizationResult
- segments: [SpeakerSegment]
- speakerCount: Int

AttributedTranscriptSegment
- startSeconds: Double
- endSeconds: Double
- speakerId: Int
- text: String
```

### Pipeline Integration
1. Record and convert to WAV as today (mono 16 kHz).
2. Run diarization (can run concurrently with whisper to reduce total time).
3. Run whisper transcription (already provides timestamps).
4. Align speaker segments to whisper segments by time overlap.
5. Render transcript Markdown with speaker labels.
6. Summarization uses the labeled transcript (optional), but JSON contract remains unchanged.

### Alignment Strategy
- For each whisper segment, compute overlap with diarization segments.
- Choose the speaker with max overlap (fallback to most recent speaker if overlap is ambiguous).
- Merge adjacent segments with the same speaker to avoid label spam.
- If diarization fails, return a single speaker (Speaker 1) and proceed.

## Model Approach
### Implemented (FluidAudio)
- Use FluidAudio’s Core ML pipeline (`DiarizerManager` + `DiarizerModels`).
- Models are downloaded on first use via `DiarizerModels.downloadIfNeeded()` and cached under:
  - `~/Library/Application Support/FluidAudio/Models/speaker-diarization-coreml/`
- The `FluidAudioDiarizationService` converts the WAV to 16 kHz mono Float32 via `AudioConverter`, runs diarization, and maps segments into `SpeakerSegment` for alignment.

### Fallback (if models unavailable)
- Return no diarization segments and continue with a plain transcript.
- Summarization and note rendering remain unchanged; only transcript speaker labels are omitted.

## Transcript Rendering
- Keep the existing transcript file location and deterministic rendering rules.
- Add speaker labels and timestamps to the transcript Markdown, for example:
```
Speaker 1 [00:12 - 00:21]
We should stick to laminate unless the cutout is far enough from the edge.

Speaker 2 [00:21 - 00:30]
Agreed. The fact sheet is strict about that.
```
- The note Markdown stays unchanged; only the transcript file gains labels.

## Error Handling
- New error: `MinuteError.diarizationFailed` (internal only).
- If diarization fails or times out:
  - Log error via `OSLog`.
  - Use a single speaker label and continue the pipeline.

## Performance Considerations
- Run diarization and transcription in parallel where possible.
- Cap max speakers (e.g., 2-6) for speed and stability.
- Use cancellation checks during model inference.

## Testing Plan
- Unit tests:
  - Alignment logic on fixed timestamp fixtures.
  - Transcript rendering with speaker labels.
- Integration tests:
  - Mock diarization output to verify pipeline behavior.
- Manual QA:
  - Verify labels remain stable for known sample audio.

## Risks and Mitigations
- Model size and memory pressure: keep models small and allow optional download.
- Diarization accuracy varies with crosstalk: expose a toggle to disable.
- License restrictions: pick models with permissive licenses and document them.

## Open Questions
- Which diarization model can be reliably converted to CoreML for macOS?
- Do we want speaker labels in the note body (not just transcript)?
- Should diarization be opt-in or enabled by default?
