<h1 align="center">
  <br>
  <img src="Minute/Assets.xcassets/AppIcon.appiconset/Minute-macOS-Dark-512x512@1x.png" alt="Minute" width="200">
  <br>
  Minute
  <br>
</h1>

<h4 align="center">A local-first macOS meeting capture app that writes deterministic notes into your Obsidian vault.</h4>

<p align="center">
  <img alt="platform" src="https://img.shields.io/badge/platform-macOS%2014%2B-0B1B2B">
  <img alt="license" src="https://img.shields.io/badge/license-MIT-2E5EAA">
  <img alt="privacy" src="https://img.shields.io/badge/privacy-local--only-1F7A3F">
</p>

<p align="center">
  <a href="#key-features">Key Features</a> •
  <a href="#output-contract">Output Contract</a> •
  <a href="#how-to-build">How to Build</a> •
  <a href="#testing">Testing</a> •
  <a href="#privacy">Privacy</a> •
  <a href="#docs">Docs</a>
</p>

<p align="center">
  <img src="docs/minute.gif" alt="Minute demo" width="820">
</p>

## Key Features
- Records audio locally (mic + system audio).
- Transcribes locally with Whisper.
- Summarizes locally with Llama (JSON-only output).
- Renders deterministic Markdown using a fixed template.
- Writes notes, audio, and transcript directly into your Obsidian vault.
- Enriches notes with optional screen context captures during recording.
- Live waveform and live transcript during recording.

## Output Contract
Exactly three artifacts are written per processed meeting:
- `Meetings/YYYY/MM/YYYY-MM-DD HH.MM - <Title>.md`
- `Meetings/_audio/YYYY-MM-DD HH.MM - <Title>.wav`
- `Meetings/_transcripts/YYYY-MM-DD HH.MM - <Title>.md`

WAV format: mono, 16 kHz, 16-bit PCM.

Frontmatter example:
```
---
type: meeting
date: Jan 19, 2026 at 11:39
title: "PIE2E and 3DBanken Progress Update"
source: "Minute"
length: 35m
tags:
---
```

## Requirements
- macOS 14+
- Apple Silicon (M1 or newer)

## Privacy
- Audio and inference stay local.
- No outbound network calls except model downloads.

## Contributing
See `CONTRIBUTING.md`.

## Security
See `SECURITY.md`.

## License
MIT. See `LICENSE`.
