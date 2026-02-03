Minute Overview

Minute is a native macOS app for capturing meetings locally and writing
deterministic notes into a user-selected Obsidian vault. It records audio,
transcribes with Fluidaudio, summarizes with Llama, and writes a fixed set of
artifacts to the vault.

What the app does
- Record microphone + system audio locally.
- Transcribe audio locally (Fluidaudio).
- Optionally capture screen context locally for summaries.
- Summarize locally with a JSON-only LLM prompt (llama).
- Render a deterministic Markdown note from JSON.
- Write exactly three files to the vault per meeting.

Core output contract (v1)
The app always writes exactly three files for a processed meeting:
- Meetings/YYYY/MM/YYYY-MM-DD HH.MM - <Title>.md
- Meetings/_audio/YYYY-MM-DD HH.MM - <Title>.wav
- Meetings/_transcripts/YYYY-MM-DD HH.MM - <Title>.md

Audio format: mono, 16 kHz, 16-bit PCM WAV.

Note structure (deterministic)
- YAML frontmatter with fixed schema.
- Sections: Summary, Decisions, Action Items, Open Questions, Key Points.
- Links to the audio and transcript files in the vault.

How the app works (pipeline)
1) Record
   - Capture mic + system audio into temporary files.
   - Mix and convert to the contract WAV format.
2) Transcribe
   - Run Fluidaudio on the WAV file.
   - Write transcript markdown to Meetings/_transcripts/.
3) Summarize
   - Run llama with a JSON-only prompt.
   - Validate JSON; if invalid, run a single repair pass.
   - If still invalid, emit a fallback note with empty sections.
4) Render
   - Convert validated JSON to deterministic Markdown.
5) Write
   - Atomically write the note and audio into the vault.

State model
Single pipeline state machine:
idle -> recording -> recorded -> processing(transcribe) -> processing(summarize)
-> writing -> done | failed

Permissions and privacy
- The app is sandboxed and uses security-scoped bookmarks for the vault.
- All audio and inference runs locally.
- The only network access is for downloading model weights.
- No transcript content is logged by default.

Storage locations
- Vault: user-selected Obsidian vault root (files written only within this tree).
- Models: ~/Library/Application Support/Minute/models/
- App support: ~/Library/Application Support/Minute/

Technology snapshot
- UI: SwiftUI (macOS 14+)
- Audio: AVFoundation + ScreenCaptureKit
- Transcription: Fluidaudio (library, XPC helper)
- Summarization: llama (library)
- Markdown: deterministic renderer (model outputs JSON only)

Code structure
- Minute/ (app target, SwiftUI UI + app orchestration)
- MinuteCore/ (shared domain + services; non-UI logic)
- MinuteWhisperService/ (XPC helper for transcription)
- Vendor/ (bundled binaries like ffmpeg)
- scripts/ (release, notarization, appcast tooling)
- docs/ (product and release docs)

Architecture
UI stays thin; business logic lives in MinuteCore. The pipeline is a single
source-of-truth state machine. Models only emit JSON; Markdown is rendered
deterministically.

Core module boundaries (MinuteCore)
- Domain/types: schemas, file contracts, errors
- Services: audio, transcription, summarization, vault access, model management
- Rendering: deterministic Markdown renderer
- Utilities: validation + JSON repair

Service flow
UI -> MeetingPipelineViewModel -> services -> vault writer

Concurrency
- Long-running work uses async/await and supports cancellation.
- Only UI updates run on MainActor.

Non-goals (v1)
- Cloud transcription or summarization
- Non-deterministic note formatting
- Additional integrations beyond the Obsidian vault
