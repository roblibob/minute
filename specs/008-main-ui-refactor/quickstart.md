# Quickstart: Main UI Refactor (Recording Stage)

**Branch**: 008-main-ui-refactor  
**Date**: 2026-02-09

## Build

- Build app:
  - `xcodebuild -project Minute.xcodeproj -scheme Minute -configuration Debug build`

## Test

- Run tests (project):
  - `xcodebuild -project Minute.xcodeproj -scheme Minute -configuration Debug test -destination 'platform=macOS'`

- Run core package tests (if applicable in your setup):
  - `xcodebuild -workspace Minute.xcworkspace -scheme MinuteCore -configuration Debug test -destination 'platform=macOS'`

## Manual QA (focused)

1. Launch app, ensure no meeting selected → Stage is shown.
2. Verify Meeting Type and Language Processing selectors show last-used values.
3. Toggle mic/system audio and verify the UI reflects active states.
4. Start recording → status + timer update immediately.
5. While recording, change Meeting Type / Language Processing and verify UI updates.
6. Stop recording → normal processing continues and produces exactly three vault files.
7. Start recording, then Cancel Session → no vault outputs are produced for the canceled session.
8. Drag/drop a supported audio file onto Stage → import begins and processing continues.

## Guardrails

- Do not change vault output paths or note rendering rules.
- Do not add outbound network calls.
- Keep long-running work cancellable and off the main thread.
