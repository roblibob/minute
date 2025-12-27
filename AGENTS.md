# Minute — Agent Guide

This document describes how to work in this repository: coding conventions, architecture expectations, testing/linting, and release discipline.

## Product constraints (v1)
Source of truth: `docs/overview.md`.

Hard requirements:
- Native macOS app (Swift + SwiftUI), macOS 14+
- Audio is recorded locally
- Transcription runs locally (whisper)
- Summarization runs locally (llama)
- Exactly three files are written to the selected Obsidian vault per processed meeting:
  - Markdown note: `Meetings/YYYY/MM/YYYY-MM-DD - <Title>.md`
  - WAV audio: `Meetings/_audio/YYYY-MM-DD - <Title>.wav`
  - Transcript Markdown: `Meetings/_transcripts/YYYY-MM-DD - <Title>.md`
- WAV format must be mono, 16 kHz, 16-bit PCM
- No outbound network calls except model downloads

## Repository structure
- `Minute/` — App target (SwiftUI)
- `Minute.xcodeproj/` — Xcode project
- `docs/` — Product docs
- `docs/tasks/` — Execution-ordered implementation plan

Planned addition:
- `MinuteCore/` (Swift Package) — non-UI logic, services, rendering, contracts

## Architecture guidance
Follow the plan in `docs/tasks/`.

Key principles:
- UI stays thin; business logic lives in `MinuteCore`.
- Single source-of-truth state machine for the pipeline.
- Determinism at boundaries:
  - models output JSON only
  - app renders Markdown deterministically
  - atomic file writes

Suggested module boundaries (inside `MinuteCore`):
- Domain/types (schemas, file contracts)
- Services (audio, transcription, summarization, vault access, model management)
- Rendering (Markdown renderer)

## Development guidelines
SOLID Principles
- Single Responsibility: One responsibility to one actor
- Open/Closed: Open for extension, closed for modification
- Liskov Substitution: Subtypes must be substitutable
- Interface Segregation: No forced implementation of unused methods
- Dependency Inversion: Depend on abstractions, not concretions

Clean Code Principles
- Comments: Code should be self-documenting
- Boundaries: Clear interfaces between modules
- Testability: Code structure that facilitates testing

Comment Only What the Code Cannot Say
- Apply the principle: "Comment what the code cannot say, not simply what it does not say"
- Remove redundant comments that simply repeat what the code already expresses
- Keep only comments that provide valuable context that cannot be expressed through code structure
- Ensure code is self-explanatory through clear naming and structure rather than excessive commenting

## Concurrency
- Prefer Swift Concurrency (`async`/`await`).
- Use `@MainActor` only for UI state updates.
- Use `actor` or immutable structs for shared state.
- Every long-running operation must support cancellation.

## Error handling
- Use a small set of domain errors (`MinuteError`) surfaced to the UI.
- Map OS/framework errors at the boundary.
- Keep user-visible error messages concise; include debug details only in logs or an optional debug panel.

## Logging and privacy
- Use `OSLog`.
- Do not log raw transcripts by default.
- Transcript is written to the vault as its own Markdown file (not embedded into the meeting note body).

## Audio conversion policy
- Capture with AVFoundation.
- Prefer an `ffmpeg` conversion step to guarantee mono 16 kHz 16-bit PCM WAV output.
- Always verify the resulting WAV format.

## Whisper/Llama integration policy
Preference order:
1. Library integration (preferred): link whisper/llama as libraries via SPM/CMake/XCFramework and call from Swift via a small C shim.
2. Executable integration (fallback): bundle CLI binaries and invoke via `Process`.

Be pragmatic: ship v1 reliably even if the fallback path is required.

## Testing
### Unit tests (required)
Add tests in `MinuteCore` for:
- Markdown renderer (golden tests)
- Filename sanitization
- File contract path generation
- JSON decoding + validation behavior
- Always add tests for new features

### Integration tests (recommended)
- Mock the process runner (or library wrapper) to test whisper/llama output handling.

### Manual QA (required before release)
Use the checklist in `docs/tasks/10-packaging-sandbox-signing-and-qa.md`.

## Linting and formatting
This repo currently has no enforced linter/formatter configuration committed.

Recommended setup:
- Formatting: `swift-format`
  - Install: `brew install swift-format`
  - Use: run `swift-format format -i -r Minute MinuteCore` once `MinuteCore` exists
- Linting: SwiftLint (optional but recommended)
  - Install: `brew install swiftlint`
  - Add a minimal `.swiftlint.yml` once the codebase grows

If you add these tools, also add:
- A CI step (GitHub Actions or similar)
- A short `make lint`/`make format` or documented `xcodebuild` invocations

## Building and testing (CLI)
Common patterns (adjust scheme names as they evolve):
- Build:
  - `xcodebuild -project Minute.xcodeproj -scheme Minute -configuration Debug build`
- Test:
  - `xcodebuild -project Minute.xcodeproj -scheme Minute -configuration Debug test`

If CI is added, prefer using `xcodebuild` so it matches local behavior.

## Release discipline
- Keep the output contract stable.
- Changes that affect note format or paths must update docs and tests.
- Before release:
  - Run unit tests
  - Run the manual QA checklist
  - Validate sandbox + security-scoped bookmark flows
  - Validate that only model downloads touch the network
