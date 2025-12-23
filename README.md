# 🕒 Minute

<p align="center">
  <img src="Minute/Assets.xcassets/AppIcon.appiconset/Minute-macOS-Dark-512x512@1x.png" alt="Minute icon" width="160" />
</p>

Minute is a native macOS companion for Obsidian that turns meetings into clean, structured notes. It records audio locally, transcribes with Whisper, summarizes with Llama, and writes the results directly into your vault.

## ✨ What it does
- Record a meeting and process it locally.
- Produce deterministic Markdown notes that match a fixed template.
- Store meeting artifacts inside your Obsidian vault.

## ⚙️ How it works
1. Record mic + system audio.
2. Transcribe locally (Whisper).
3. Summarize locally (Llama, JSON-only).
4. Render deterministic Markdown.
5. Write files atomically into the vault.

## 📄 Output contract (default)
Exactly three artifacts are written per meeting:
- `Meetings/YYYY/MM/YYYY-MM-DD - <Title>.md`
- `Meetings/_audio/YYYY-MM-DD - <Title>.wav`
- `Meetings/_transcripts/YYYY-MM-DD - <Title>.md`

The WAV format is mono, 16 kHz, 16-bit PCM. The note links to the audio and transcript files.

## 🔒 Privacy and networking
- Audio and inference stay local.
- No outbound network calls except model downloads.

## ✅ Requirements
- macOS 14+
- Apple Silicon (M1 or better)

## 📦 Installation (Alpha)
1. Download the latest `.dmg` from GitHub Releases.
2. Drag `Minute.app` into `/Applications`.
3. Since the app is currently unsigned, approve it in System Settings → Privacy & Security the first time you launch it.

## 🧰 Settings
In General settings you can:
- Choose vault folders
- Toggle whether audio and transcript files are saved (the note omits links when disabled)

## 🛠️ Build (CLI)
```
xcodebuild -project Minute.xcodeproj -scheme Minute -configuration Debug build
```

## 🧪 Test (CLI)
```
xcodebuild -project Minute.xcodeproj -scheme MinuteCore -configuration Debug test
```
