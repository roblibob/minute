# Implementation Plan: Advanced Inference Provider Options

**Branch**: `017-ollama-summarization-option` | **Date**: 2026-03-24 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `/specs/017-ollama-summarization-option/spec.md`

**Note**: This template is filled in by the `/speckit.plan` command. See `.specify/templates/commands/plan.md` for the execution workflow.

## Summary

Add advanced-user AI configuration that lets Minute choose provider and model separately for summarization and for vision-based screen-context inference, with `Built-in` and `Ollama` available for each capability in onboarding and settings. Preserve the existing three-file vault contract, introduce Ollama discovery/validation for locally available models and vision capability, and freeze each capability’s provider/model at task start so in-flight work stays deterministic.

## Technical Context

**Language/Version**: Swift 6.2 tools for `MinuteCore`; Swift/SwiftUI macOS app target on Xcode 15.x conventions  
**Primary Dependencies**: SwiftUI, Combine, `MinuteCore`, `MinuteLlama`, new `MinuteOllama` target, Foundation networking for localhost daemon calls, AVFoundation, ScreenCaptureKit, FluidAudio  
**Storage**: Local vault files, `UserDefaults`-backed app preferences, Application Support model artifacts for llama.cpp, and Ollama daemon state managed outside Minute  
**Testing**: Swift Testing in `MinuteCore/Tests/MinuteCoreTests` plus app-facing tests in `MinuteTests`  
**Target Platform**: macOS 14+ (Apple Silicon focus)
**Project Type**: Native macOS app (`Minute/`) with shared business logic in Swift Package (`MinuteCore/`) and runtime-specific package targets  
**Performance Goals**: Provider/model switching and validation should feel immediate in wizard/settings; Ollama discovery should complete quickly against the local daemon; summarization and vision startup should not regress existing task responsiveness beyond local availability checks  
**Constraints**: Preserve the exact three-file vault contract; local-only processing only; no outbound network calls except model downloads; summarization and vision configuration remain independent; in-progress tasks must keep the provider/model selected at task start; UI remains thin and business logic stays in `MinuteCore`  
**Scale/Scope**: Single-user desktop workflow covering onboarding, settings, capability-specific model readiness, summarization runtime selection, vision runtime selection, and local Ollama model discovery for one machine at a time

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

- Output contract unchanged or updated docs/tests included. ✅ Unchanged three-file vault contract; plan adds tests around provider switching without changing note/audio/transcript paths.
- Local-only processing preserved; no outbound network calls beyond model downloads. ✅ Preserved; Ollama integration talks only to the local daemon on `localhost`, and any model downloads remain explicit Ollama pulls or existing pinned downloads.
- Deterministic Markdown rendering maintained for any note changes. ✅ Preserved; provider choice changes runtime selection only, not the renderer or vault write contract.
- MinuteCore tests added/updated for new behavior (renderer, file contracts, JSON validation). ✅ Planned for capability-specific provider persistence, runtime selection, discovery parsing, validation, and in-flight task binding.
- Pipeline state machine and cancellation support respected for long-running work. ✅ Planned; capability-specific selection is resolved before task start and long-running work remains behind existing coordinator/orchestrator boundaries.

**Gate Status**: PASS (no justified violations)

## Project Structure

### Documentation (this feature)

```text
specs/017-ollama-summarization-option/
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
│   ├── ViewModels/
│   │   ├── MeetingPipelineViewModel.swift
│   │   └── ModelSetupLifecycleController.swift
│   └── Views/
│       ├── Onboarding/
│       │   ├── OnboardingView.swift
│       │   └── OnboardingViewModel.swift
│       └── Settings/
│           ├── ModelsSettingsSection.swift
│           ├── ModelsSettingsViewModel.swift
│           ├── SummarizationProviderPicker.swift
│           ├── VisionProviderPicker.swift
│           └── InferenceCapabilityStatusView.swift
└── [imports `MinuteOllama` alongside existing runtime modules]

MinuteCore/
├── Package.swift
├── Sources/
│   ├── MinuteCore/
│   │   ├── Configuration/
│   │   │   └── AppConfiguration.swift
│   │   ├── Domain/
│   │   │   ├── InferenceCapability.swift
│   │   │   ├── InferenceProvider.swift
│   │   │   └── OllamaModelDescriptor.swift
│   │   ├── Pipeline/
│   │   │   └── MeetingPipelineCoordinator.swift
│   │   └── Services/
│   │       ├── DefaultModelManager.swift
│   │       ├── ServiceProtocols.swift
│   │       ├── SummarizationModelSelectionStore.swift
│   │       ├── VisionModelSelectionStore.swift
│   │       ├── InferenceProviderSelectionStore.swift
│   │       └── InferenceRuntimeFactory.swift
│   ├── MinuteLlama/
│   │   └── Services/
│   │       ├── LlamaLibrarySummarizationService.swift
│   │       └── LlamaMTMDScreenInferenceService.swift
│   └── MinuteOllama/
│       └── Services/
│           ├── OllamaSummarizationService.swift
│           ├── OllamaVisionInferenceService.swift
│           ├── OllamaModelDiscoveryService.swift
│           └── OllamaAPIClient.swift
└── Tests/
    └── MinuteCoreTests/
        ├── InferenceProviderSelectionStoreTests.swift
        ├── OllamaModelDiscoveryServiceTests.swift
        └── InferenceRuntimeFactoryTests.swift

MinuteTests/
├── OnboardingInferenceProviderTests.swift
└── ModelsSettingsInferenceProviderTests.swift
```

