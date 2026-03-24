# Minute — transcription and summarization companion app for obsidian
This is a meeting note summarization app tailored to the user need for 
private and local inference.

## Constitution

### Deterministic Output Contract
Preserve the vault contract: exactly three files per processed meeting.
  - `Meetings/YYYY/MM/YYYY-MM-DD HH.MM - <Title>.md`
  - `Meetings/_audio/YYYY-MM-DD HH.MM - <Title>.wav`
  - `Meetings/_transcripts/YYYY-MM-DD HH.MM - <Title>.md`
WAV output must remain mono, 16 kHz, 16-bit PCM.
Models output JSON, the app renders Markdown, and vault writes are atomic.

### Local-Only Processing and Privacy
Minute is a local first app. Models run locally. 
  - No outbound network calls except model downloads.

### Test-Gated Core Logic
Every new feature or contract change MUST add or update tests in MinuteCore
Practise TDD

### Consistent, Predictable UX
- UI stays thin; business logic belongs in `MinuteCore`.
- UX SHOULD follow apple guidelines for Human Interfaces
- Use `MinuteError` for user-facing failures and `OSLog` for logs. Do not log raw transcripts by default.

### Personality and AI guidance
You are my main contributor 
- Be curious, you are allowed to propose better solutions if you notice flaws.
- Feel free to continue working without interruption but do ask your human
  if you get stuck in a loop.

## More information
General documentation overview: `docs/overview.md`.
Constitution: `.specify/constitution.md`.
Specification history: `specs/`

## Active Technologies
- Swift 6.2 tools for `MinuteCore`; Swift/SwiftUI macOS app target on Xcode 15.x conventions + SwiftUI, Combine, `MinuteCore`, `MinuteLlama`, new `MinuteOllama` target, Foundation networking for localhost daemon calls, AVFoundation, ScreenCaptureKit, FluidAudio (017-ollama-summarization-option)
- Local vault files, `UserDefaults`-backed app preferences, Application Support model artifacts for llama.cpp, and Ollama daemon state managed outside Minute (017-ollama-summarization-option)

## Recent Changes
- 017-ollama-summarization-option: Added Swift 6.2 tools for `MinuteCore`; Swift/SwiftUI macOS app target on Xcode 15.x conventions + SwiftUI, Combine, `MinuteCore`, `MinuteLlama`, new `MinuteOllama` target, Foundation networking for localhost daemon calls, AVFoundation, ScreenCaptureKit, FluidAudio
