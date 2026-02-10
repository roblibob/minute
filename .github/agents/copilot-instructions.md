# Minute Development Guidelines

Auto-generated from all feature plans. Last updated: 2026-02-04

## Active Technologies
- JSON file-based metadata (Obsidian vault + internal app support) (003-meeting-type-prompts)
- Swift 5.9 (Xcode 15.x) + SwiftUI (app), MinuteCore (SPM), MinuteLlama (llama XCFramework + CLI), FluidAudio (ASR/diarization), AVFoundation, ScreenCaptureKi (004-background-summarization)
- Filesystem (vault outputs + temp dirs) + UserDefaults (settings, security-scoped bookmarks) (004-background-summarization)
- Swift 5.9 (Xcode 15.x) + MinuteCore (Swift Package), local llama.cpp XCFramework integration (`MinuteLlama`), SwiftUI app target (005-meeting-type-autodetect)
- N/A (classification is derived from transcript text; no new persisted entities required) (005-meeting-type-autodetect)
- Swift 5.9 (Xcode 15.x) + SwiftUI (app), MinuteCore (SPM), FluidAudio (ASR/diarization), AVFoundation; bundled ffmpeg available in `Vendor/ffmpeg` for deterministic audio preprocessing (006-speaker-diarization)
- Swift 5.9+ (Xcode 15.x), macOS 14+. (006-speaker-diarization)
- Swift 5.9+ (Xcode 15.x), SwiftUI + SwiftUI, AppKit (for macOS window management), MinuteCore (domain logic) (007-fix-ui-layout)
- N/A (UI layout fixes only) (007-fix-ui-layout)
- Swift 5.9 (Xcode 15.x) + SwiftUI, AVFoundation, ScreenCaptureKit, MinuteCore (008-main-ui-refactor)
- Files (vault outputs + app support) + UserDefaults for preferences (008-main-ui-refactor)

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
- 008-main-ui-refactor: Added Swift 5.9 (Xcode 15.x) + SwiftUI, AVFoundation, ScreenCaptureKit, MinuteCore
- 007-fix-ui-layout: Added Swift 5.9+ (Xcode 15.x), SwiftUI + SwiftUI, AppKit (for macOS window management), MinuteCore (domain logic)
- 006-speaker-diarization: Added Swift 5.9+ (Xcode 15.x), macOS 14+.


<!-- MANUAL ADDITIONS START -->
<!-- MANUAL ADDITIONS END -->
