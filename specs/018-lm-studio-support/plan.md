# Implementation Plan: LM Studio Provider Support

**Branch**: `018-lm-studio-support` | **Date**: 2026-04-02 | **Spec**: [spec.md](../018-lm-studio-support/spec.md)
**Input**: Feature specification from `/specs/018-lm-studio-support/spec.md`

**Note**: This template is filled in by the `/speckit.plan` command. See `.specify/templates/commands/plan.md` for the execution workflow.

## Summary

Add `LM Studio` as a third local inference provider for summarization and screen-context vision in onboarding and settings, matching the current advanced-provider workflow without changing the three-file vault contract. The implementation will keep provider binding in `MinuteCore`, add a dedicated `MinuteLMStudio` runtime target for local server discovery and inference, and generalize current Ollama-specific persistence and readiness paths so `Built-in`, `Ollama`, and `LM Studio` coexist cleanly.

## Technical Context

**Language/Version**: Swift 6.2 tools for `MinuteCore`; Swift/SwiftUI macOS app target on Xcode 15.x conventions  
**Primary Dependencies**: SwiftUI, Combine, `MinuteCore`, `MinuteLlama`, `MinuteOllama`, new `MinuteLMStudio` target, Foundation networking for local server calls, AVFoundation, ScreenCaptureKit, FluidAudio  
**Storage**: Local vault files, `UserDefaults`-backed provider preferences and local server settings, Application Support model artifacts for built-in runtimes, and user-managed Ollama and LM Studio state outside Minute  
**Testing**: Swift Testing in `MinuteCore/Tests/MinuteCoreTests` plus app-facing tests in `MinuteTests`  
**Target Platform**: macOS 14+ (Apple Silicon focus)
**Project Type**: Native macOS app (`Minute/`) with shared business logic in Swift Package (`MinuteCore/`) and runtime-specific package targets  
**Performance Goals**: Provider changes and readiness refresh should feel immediate in onboarding and settings; LM Studio discovery should complete quickly against the local server; summarization and vision startup should not regress existing responsiveness beyond local availability checks  
**Constraints**: Preserve the exact three-file vault contract; local-only processing only; no outbound network calls except model downloads; keep summarization and vision configuration independent; freeze provider and model at task start; keep LM Studio scoped to local loopback server usage; UI remains thin and business logic stays in `MinuteCore`  
**Scale/Scope**: Single-user desktop workflow covering onboarding, settings, capability-specific model readiness, reprocessing, summarization runtime selection, vision runtime selection, and local LM Studio model discovery for one machine at a time

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

- Output contract unchanged or updated docs/tests included. ✅ Unchanged three-file vault contract; plan adds regression coverage around provider selection without changing note, audio, or transcript paths.
- Local-only processing preserved; no outbound network calls beyond model downloads. ✅ Preserved; LM Studio integration is scoped to a user-managed local loopback server.
- Deterministic Markdown rendering maintained for any note changes. ✅ Preserved; provider choice changes runtime selection only, not renderer behavior or vault write contract.
- MinuteCore tests added/updated for new behavior (renderer, file contracts, JSON validation). ✅ Planned for provider persistence, LM Studio discovery/validation, immutable task binding, and contract regression coverage.
- Pipeline state machine and cancellation support respected for long-running work. ✅ Planned; provider selection is resolved before task start and long-running work remains behind existing coordinator boundaries.

**Gate Status**: PASS (no justified violations)

## Project Structure

### Documentation (this feature)

```text
specs/018-lm-studio-support/
├── plan.md
├── research.md
├── data-model.md
├── quickstart.md
├── contracts/
│   └── openapi.yaml
└── tasks.md
```

### Source Code (repository root)

```text
Minute/
├── Sources/
│   ├── Views/
│   │   ├── Onboarding/
│   │   │   ├── OnboardingView.swift
│   │   │   └── OnboardingViewModel.swift
│   │   └── Settings/
│   │       ├── ModelsSettingsSection.swift
│   │       ├── ModelsSettingsViewModel.swift
│   │       └── InferenceCapabilityStatusView.swift
│   └── ViewModels/
│       ├── MeetingPipelineViewModel.swift
│       └── ModelSetupLifecycleController.swift

MinuteTests/
├── OnboardingInferenceProviderTests.swift
├── ModelsSettingsInferenceProviderTests.swift
├── MeetingPipelineViewModelScreenContextAlertsTests.swift
└── MeetingNotesBrowserViewModelReprocessingTests.swift

MinuteCore/
├── Package.swift
├── Sources/
│   ├── MinuteCore/
│   │   ├── Configuration/
│   │   │   └── AppConfiguration.swift
│   │   ├── Domain/
│   │   │   ├── InferenceCapability.swift
│   │   │   ├── InferenceProvider.swift
│   │   │   ├── CapabilityAvailabilityState.swift
│   │   │   └── LMStudioModelDescriptor.swift
│   │   ├── Pipeline/
│   │   │   └── MeetingPipelineCoordinator.swift
│   │   └── Services/
│   │       ├── InferenceProviderSelectionStore.swift
│   │       ├── InferenceRuntimeFactory.swift
│   │       ├── DefaultModelManager.swift
│   │       ├── ServiceProtocols.swift
│   │       └── ProviderConnectionSettingsStore.swift
│   ├── MinuteLlama/
│   │   └── Services/
│   ├── MinuteOllama/
│   │   └── Services/
│   └── MinuteLMStudio/
│       └── Services/
│           ├── LMStudioAPIClient.swift
│           ├── LMStudioModelDiscoveryService.swift
│           ├── LMStudioSummarizationService.swift
│           └── LMStudioVisionInferenceService.swift
└── Tests/
    └── MinuteCoreTests/
        ├── InferenceProviderSelectionStoreTests.swift
        ├── InferenceRuntimeFactoryTests.swift
        ├── LMStudioModelDiscoveryServiceTests.swift
        └── OutputContractCoverageTests.swift
```

