Minute Overview

Minute is a native macOS app for capturing meetings locally and writing
deterministic notes into a user-selected Obsidian vault. It records audio,
transcribes with Fluidaudio, summarizes with local built-in or Ollama-backed
inference, and writes a fixed set of artifacts to the vault.

What the app does
- Record microphone + system audio locally.
- Transcribe audio locally (Fluidaudio).
- Optionally capture screen context locally for summaries.
- Let advanced users configure summarization and screen-context vision separately,
  with independent `Built-in` and `Ollama` provider/model choices.
- **Tailor summaries based on meeting type (built-in and custom).**
- Summarize locally with a JSON-only LLM prompt using the configured local provider.
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
- Speaker naming metadata (if the user edits it) is stored in the meeting note YAML frontmatter under app-owned keys:
   - `participants`: list of participant display names (strings)
   - `speaker_map`: mapping of speaker IDs to participant names
     - YAML keys are strings (e.g. `"1"`), but represent stable speaker IDs as integers.
   - `speaker_order`: optional list of speaker IDs used to display speakers in a stable order
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
   - Resolve the configured summarization provider/model for that run.
   - Run the built-in local model or the local Ollama daemon with a JSON-only prompt.
   - Validate JSON; if invalid, run a single repair pass.
   - If still invalid, emit a fallback note with empty sections.
   - Keep the resolved provider/model fixed for the lifetime of the in-flight task.
4) Render
   - Convert validated JSON to deterministic Markdown.
5) Write
   - Atomically write the note and audio into the vault.

Advanced inference configuration
- Summarization and screen-context vision are configured independently.
- Each capability can use `Built-in` or `Ollama`.
- Ollama discovery reflects models already downloaded to the configured Ollama daemon.
- Vision validation checks whether the selected Ollama model advertises `vision` capability.
- If a capability is unavailable, the app surfaces actionable readiness state instead of silently falling back.

State model
Single pipeline state machine:
idle -> recording -> recorded -> processing(transcribe) -> processing(summarize)
-> writing -> done | failed

Permissions and privacy
- The app is sandboxed and uses security-scoped bookmarks for the vault.
- All audio and inference runs locally.
- The only network access is for downloading model weights and, when enabled by the user, talking to the configured Ollama daemon endpoint.
- The default Ollama endpoint is loopback. Advanced users can point it at another user-managed Ollama host on their network.
- No transcript content is logged by default.
- Known-speaker profiles and diarization embeddings (when enabled) are stored in app support, not in the vault.
- The vault output contract remains exactly three files per meeting.
- Release builds are profile-driven: `app-store` disables updater behavior; `direct` keeps Sparkle updater/appcast behavior.

Storage locations
- Vault: user-selected Obsidian vault root (files written only within this tree).
- Models: ~/Library/Application Support/Minute/models/
- App support: ~/Library/Application Support/Minute/

Technology snapshot
- UI: SwiftUI (macOS 14+)
- Audio: AVFoundation + ScreenCaptureKit
- Transcription: Fluidaudio (library, XPC helper)
- Summarization: built-in llama runtime or local Ollama daemon
- Vision inference: built-in llama runtime or local Ollama daemon
- Markdown: deterministic renderer (model outputs JSON only)

Code structure
- Minute/ (app target, SwiftUI UI + app orchestration)
- MinuteCore/ (shared domain + services; non-UI logic)
- MinuteWhisperService/ (XPC helper for transcription)
- Vendor/ (bundled binaries like ffmpeg)
- scripts/ (release, notarization, appcast tooling)
- docs/ (product and release docs)

Meeting Types settings
- Users manage prompts in **Settings -> Meeting Types**.
- Built-in meeting types can be edited and restored to defaults.
- Users can create, rename, and delete custom meeting types.
- Custom meeting types can optionally participate in autodetect classification using classifier labels/signals.
- If a previously selected custom type is removed, processing is blocked until a valid replacement is selected.

Architecture
UI stays thin; business logic lives in MinuteCore. The pipeline is a single
source-of-truth state machine. Models only emit JSON; Markdown is rendered
deterministically.

Ownership highlights (013 simplification)
- Pipeline status presentation and defaults observation are isolated in
  `PipelineStatusPresenter` and `PipelineDefaultsObserver`.
- Shared model validation/download lifecycle is centralized in
  `ModelSetupLifecycleController`.
- Meeting-note parsing/transforms are centralized in
  `MinuteCore/Rendering/MeetingNoteParsing`.
- Vault path normalization is centralized in
  `MinuteCore/Vault/VaultPathNormalizer`.
- ScreenCaptureKit async wrappers are centralized in
  `MinuteCore/Services/ScreenCaptureKitAdapter`.

Core module boundaries (MinuteCore)
- Domain/types: schemas, file contracts, errors
- Services: audio, transcription, summarization, vision inference, vault access, model management, capability discovery/validation
- Rendering: deterministic Markdown renderer
- Utilities: validation + JSON repair

Service flow
UI -> MeetingPipelineViewModel -> services -> vault writer

Concurrency
- Long-running work uses async/await and supports cancellation.
- Only UI updates run on MainActor.

Non-goals (v1)
- Cloud transcription or summarization
- Remote hosted inference dependencies for summarization or screen-context vision
- Non-deterministic note formatting
- Additional integrations beyond the Obsidian vault
