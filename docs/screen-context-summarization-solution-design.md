# Screen-Context Summarization Solution Design

## Goal
Enhance meeting minutes with useful information derived from the user-selected screen content (e.g., agenda, participant count, shared document titles), while keeping all processing local and non-intrusive.

## Non-goals
- Do not record or store full meeting video.
- Do not capture content outside user-selected apps/windows.
- Do not change the vault output contract (still exactly three files).
- Do not make any outbound network calls beyond model downloads.

## Constraints (from AGENTS.md and docs/overview.md)
- macOS 14+ native SwiftUI app.
- Local-only processing (Whisper + Llama).
- Deterministic Markdown rendering from JSON-only summaries.
- UI remains thin; logic lives in MinuteCore where practical.
- Every long-running operation must be cancellable.

## Proposed Approach
Add a lightweight, opt-in “screen context” pipeline that samples the content of selected windows, extracts structured cues, and feeds them into summarization as supplemental context.

High-level flow:
1. User selects specific windows (e.g., Teams meeting window, Slack huddle).
2. During recording, sample frames at low frequency and detect changes.
3. Extract text and cues from frames (OCR + heuristics).
4. Normalize into a small JSON context payload.
5. Provide that payload to the summarizer (as text or multimodal input when supported).
6. Renderer remains unchanged; it consumes the same JSON schema as today.

## Why This Works
- Adds agenda/participants cues without storing video.
- Keeps privacy risk low by extracting and storing only text snippets and aggregates.
- Works even with non-multimodal models by converting screen context to structured text.

## Data Model (MinuteCore)
```
struct ScreenContextSnapshot: Sendable {
    var capturedAt: Date
    var windowID: CGWindowID
    var windowTitle: String
    var extractedText: String
}

struct ScreenContextSummary: Sendable {
    var agendaItems: [String]
    var participantCount: Int?
    var participantNames: [String]
    var sharedArtifacts: [String]
    var keyHeadings: [String]
    var notes: [String]
}
```

Notes:
- `ScreenContextSnapshot` is transient; only the aggregated `ScreenContextSummary` is kept for summarization.
- All fields remain best-effort and optional.

## New Services (MinuteCore)
### ScreenContextCaptureService
- Uses `ScreenCaptureKit` with `SCContentFilter` scoped to selected windows/apps.
- Captures frames at low FPS (e.g., 0.5–1 fps) with change detection to skip similar frames.
- Always cancelable.

### ScreenContextExtractionService
- Runs OCR via `Vision` (`VNRecognizeTextRequest`) on sampled frames.
- Extracts window title + visible headings (font size heuristics when available).
- Produces `ScreenContextSnapshot` entries.

### ScreenContextAggregationService
- Aggregates snapshots into `ScreenContextSummary`.
- Heuristics:
  - Agenda: heading-like lines repeated or ordered.
  - Participants: "Participants (N)" or list-like lines near "Participants" headings.
  - Shared artifacts: lines with file extensions or document-like titles.
- Redaction pass (email/phone patterns) before summarization.

### Summarization Integration
Two modes, chosen by model capability:
1. **Text-only (default)**: Convert `ScreenContextSummary` into a short “context appendix” string and add it to the prompt (still JSON-only output).
2. **Multimodal (future)**: Pass representative frames + `ScreenContextSummary` to a multimodal summarizer; still require JSON-only output.

## Pipeline Integration
Add a parallel path that runs alongside recording:
- `recording` state spawns `ScreenContextCaptureService`.
- On stop, finalize aggregation and attach `ScreenContextSummary` to the summarization request.
- If capture fails or is disabled, summarization proceeds normally.

## UI / UX
- Optional toggle: “Enhance notes with selected screen content.”
- Window selection sheet using `SCShareableContent` (list of windows/apps).
- Clear disclosure: “Only extracted text is used. No video is stored.”
- Visual hint when selected windows disappear or become protected.

## Privacy and Security
- Opt-in only; default off.
- Scope strictly to selected windows using `SCContentFilter`.
- Never write snapshots or raw OCR output to disk.
- No raw OCR text logging; use `OSLog` for high-level events only.

## Error Handling
- Fail open: if screen context fails, continue with audio-only summarization.
- Map OS/framework errors to `MinuteError.screenContextFailed` (concise UI message).

## Testing Plan
### Unit tests (MinuteCore)
- Aggregation heuristics (agenda detection, participant count parsing).
- Redaction pass for sensitive patterns.
- Prompt composition includes or excludes screen context cleanly.

### Integration tests (recommended)
- Mock `ScreenContextCaptureService` to simulate snapshots.
- Verify summarization service receives correct context payload.

### Manual QA
- Select Teams window → verify agenda/participants appear when visible.
- Select Slack huddle → verify shared doc names captured.
- Disable feature → no screen context in summaries.

## Risks and Mitigations
- OCR noise: keep context short, dedupe, and use heuristics.
- High CPU: low FPS + change detection + throttling.
- Protected content: show warning; do not attempt capture.
- Privacy concerns: clear opt-in and local-only processing; no raw logging.

## Open Questions
- Should screen context be shown in the UI debug panel?
- What is the minimal and safe “context appendix” format for the prompt?
- Do we need per-app templates (Teams vs Slack) for better heuristics?
