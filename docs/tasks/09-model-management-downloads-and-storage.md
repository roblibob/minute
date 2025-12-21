# 09 — Model Management: Downloads and Storage

## Goal
Implement first-run model download and storage under Application Support, with pinned source + checksum verification, and expose progress in the UI.

Networking is allowed only for model downloads.

## Deliverables
- `ModelManager` that:
  - Ensures models exist locally
  - Downloads missing models from a pinned URL
  - Verifies checksum (SHA-256) before marking as usable
  - Supports resume if possible (optional)
  - Publishes progress for UI
- Default models (per overview):
  - Whisper: `base.en` (whisper.cpp compatible)
  - LLM: `qwen2.5-7b-instruct` GGUF quantized (Q4)
- Storage location:
  - `~/Library/Application Support/Minute/models/`

## Storage layout
Recommended structure:
- `models/whisper/base.en.bin` (or whichever format whisper expects)
- `models/llm/qwen2.5-7b-instruct-q4.gguf`
- `models/manifest.json` (optional) containing versions + checksums

## Pinned source and verification
- Hardcode or remotely fetch a manifest from a pinned host.
- For v1 simplicity, hardcode:
  - URL
  - expected SHA-256 checksum
  - expected file size

Download rules:
- If checksum mismatch → delete file and fail with clear error.
- Do not proceed to inference until checksum verified.

## Download implementation (Swift)
- Use `URLSessionDownloadTask` for large files.
- Store into a temporary file.
- After download:
  - compute SHA-256
  - move into final models directory atomically

Progress:
- Observe `URLSessionTask` progress via KVO/Combine or `URLSession` delegate.
- Publish to the UI state machine (phase 03) so first-run shows a progress indicator.

## Offline handling
- If models are missing and network is unavailable:
  - show a blocking error with next steps
- If models are present:
  - app runs fully offline

## Versioning and upgrades (v1)
- Keep it minimal:
  - If local model present and checksum matches, do nothing.
  - If you change the pinned model in future, the checksum mismatch will trigger re-download.

## Exit criteria checklist
- [ ] First run downloads both models to Application Support
- [ ] Checksum verification is enforced
- [ ] Progress is visible in the UI
- [ ] App runs offline after models are downloaded
