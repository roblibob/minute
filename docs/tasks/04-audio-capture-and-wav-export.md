# 04 — Audio Capture and WAV Export

## Goal
Record microphone + system audio, produce a WAV file that matches the fixed v1 contract (mono, 16 kHz, 16-bit PCM), and copy it into the vault audio location.

Key constraint: the exported WAV must be deterministic and verifiable.

## Deliverables
- Microphone permission gating (macOS)
- Screen recording permission gating (macOS, required for system audio)
- `AudioService` that can:
  - Start recording to a temporary location
  - Stop recording and finalize a stable file
  - Export/convert to WAV mono 16 kHz 16-bit PCM
  - Return URLs + duration
- A format verification step that asserts the final WAV meets contract

## Microphone permission
- Add `NSMicrophoneUsageDescription` to Info.plist.
- Use `AVAudioSession` is iOS-only; on macOS use `AVCaptureDevice.requestAccess(for: .audio)`.
- Gate Start Recording until permission is granted.

## Screen recording permission (system audio)
- Use `ScreenCaptureKit` to capture system audio.
- Gate Start Recording until screen recording permission is granted (`CGPreflightScreenCaptureAccess` / `CGRequestScreenCaptureAccess`).

## Recording + conversion approach
Use AVFoundation for mic capture and ScreenCaptureKit for system audio, then prefer an `ffmpeg` conversion step to guarantee the WAV output contract across machines.

Rationale:
- Capture APIs vary by device and hardware sample rates.
- A deterministic conversion stage reduces “it works on my Mac” audio format drift.
- We still verify the output WAV format after conversion.

### Capture (AVFoundation + ScreenCaptureKit)
Record mic to a temporary file in a convenient capture format (e.g., CAF or WAV at native settings).
Record system audio to a separate temp file with ScreenCaptureKit.
Two viable approaches:

1) AVAudioEngine + tap → write to file
- Simple and low-level.

2) Record native, then convert (often simpler)
- Record using stable containers (e.g., CAF)
- Mix + convert on stop.

The plan recommends (2) for robustness: it isolates recording from conversion.

### Convert to contract WAV (preferred: ffmpeg)
Bundle `ffmpeg` and convert via `Process`:
- Input: temp recordings (mic + system), mixed to mono
- Output: WAV mono 16 kHz, 16-bit PCM

If AVFoundation-only conversion proves fully deterministic and always passes validation, `ffmpeg` can be disabled/removed later.

## File locations
- During recording: write into app temp directory (`FileManager.default.temporaryDirectory`) under a per-session subfolder.
- After stop/export:
  1. Determine vault destination URL: `Meetings/_audio/YYYY-MM-DD - <Title>.wav`
  2. Copy or move the exported WAV into the vault (atomic write patterns handled later)

In early implementation, the title may be unknown at stop time. Two strategies:
1. Record and export to temp with a placeholder name; move into final vault name after summarization returns title.
2. Use date + “Untitled” initially, then rename after summarization.

The plan recommends strategy 1: keep the final vault write late, after title is known.

## WAV contract verification
After export, open the file with `AVAudioFile(forReading:)` and validate:
- fileType: WAV
- sampleRate: 16000
- channelCount: 1
- commonFormat: `pcmFormatInt16`

If verification fails, treat as `audioExportFailed`.

## UX notes
- During recording, show elapsed time.
- Provide immediate feedback for permission denial.

## Exit criteria checklist
- [ ] Start/Stop records microphone + system audio
- [ ] Exported WAV validates as mono, 16 kHz, 16-bit PCM
- [ ] Recording lifecycle is stable across repeated runs
- [ ] Permission denied path is clear and recoverable