**Structure Decision**: Keep capability-neutral orchestration and persistence in `MinuteCore`, preserve `MinuteLlama` for built-in summarization and vision, and add a small `MinuteOllama` package target for daemon-backed summarization, vision, and discovery. The app target remains thin and imports the runtime modules only where it builds the live service factories.

## Phase 0 — Research (completed)

See [research.md](research.md).

Key conclusions:
- Add capability-aware provider selection and model-selection stores instead of overloading the existing summarization model store.
- Use Ollama’s local `GET /api/tags` endpoint to discover downloaded models and `POST /api/show` to inspect per-model capabilities, including `vision`.
- Do not rely on a local Ollama API for “not yet downloaded” models; no documented local endpoint provides that inventory, so the feature should work with downloaded-model discovery plus advanced-user model selection.
- Support separate built-in or Ollama choices for summarization and vision, and validate that any chosen vision model actually advertises vision capability.

## Phase 1 — Design & Contracts (completed)

- Data model: [data-model.md](data-model.md)
- Internal contracts: [contracts/openapi.yaml](contracts/openapi.yaml)
- Validation and QA flow: [quickstart.md](quickstart.md)

## Phase 2 — Implementation Plan

### 1) Add capability-aware provider and model preferences in MinuteCore

- Introduce capability-aware domain types for `summarization` and `vision`.
- Add dedicated provider-selection stores backed by `UserDefaults` for both capabilities.
- Preserve existing built-in model/context selections and add provider-specific Ollama model-tag persistence so changing one capability does not overwrite the user’s saved choices for the other capability.
- Add migration logic so existing users default to `Built-in` for both capabilities without behavior change.

### 2) Add runtime-factory boundaries that freeze configuration per task

- Replace direct built-in runtime construction in the app layer with capability-aware runtime factories.
- Resolve the active provider and model reference separately for summarization and vision at the moment each task starts.
- Bind the resolved summarization runtime into the existing `MeetingPipelineCoordinator` closure so mid-run settings changes do not alter the active summarization runtime for in-flight work.
- Bind the resolved vision runtime into the screen-context inference path so mid-task settings changes do not alter the active vision runtime for in-flight work.
- Keep `MeetingNotesBrowserViewModel` reprocessing on the same summarization-selection path so normal runs and reprocess runs stay consistent.

### 3) Add a dedicated `MinuteOllama` runtime target for local daemon-backed summarization and vision

- Add a new Swift package target for Ollama-specific API calls and service implementations.
- Implement an Ollama-backed `SummarizationServicing` type that matches the existing JSON-output contract expected by `MeetingPipelineCoordinator`.
- Implement an Ollama-backed vision inference service that can accept local image data and return structured screen-context output.
- Keep network access restricted to the local Ollama daemon base URL.
- Translate daemon/connectivity failures into concise `MinuteError` user-facing states rather than surfacing raw transport errors.

### 4) Add local Ollama discovery and capability validation flows

- Implement discovery against `GET /api/tags` to list locally available Ollama models.
- Implement per-model details lookup with `POST /api/show` so the app can inspect capabilities, context metadata, and whether a model advertises `vision`.
- Validate that any Ollama model selected for vision includes vision capability before it can be used.
- Represent daemon availability, downloaded-model inventory, selected-tag validity, and capability metadata in capability-neutral readiness models usable by both onboarding and settings.
- Explicitly treat “not yet downloaded models” as outside the daemon-discovery API scope for this feature; if the selected tag is absent, the UX should explain that the model must be pulled in Ollama first.

### 5) Update onboarding and settings to expose separate advanced controls

- Extend `OnboardingViewModel` and `ModelsSettingsViewModel` with separate summarization and vision provider/model state plus capability-specific readiness messaging.
- Update onboarding and settings UI to show:
  - summarization provider and model selection,
  - vision provider and model selection,
  - readiness/status messaging appropriate to each capability.
- Preserve the distinction between summarization, vision, and transcription configuration.
- Update download/readiness copy so it no longer implies one shared AI-model stack applies to every capability.

### 6) Test plan (TDD, contract-first)

- Add `MinuteCore` tests for capability-specific provider-selection persistence, migration defaults, and independent model-selection preservation.
- Add `MinuteCore` tests for Ollama discovery parsing from `/api/tags` and `/api/show`, including `vision` capability extraction, unavailable-daemon handling, and non-vision model rejection for the vision capability.
- Add `MinuteCore` tests for runtime factory selection and coordinator/screen-inference behavior that prove in-flight tasks stay bound to the provider/model chosen at start.
- Add `MinuteTests` coverage for onboarding/settings exposure, persistence, and capability-specific readiness messaging.
- Add regression tests confirming the vault three-file output contract remains unchanged regardless of summarization or vision provider selection.

## Post-Design Constitution Re-check

- Output contract: unchanged; capability-specific provider choice affects runtime selection only and does not alter artifact count, paths, or atomic writes ✅
- Local-only and privacy: preserved; Ollama integration targets `localhost` only, with no new remote dependencies beyond optional model downloads already allowed by policy ✅
- Determinism: note rendering remains unchanged and capability-specific provider/model binding is frozen at task start to avoid mid-task drift ✅
- Test-gated core logic: plan adds `MinuteCore` and app tests for capability-specific persistence, discovery, binding, and UX exposure ✅
- State machine/cancellation: long-running work remains inside existing coordinator/orchestrator boundaries with no UI-thread blocking design ✅

## Complexity Tracking

No constitution violations are required for this feature.
