Minute — Native macOS Solution Design (v1)

Goal

Ship a coworker‑friendly native macOS companion app that:
	•	Records a meeting (mic input)
	•	Transcribes locally
	•	Generates a meeting note locally
	•	Writes exactly three artifacts into a user‑selected Obsidian vault:
	•	a Markdown note (.md)
	•	a WAV audio file (.wav)
	•	a transcript Markdown file (.md)

No other integrations are required for v1.

⸻

Fixed v1 output contract

File locations
	•	Markdown note:
	•	Meetings/YYYY/MM/YYYY-MM-DD - <Title>.md
	•	Audio:
	•	Meetings/_audio/YYYY-MM-DD - <Title>.wav
	•	Transcript:
	•	Meetings/_transcripts/YYYY-MM-DD - <Title>.md

The WAV must be mono, 16 kHz, 16‑bit PCM.

Note contents

The note is fully deterministic in structure and contains:
	•	YAML frontmatter
	•	Sections: Summary, Decisions, Action Items, Open Questions, Key Points
	•	A link to the WAV file stored in the vault

Frontmatter (fixed schema)

---
type: meeting
date: YYYY-MM-DD
title: "<Title>"
audio: "Meetings/_audio/YYYY-MM-DD - <Title>.wav"
transcript: "Meetings/_transcripts/YYYY-MM-DD - <Title>.md"
source: "Minute"
---

Body template (fixed)

# <Title>

## Summary
<generated summary>

## Decisions
- <decision 1>

## Action Items
- [ ] <action item> (Owner: <name>) (Due: <YYYY-MM-DD or blank>)

## Open Questions
- <question 1>

## Key Points
- <point 1>

## Audio
[[Meetings/_audio/YYYY-MM-DD - <Title>.wav]]

## Transcript
[[Meetings/_transcripts/YYYY-MM-DD - <Title>.md]]

The transcript is written as its own Markdown file and linked from the note.

⸻

Recommended path: fully native macOS app

Technology choices (fixed)
	•	App: Swift + SwiftUI (macOS 14+ recommended)
	•	Audio capture: AVFoundation (mic) + ScreenCaptureKit (system audio)
	•	Audio format: WAV, mono, 16 kHz, 16‑bit PCM (stored in vault)
	•	Transcription: whisper.cpp (bundled)
	•	LLM summarization: llama.cpp (bundled, Metal‑accelerated build where possible)
	•	Model format: GGUF (downloaded by the app on first run)
	•	Templating: deterministic Markdown renderer (no “model writes markdown”)
	•	The app does not depend on Ollama.

Practical v1 choice: bundle whisper.cpp and llama.cpp as executables and invoke them via Process for fast iteration and deterministic integration.

⸻

User experience

First run
	1.	User selects their Obsidian vault root folder.
	2.	User sets Meeting folder and audio folder, e.g.:
	•	Meetings/
	•	Meetings/_audio/
	3.	Minute downloads required model weights into:
	•	~/Library/Application Support/Minute/models/
	4.	Minute requests microphone and screen recording permissions.

Daily use
	•	Click Start Recording
	•	Click Stop
	•	Click Process

A new note appears in Meetings/… and the audio appears in Meetings/_audio/….

⸻

Processing pipeline (v1)

1) Record
	•	Record microphone + system audio into temporary files.
	•	On stop, mix and convert/export to WAV mono 16 kHz and copy into the vault under Meetings/_audio/.

2) Transcribe (local)
	•	Run whisper.cpp against the WAV file.
	•	Write a transcript Markdown file into the vault under Meetings/_transcripts/.

3) Summarize + extract structure (local)
	•	Run llama.cpp with a JSON‑only prompt.
	•	Output must be valid JSON matching the fixed schema below.

Extraction JSON schema (fixed)

{
  "title": "",
  "date": "YYYY-MM-DD",
  "summary": "",
  "decisions": [""],
  "action_items": [{"owner":"","task":"","due":""}],
  "open_questions": [""],
  "key_points": ["" ]
}

