# Source-Aware Diarization Solution Design

## Goal
Use the known separation between microphone and system audio to improve speaker attribution without adding new files or changing the output contract.

## Non-goals
- Do not change the vault output contract or note format.
- Do not add new files to the vault.
- Do not perform any outbound network calls.
- Do not log raw transcript content.

## Constraints (from AGENTS.md and docs/overview.md)
- macOS 14+ native app (SwiftUI).
- Audio is recorded locally; Whisper + Llama run locally.
- Exactly three files are written per meeting.
- WAV format is mono, 16 kHz, 16-bit PCM.
- UI stays thin; business logic lives in MinuteCore when practical.

## Proposed Approach
Treat the microphone and system audio tracks as known speaker sources and build speaker segments from each track before attribution.

High-level flow:
1. Capture mic and system audio as separate streams.
2. Derive speech segments per stream (VAD or energy threshold).
3. Label segments with fixed speaker identities:
   - "Local" = microphone
   - "Remote" = system audio
4. Merge segments and attribute transcript segments with the known labels.
5. Run diarization inside each track to split "Remote" into multiple speakers.

## Pipeline Changes
Current pipeline:
- Record -> mix -> transcribe -> diarize -> attribute -> summarize -> write

Proposed:
- Record -> keep separate streams -> mix -> transcribe (on mixed WAV) -> source-aware segmentation -> attribute -> summarize -> write

Notes:
- Mixed WAV remains the single audio artifact written to the vault.
- Source-aware diarization is used only to label transcript segments.

## MinuteCore Changes
### New Types
```
enum AudioSource: String, Sendable {
    case microphone
    case system
}

struct SourceSpeechSegment: Sendable {
    var source: AudioSource
    var start: TimeInterval
    var end: TimeInterval
}
```

### New Services
- `SourceAudioSegmentationServicing`
  - Inputs: mic WAV URL, system WAV URL
  - Output: `[SourceSpeechSegment]`
  - Implementation: lightweight VAD or energy threshold with smoothing.

- `SourceAwareDiarizationService` (MinuteCore)
  - Inputs: `TranscriptionResult`, `[SourceSpeechSegment]`
  - Output: `[AttributedTranscriptSegment]`
  - Merges segments and assigns "Local"/"Remote" labels.

### Integration Points
- `MeetingPipelineViewModel`
  - Keep references to mic/system temporary URLs during capture.
  - After transcription, call the source segmentation service and use the output to attribute segments.
  - Fall back to existing diarization if segmentation fails.

## Algorithm Outline
1. Run VAD per track to produce speech intervals.
2. Normalize and merge adjacent intervals within a small gap (e.g., 200 ms).
3. Label intervals by `AudioSource`.
4. Map transcript segments to the nearest overlapping source interval.
5. If multiple sources overlap, choose the one with higher energy or mark as "Overlap".

Optional extension:
- If a diarization model is available, run it only on the system track to split "Remote" into multiple speakers while keeping "Local" fixed.

## Error Handling
- If segmentation fails, fall back to existing diarization or return unlabeled segments.
- Map low-level errors to `MinuteError` at service boundaries.
- Keep user-visible errors concise; log details with `OSLog`.

## Logging and Privacy
- Use `OSLog` for events and durations.
- Never log raw transcript content or audio samples.

## Testing Plan
### Unit tests (MinuteCore)
- Segment merging logic (gap smoothing).
- Attribution logic with overlapping segments.
- Fallback behavior when segmentation fails.

### Integration tests (recommended)
- Mock segmentation service to verify that "Local"/"Remote" labels flow into transcript attribution.

### Manual QA
- Record a meeting with only mic speech: all transcript segments labeled "Local".
- Record system-only speech (screen share playback): labeled "Remote".
- Overlap: verify expected label selection or overlap handling.

## Risks and Mitigations
- Crosstalk between mic/system audio: use energy gating and overlap rules.
- VAD sensitivity: provide conservative thresholds and smoothing.
- Different capture latency between tracks: align using known capture start timestamps.

## Open Questions
- Should we display "Local"/"Remote" labels in the UI, or keep them transcript-only? 
  - Answer: Keep transcript-only.
- Do we want a user-facing toggle to enable/disable source-aware diarization?
  - Answer: No, as it would complicate the UI and add unnecessary complexity for most users.