**Structure Decision**: Keep capability-neutral orchestration, persistence, and pipeline binding in `MinuteCore`, preserve existing built-in and Ollama runtime modules, and add a sibling `MinuteLMStudio` target for LM Studio-specific discovery, validation, and inference. The app target remains thin and imports runtime modules only where it builds live service factories and provider-facing UI state.

## Phase 0 — Research (completed)

See [research.md](../018-lm-studio-support/research.md).

Key conclusions:
- Use LM Studio's OpenAI-compatible local inference endpoints for summarization and vision.
- Use local model-discovery endpoints with richer LM Studio metadata to validate model availability and vision capability.
- Keep LM Studio scoped to a loopback-local server to stay within Minute's local-only constitution.
- Add a dedicated `MinuteLMStudio` runtime target and generalize current Ollama-specific provider state where needed.

## Phase 1 — Design & Contracts (completed)

- Data model: [data-model.md](../018-lm-studio-support/data-model.md)
- Internal contracts: [contracts/openapi.yaml](../018-lm-studio-support/contracts/openapi.yaml)
- Validation and QA flow: [quickstart.md](../018-lm-studio-support/quickstart.md)

## Phase 2 — Implementation Plan

### 1. Extend provider domain and persisted settings

- Add `LM Studio` to the provider catalog and user-facing provider descriptions.
- Extend persisted configuration so each capability can retain built-in, Ollama, and LM Studio model references independently.
- Add LM Studio local server settings with a loopback default and preserve existing upgraded-user defaults.
- Refactor current Ollama-named persistence seams where necessary so the app does not accumulate duplicate advanced-provider state.

### 2. Generalize runtime binding while preserving immutable per-task selection

- Extend `InferenceRuntimeFactory` so summarization and vision can resolve `LM Studio` bindings without changing the existing task-start binding model.
- Keep provider/model resolution frozen at task start for summarization, screen-context inference, and reprocessing flows.
- Preserve built-in and Ollama behavior for users who never choose LM Studio.

### 3. Add a dedicated `MinuteLMStudio` runtime integration

- Add a new Swift package target for LM Studio discovery, validation, summarization, and vision inference.
- Implement local server access through LM Studio's documented local endpoints.
- Translate local server and model-availability failures into concise `MinuteError` user-facing states rather than raw transport errors.

### 4. Add LM Studio readiness, discovery, and validation flows

- Discover local LM Studio models from the configured local server.
- Validate that the selected LM Studio model still exists and is appropriate for the selected capability.
- Block vision configuration when the selected LM Studio model is not vision-capable.
- Surface capability-specific readiness messages that remain clear whether the affected provider is built-in, Ollama, or LM Studio.

### 5. Update onboarding and settings for third-provider parity

- Extend onboarding and settings view models so summarization and vision each expose `Built-in`, `Ollama`, and `LM Studio`.
- Surface LM Studio connection and model controls only when that provider is selected.
- Preserve the distinction between summarization, vision, and transcription configuration.
- Ensure provider copy remains understandable to advanced but non-developer users.

### 6. Test plan (TDD, contract-first)

- Add `MinuteCore` tests for provider enum expansion, persisted migration defaults, and independent provider/model retention across summarization and vision.
- Add `MinuteCore` tests for LM Studio connection validation, model-discovery parsing, vision-capability rejection, and immutable task binding.
- Add `MinuteTests` coverage for onboarding and settings exposure, persistence, readiness messaging, and provider switching.
- Add regression tests confirming the deterministic three-file vault contract remains unchanged regardless of provider combination.

## Post-Design Constitution Re-check

- Output contract: unchanged; LM Studio affects runtime selection only and does not alter artifact count, paths, or atomic writes ✅
- Local-only and privacy: preserved; LM Studio is scoped to a local loopback server and introduces no new remote dependency beyond allowed model downloads ✅
- Determinism: note rendering remains unchanged and provider/model binding is frozen at task start to avoid mid-task drift ✅
- Test-gated core logic: plan adds `MinuteCore` and app tests for persistence, discovery, validation, binding, and contract regressions ✅
- State machine and cancellation: long-running work remains inside existing coordinator boundaries with no UI-thread blocking design ✅

## Complexity Tracking

No constitution violations are required for this feature.
