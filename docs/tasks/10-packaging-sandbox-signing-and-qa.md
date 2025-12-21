# 10 — Packaging, Sandbox, Signing, and QA

## Goal
Prepare Minute for distribution as a signed + notarized macOS app (DMG), with App Sandbox enabled and reliable vault access via security-scoped bookmarks.

Also define the QA checklist that verifies the v1 output contract end-to-end.

## Deliverables
- App Sandbox entitlements configured
- Hardened Runtime enabled
- Code signing + notarization pipeline documented
- A manual QA checklist for v1 acceptance
- Basic automated tests running in CI (optional but recommended)

## Sandboxing
### Entitlements
- Enable App Sandbox.
- Allow:
  - Microphone access (privacy is via Info.plist usage string)
  - Screen recording access (required for system audio capture)
  - User-selected file read/write for the Obsidian vault folder (security-scoped)
- Avoid broad file access entitlements.

### Info.plist
Set:
- `NSMicrophoneUsageDescription`: explain local recording
- `NSScreenCaptureUsageDescription`: explain system audio capture

## Bundling whisper, llama, and ffmpeg
### Libraries
If `whisper.cpp` / `llama.cpp` are integrated as libraries:
- Ensure the compiled libraries are included and code-signed as part of the app.
- Confirm runtime linking works under App Sandbox.
- Prefer this approach for simpler cancellation, fewer moving parts, and better observability.

### ffmpeg (WAV conversion)
Given the v1 requirement for deterministic WAV output, this plan assumes `ffmpeg` is bundled (unless AVFoundation-only export is later proven sufficient and `ffmpeg` is removed).
Apply the same code-signing and sandbox validation.

## Notarization and distribution
Recommended release steps:
1. Archive in Xcode (Release)
2. Export signed app
3. Notarize using notarytool
4. Staple the ticket
5. Package into DMG

Document the exact commands used for consistency.

## QA plan
### Acceptance criteria (v1)
From `docs/overview.md`:
- Record → Stop → Process produces exactly three new files in the vault:
  - meeting note `.md`
  - audio `.wav`
  - transcript `.md`
- WAV format: mono, 16 kHz, 16-bit PCM
- Note structure:
  - YAML frontmatter with fixed schema
  - Sections: Summary, Decisions, Action Items, Open Questions, Key Points
  - Links to both the WAV and transcript files in the vault
- No network calls except model downloads

### Manual test checklist
- First run:
  - Select vault folder
  - Configure meetings/audio folders
  - Download models (progress shown)
  - Grant microphone permission
  - Grant screen recording permission
- Daily use:
  - Record short meeting
  - Process
  - Verify files are created at correct paths
  - Open note in Obsidian and verify audio link works
- Failure modes:
  - Deny microphone permission → clear message
  - Deny screen recording permission → clear message
  - Disconnect network on first run → model download error
  - Corrupt model file → checksum mismatch triggers re-download
  - Whisper fails → error shown, no vault artifacts written
  - Llama outputs invalid JSON → repair pass; if still invalid, fallback note created

### Automated tests (recommended)
- `MinuteCore` unit tests:
  - Markdown renderer golden tests
  - Filename sanitization tests
  - MeetingFileContract path computation tests
  - JSON decode + repair behavior tests (repair service mocked)
- Integration tests (mocked transcription/summarization services):
  - Whisper + llama output handling

## Privacy and logging
- Do not log raw transcript by default.
- If debug logging is added, gate behind a user setting and redact by default.

## Exit criteria checklist
- [ ] App runs with App Sandbox enabled and can access vault via bookmark
- [ ] Whisper/llama libraries load successfully inside the signed app
- [ ] DMG can be installed on a clean machine (or new user profile)
- [ ] Manual QA checklist passes
