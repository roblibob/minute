# 01 — Foundation and Project Structure

## Goal
Establish a maintainable Swift/SwiftUI macOS codebase with clear module boundaries, consistent error handling, and a predictable dependency graph. This phase should result in a running app shell and a buildable core package where all non-UI logic lives.

## Deliverables
- Xcode project builds and runs on macOS 14+
- A `MinuteCore` Swift Package added to the app workspace
- Core modules/protocols stubbed to match the overview services
- Baseline logging + error types
- A small “smoke test” flow in the UI that exercises state transitions without real recording/inference yet

## Recommended module layout
### App target: `MinuteApp`
Contains:
- SwiftUI views
- ViewModels / state machine
- Settings UI
- Composition root (dependency wiring)

### Swift Package: `MinuteCore`
Prefer splitting into targets inside the package (still one SPM package):
- `MinuteDomain`
  - Types and schemas: `MeetingExtraction`, `ActionItem`, etc.
  - Path contract types: `VaultPaths`, `MeetingFileContract`
- `MinuteServices`
  - `AudioService`, `TranscriptionService`, `SummarizationService`
  - `ModelManager`, `VaultAccess`, `VaultWriter`
- `MinuteRendering`
  - `MarkdownRenderer`
  - Filename sanitization + template rendering

This keeps the app target small and the core portable/testable.

## Coding standards and best practices
- Concurrency: prefer structured concurrency (`async` functions, `Task`, `TaskGroup`) for pipeline stages.
- Isolation: use `actor` for shared mutable state (e.g., model downloads, pipeline coordinator) or make services immutable.
- Error handling: define a narrow set of domain errors and map system errors into them at the boundary.
- Logging: use `OSLog` with categories per subsystem.
- Avoid “stringly typed” contracts: represent file paths and schema as typed models.

## Baseline types (to implement in this phase)
### Domain
- `MeetingExtraction` Codable model matching the fixed JSON schema
- `MeetingNote` (derived) containing title/date + rendered Markdown
- `MeetingFileContract`
  - Computes relative vault paths (Meetings/YYYY/MM and Meetings/_audio)
  - Enforces WAV filename contract and note filename contract

### Errors
Define an enum such as:
- `MinuteError.permissionDenied`
- `MinuteError.vaultUnavailable`
- `MinuteError.audioExportFailed`
- `MinuteError.whisperFailed(exitCode: Int, output: String)`
- `MinuteError.llamaFailed(exitCode: Int, output: String)`
- `MinuteError.jsonInvalid`
- `MinuteError.vaultWriteFailed`

Keep the original underlying error (`underlying: Error?`) for debugging, but avoid leaking it to UI.

## Service protocols
Create protocols in `MinuteCore` (and concrete implementations later):
- `VaultAccessing`
- `AudioServicing`
- `TranscriptionServicing`
- `SummarizationServicing`
- `MarkdownRendering`
- `VaultWriting`
- `ModelManaging`

Keep protocols small. For example, `TranscriptionServicing.transcribe(wavURL:) async throws -> TranscriptionResult`.

## App composition root
In the app target, implement a single place to construct dependencies. Typical patterns:
- An `AppEnvironment` struct containing the service instances
- A `DependencyContainer` with lazy properties

Keep UI code dependent only on protocols (when feasible), not concrete types.

## State machine foundation (stub)
Even in this phase, implement the state enum and transitions (without real audio/model yet). This reduces future refactors.

Suggested states:
- `idle`
- `recording(startedAt: Date)`
- `recorded(audioTempURL: URL, duration: TimeInterval)`
- `processing(stage: ProcessingStage, progress: Double?)`
- `done(noteURL: URL, audioURL: URL)`
- `failed(userMessage: String, debug: String?)`

Where `ProcessingStage` is:
- `transcribe`
- `summarize`
- `repairJSON`
- `write`

## Testing baseline
Add a test target for `MinuteCore` and start with:
- JSON decoding tests for `MeetingExtraction`
- Filename sanitization tests
- Markdown rendering determinism tests (golden string comparison)

## Exit criteria checklist
- [ ] App runs and shows placeholder UI
- [ ] Core package compiles and tests run
- [ ] State machine compiles and can simulate transitions
- [ ] Logging and error mapping approach established
