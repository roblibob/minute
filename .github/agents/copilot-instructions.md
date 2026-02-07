# Minute Development Guidelines

Auto-generated from all feature plans. Last updated: 2026-02-04

## Active Technologies
- JSON file-based metadata (Obsidian vault + internal app support) (003-meeting-type-prompts)
- Swift 5.9 (Xcode 15.x) + SwiftUI (app), MinuteCore (SPM), MinuteLlama (llama XCFramework + CLI), FluidAudio (ASR/diarization), AVFoundation, ScreenCaptureKi (004-background-summarization)
- Filesystem (vault outputs + temp dirs) + UserDefaults (settings, security-scoped bookmarks) (004-background-summarization)
- Swift 5.9 (Xcode 15.x) + MinuteCore (Swift Package), local llama.cpp XCFramework integration (`MinuteLlama`), SwiftUI app target (005-meeting-type-autodetect)
- N/A (classification is derived from transcript text; no new persisted entities required) (005-meeting-type-autodetect)

- Swift 5.9 + SwiftUI, Combine, AVFoundation, MinuteCore (Internal), Llama (Internal C++ wrapper) (001-meeting-type-prompts)

## Project Structure

```text
src/
tests/
```

## Commands

# Add commands for Swift 5.9

## Code Style

Swift 5.9: Follow standard conventions

## Recent Changes
- 005-meeting-type-autodetect: Added Swift 5.9 (Xcode 15.x) + MinuteCore (Swift Package), local llama.cpp XCFramework integration (`MinuteLlama`), SwiftUI app target
- 004-background-summarization: Added Swift 5.9 (Xcode 15.x) + SwiftUI (app), MinuteCore (SPM), MinuteLlama (llama XCFramework + CLI), FluidAudio (ASR/diarization), AVFoundation, ScreenCaptureKi
- 003-meeting-type-prompts: Added Swift 5.9 + SwiftUI, Combine, AVFoundation, MinuteCore (Internal), Llama (Internal C++ wrapper)


<!-- MANUAL ADDITIONS START -->
<!-- MANUAL ADDITIONS END -->
