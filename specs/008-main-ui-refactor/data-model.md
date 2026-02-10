# Data Model: Main UI Refactor (Recording Stage)

**Branch**: 008-main-ui-refactor  
**Date**: 2026-02-09

This feature is primarily a UI refactor, but it introduces/clarifies a small set of user-facing state and preference entities for the Stage.

## Entities

### StagePreferences

Represents persisted, last-used Stage configuration.

Fields:
- `meetingType`: Meeting type selection (domain value)
- `languageProcessing`: Language processing profile selection (domain value)
- `captureSources`: capture configuration for mic/system audio + optional screen context

Validation:
- If both mic and system audio are disabled, `canStartRecording` is false and UI must explain why.

### LanguageProcessingProfile

Represents a deterministic, persisted “language processing” selection used post-recording.

Fields:
- `input`: input language selection (e.g., auto)
- `output`: output language selection (e.g., English)

Notes:
- Must have a default that matches current behavior.

### CaptureSources

Represents what will be captured for a recording session.

Fields:
- `microphoneEnabled`: Bool
- `systemAudioEnabled`: Bool
- `screenContextEnabled`: Bool
- `screenContextSelection`: Optional selection value ("None" vs chosen)

### RecordingSessionDraft

Represents the in-progress session configuration while actively recording.

Fields:
- `startedAt`: timestamp
- `meetingType`: current value (editable during recording)
- `languageProcessing`: current value (editable during recording)
- `captureSources`: current value (editable during recording)
- `status`: ready | recording | stopping | canceling

### InputLevels

Represents UI-only audio activity samples.

Fields:
- `isListening`: Bool
- `samples`: bounded numeric samples for visualization

## State transitions (Stage)

- `idle` → `recording`: user presses Record and capture successfully starts
- `recording` → `idle`: user presses Stop and capture successfully stops; pipeline continues processing
- `recording` → `idle`: user presses Cancel; session discarded; no meeting output produced
- `idle` → `importing`: user drops/imports a supported media file

## Out of scope

- Changing selected-meeting detail behaviors (analysis/chat/summary UX)
- Changing vault output paths or deterministic renderer rules