4) Validate and repair

If JSON parse fails:
	1.	Run a single “repair JSON” pass with llama.cpp.
	2.	If still invalid, generate a fallback note with:
	•	Summary: Failed to structure output; see audio for details.
	•	Empty sections.

5) Render Markdown (deterministic)
	•	Minute renders the Markdown note using the fixed template.
	•	The model never writes Markdown; it only produces JSON.

6) Write to vault atomically
	•	Write to a temporary file in the same folder and then rename.

⸻

App architecture

Targets / modules
	1.	MinuteApp (UI)
	•	SwiftUI views
	•	State machine
	•	Progress UI and failure states
	2.	Permissions
	•	Microphone permission gating + messaging
	3.	VaultAccess
	•	Folder selection + sandbox-safe access via security‑scoped bookmarks
	4.	AudioService
	•	Capture → convert/export → final WAV path
	5.	TranscriptionService
	•	Runs whisper.cpp and returns transcript (in memory / temp only)
	6.	SummarizationService
	•	Runs llama.cpp JSON‑only prompt → returns JSON
	7.	Validation & Repair
	•	Strict JSON parsing → single repair → fallback
	8.	MarkdownRenderer
	•	Deterministic Markdown from validated schema
	9.	VaultWriter
	•	Atomic writes and directory creation

State machine (single source of truth)

idle → recording → recorded → processing(transcribe) → processing(summarize) → writing → done | failed

⸻

Sandboxing & vault access (macOS)

To work reliably with notarization + App Sandbox:
	•	Use NSOpenPanel to select the vault root folder.
	•	Persist a security‑scoped bookmark for the vault root.
	•	Before any read/write in the vault:
	•	startAccessingSecurityScopedResource()
	•	do work
	•	stopAccessingSecurityScopedResource()

Minute only reads/writes within:
	•	the selected vault folder
	•	~/Library/Application Support/Minute/…

⸻

Model management

Bundled binaries
	•	whisper.cpp
	•	llama.cpp
	•	ffmpeg (optional; used only if AVFoundation export is insufficient for deterministic 16 kHz mono output)

Downloaded model weights (first run)

Stored under:
	•	~/Library/Application Support/Minute/models/

Defaults (fixed):
	•	Whisper model: base.en (whisper.cpp compatible)
	•	LLM model: qwen2.5-7b-instruct GGUF quantized (Q4)

Download rules:
	•	No network calls except downloading model weights from a pinned, checksum‑verified source.

⸻

Development plan

Phase 0 — Scaffold
	•	Create Xcode SwiftUI app + MinuteCore Swift Package
	•	Implement vault selection + bookmark persistence
	•	Settings UI (Meetings folder + audio folder relative to vault)
	•	Basic Start/Stop/Process screen with state machine

Phase 1 — Audio
	•	Implement AudioService
	•	Verify output WAV constraints (mono, 16 kHz, 16‑bit PCM)

Phase 2 — Transcription
	•	Bundle and invoke whisper.cpp via Process
	•	Capture stdout deterministically + cancellation + errors

Phase 3 — Summarization
	•	Bundle and invoke llama.cpp via Process
	•	JSON‑only prompt + one repair pass

Phase 4 — Deterministic note writing
	•	Schema validation + fallback
	•	Deterministic Markdown renderer
	•	Atomic vault writes

Phase 5 — Packaging
	•	Hardened Runtime + sandbox
	•	Code signing + notarization
	•	Signed .dmg distribution

⸻

Security & privacy
	•	Audio and inference stay local.
	•	Minute makes no outbound requests except model downloads.
	•	Transcript is written to the vault as its own Markdown file.

⸻

Deliverables (v1)
	•	A signed, notarized .dmg containing Minute.app

Install steps:
	1.	Drag Minute.app to Applications
	2.	Open Minute, select vault
	3.	Grant microphone permission
	4.	Wait for model download (first run only)
	5.	Record → Stop → Process → exactly three files appear in the vault
