# Tasks: Advanced Inference Provider Options

**Input**: Design documents from `/Users/roblibob/Projects/FLX/Minute/Minute/specs/017-ollama-summarization-option/`
**Prerequisites**: `/Users/roblibob/Projects/FLX/Minute/Minute/specs/017-ollama-summarization-option/plan.md`, `/Users/roblibob/Projects/FLX/Minute/Minute/specs/017-ollama-summarization-option/spec.md`, `/Users/roblibob/Projects/FLX/Minute/Minute/specs/017-ollama-summarization-option/research.md`, `/Users/roblibob/Projects/FLX/Minute/Minute/specs/017-ollama-summarization-option/data-model.md`, `/Users/roblibob/Projects/FLX/Minute/Minute/specs/017-ollama-summarization-option/contracts/openapi.yaml`

**Tests**: Tests are REQUIRED for this feature because it adds new MinuteCore behavior, new runtime-selection contracts, and new UI flows.

**Organization**: Tasks are grouped by user story so each story can be implemented and validated independently.

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Wire the package and app targets for the new provider-specific runtime surface.

- [x] T001 Update local package products and targets in /Users/roblibob/Projects/FLX/Minute/Minute/MinuteCore/Package.swift
- [x] T002 Update app target package references for the new runtime module in /Users/roblibob/Projects/FLX/Minute/Minute/Minute.xcodeproj/project.pbxproj
- [x] T003 [P] Create capability/provider domain scaffolding in /Users/roblibob/Projects/FLX/Minute/Minute/MinuteCore/Sources/MinuteCore/Domain/InferenceCapability.swift, /Users/roblibob/Projects/FLX/Minute/Minute/MinuteCore/Sources/MinuteCore/Domain/InferenceProvider.swift, /Users/roblibob/Projects/FLX/Minute/Minute/MinuteCore/Sources/MinuteCore/Domain/OllamaModelDescriptor.swift, and /Users/roblibob/Projects/FLX/Minute/Minute/MinuteCore/Sources/MinuteCore/Domain/CapabilityAvailabilityState.swift
- [x] T004 [P] Create runtime/store scaffolding in /Users/roblibob/Projects/FLX/Minute/Minute/MinuteCore/Sources/MinuteCore/Services/InferenceProviderSelectionStore.swift, /Users/roblibob/Projects/FLX/Minute/Minute/MinuteCore/Sources/MinuteCore/Services/VisionModelSelectionStore.swift, /Users/roblibob/Projects/FLX/Minute/Minute/MinuteCore/Sources/MinuteCore/Services/InferenceRuntimeFactory.swift, /Users/roblibob/Projects/FLX/Minute/Minute/MinuteCore/Sources/MinuteOllama/Services/OllamaAPIClient.swift, /Users/roblibob/Projects/FLX/Minute/Minute/MinuteCore/Sources/MinuteOllama/Services/OllamaSummarizationService.swift, /Users/roblibob/Projects/FLX/Minute/Minute/MinuteCore/Sources/MinuteOllama/Services/OllamaVisionInferenceService.swift, and /Users/roblibob/Projects/FLX/Minute/Minute/MinuteCore/Sources/MinuteOllama/Services/OllamaModelDiscoveryService.swift

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Establish shared persistence, protocols, defaults, and runtime-factory infrastructure that all stories depend on.

**⚠️ CRITICAL**: No user story work should begin until this phase is complete.

- [x] T005 [P] Add failing preference and migration coverage in /Users/roblibob/Projects/FLX/Minute/Minute/MinuteCore/Tests/MinuteCoreTests/AppConfigurationTests.swift and /Users/roblibob/Projects/FLX/Minute/Minute/MinuteCore/Tests/MinuteCoreTests/InferenceProviderSelectionStoreTests.swift
- [x] T006 [P] Add failing runtime-factory coverage in /Users/roblibob/Projects/FLX/Minute/Minute/MinuteCore/Tests/MinuteCoreTests/InferenceRuntimeFactoryTests.swift
- [x] T007 Update defaults and migration keys for summarization and vision configuration in /Users/roblibob/Projects/FLX/Minute/Minute/MinuteCore/Sources/MinuteCore/Configuration/AppConfiguration.swift
- [x] T008 [P] Implement provider and vision model selection stores in /Users/roblibob/Projects/FLX/Minute/Minute/MinuteCore/Sources/MinuteCore/Services/InferenceProviderSelectionStore.swift and /Users/roblibob/Projects/FLX/Minute/Minute/MinuteCore/Sources/MinuteCore/Services/VisionModelSelectionStore.swift
- [x] T009 [P] Extend shared runtime and availability protocols in /Users/roblibob/Projects/FLX/Minute/Minute/MinuteCore/Sources/MinuteCore/Services/ServiceProtocols.swift
- [x] T010 Implement capability-aware runtime resolution in /Users/roblibob/Projects/FLX/Minute/Minute/MinuteCore/Sources/MinuteCore/Services/InferenceRuntimeFactory.swift

**Checkpoint**: Foundation ready - user story implementation can now begin.

---

## Phase 3: User Story 1 - Choose a Summarization Provider and Model During Setup (Priority: P1) 🎯 MVP

**Goal**: Let advanced users choose `Built-in` or `Ollama` plus the summarization model during onboarding, and bind summarization runs to that saved choice.

**Independent Test**: Complete onboarding on a clean profile, choose a summarization provider/model, finish onboarding, and verify a later summarization run uses the saved summarization configuration.

### Tests for User Story 1 (REQUIRED) ⚠️

- [x] T011 [P] [US1] Add failing onboarding summarization-selection coverage in /Users/roblibob/Projects/FLX/Minute/Minute/MinuteTests/OnboardingInferenceProviderTests.swift
- [x] T012 [P] [US1] Add failing summarization runtime-binding coverage in /Users/roblibob/Projects/FLX/Minute/Minute/MinuteCore/Tests/MinuteCoreTests/InferenceRuntimeFactoryTests.swift and /Users/roblibob/Projects/FLX/Minute/Minute/MinuteCore/Tests/MinuteCoreTests/MeetingPipelineCoordinatorTests.swift

### Implementation for User Story 1

- [x] T013 [P] [US1] Implement Ollama-backed summarization runtime in /Users/roblibob/Projects/FLX/Minute/Minute/MinuteCore/Sources/MinuteOllama/Services/OllamaSummarizationService.swift
- [x] T014 [P] [US1] Implement onboarding summarization configuration state in /Users/roblibob/Projects/FLX/Minute/Minute/Minute/Sources/Views/Onboarding/OnboardingViewModel.swift
- [x] T015 [P] [US1] Add onboarding summarization provider/model controls in /Users/roblibob/Projects/FLX/Minute/Minute/Minute/Sources/Views/Onboarding/OnboardingView.swift and /Users/roblibob/Projects/FLX/Minute/Minute/Minute/Sources/Views/Settings/SummarizationProviderPicker.swift
- [x] T016 [US1] Integrate summarization runtime selection into live processing flows in /Users/roblibob/Projects/FLX/Minute/Minute/Minute/Sources/ViewModels/MeetingPipelineViewModel.swift and /Users/roblibob/Projects/FLX/Minute/Minute/Minute/Sources/Views/MeetingNotes/MeetingNotesBrowserViewModel.swift

**Checkpoint**: User Story 1 is independently functional when onboarding can save a summarization provider/model and later summarization uses it.

---

## Phase 4: User Story 2 - Configure Vision Separately From Summarization (Priority: P2)

**Goal**: Let advanced users choose a separate provider/model for vision-based screen-context inference without affecting summarization choices.

**Independent Test**: Configure one provider/model for summarization and a different provider/model for vision, then verify that each capability retains its own selection and uses the correct runtime.

### Tests for User Story 2 (REQUIRED) ⚠️

- [x] T017 [P] [US2] Add failing independent capability-selection coverage in /Users/roblibob/Projects/FLX/Minute/Minute/MinuteTests/ModelsSettingsInferenceProviderTests.swift
- [x] T018 [P] [US2] Add failing vision runtime-binding coverage in /Users/roblibob/Projects/FLX/Minute/Minute/MinuteCore/Tests/MinuteCoreTests/InferenceRuntimeFactoryTests.swift and /Users/roblibob/Projects/FLX/Minute/Minute/MinuteCore/Tests/MinuteCoreTests/ScreenContextCaptureServiceWindowLifecycleTests.swift

### Implementation for User Story 2

- [x] T019 [P] [US2] Implement separate vision configuration persistence in /Users/roblibob/Projects/FLX/Minute/Minute/MinuteCore/Sources/MinuteCore/Services/VisionModelSelectionStore.swift and /Users/roblibob/Projects/FLX/Minute/Minute/MinuteCore/Sources/MinuteCore/Services/InferenceProviderSelectionStore.swift
- [x] T020 [P] [US2] Implement Ollama-backed vision inference runtime in /Users/roblibob/Projects/FLX/Minute/Minute/MinuteCore/Sources/MinuteOllama/Services/OllamaVisionInferenceService.swift
- [x] T021 [P] [US2] Add separate vision configuration controls in /Users/roblibob/Projects/FLX/Minute/Minute/Minute/Sources/Views/Settings/ModelsSettingsViewModel.swift, /Users/roblibob/Projects/FLX/Minute/Minute/Minute/Sources/Views/Settings/ModelsSettingsSection.swift, and /Users/roblibob/Projects/FLX/Minute/Minute/Minute/Sources/Views/Settings/VisionProviderPicker.swift
- [x] T022 [US2] Integrate capability-specific vision runtime selection into screen-context processing in /Users/roblibob/Projects/FLX/Minute/Minute/Minute/Sources/ViewModels/MeetingPipelineViewModel.swift, /Users/roblibob/Projects/FLX/Minute/Minute/MinuteCore/Sources/MinuteCore/Services/ScreenContextCaptureService.swift, and /Users/roblibob/Projects/FLX/Minute/Minute/MinuteCore/Sources/MinuteCore/Services/ScreenContextVideoFrameExtractor.swift
- [x] T023 [US2] Extend onboarding for separate vision configuration in /Users/roblibob/Projects/FLX/Minute/Minute/Minute/Sources/Views/Onboarding/OnboardingViewModel.swift and /Users/roblibob/Projects/FLX/Minute/Minute/Minute/Sources/Views/Onboarding/OnboardingView.swift

**Checkpoint**: User Story 2 is independently functional when summarization and vision can use different saved provider/model selections.

---

## Phase 5: User Story 3 - Adjust Advanced AI Configuration Later in Settings (Priority: P3)

**Goal**: Provide clear settings-time validation, Ollama discovery, and capability-specific error handling for unavailable or invalid provider/model choices.

**Independent Test**: Open settings on an already configured app, select unavailable or invalid Ollama models for summarization or vision, and verify that the app preserves unrelated settings while showing actionable validation feedback.

### Tests for User Story 3 (REQUIRED) ⚠️

- [x] T024 [P] [US3] Add failing Ollama discovery and validation coverage in /Users/roblibob/Projects/FLX/Minute/Minute/MinuteCore/Tests/MinuteCoreTests/OllamaModelDiscoveryServiceTests.swift
- [x] T025 [P] [US3] Add failing settings validation coverage in /Users/roblibob/Projects/FLX/Minute/Minute/MinuteTests/ModelsSettingsInferenceProviderTests.swift and /Users/roblibob/Projects/FLX/Minute/Minute/MinuteTests/MeetingPipelineViewModelScreenContextAlertsTests.swift

### Implementation for User Story 3

- [x] T026 [P] [US3] Implement local Ollama discovery and details lookup in /Users/roblibob/Projects/FLX/Minute/Minute/MinuteCore/Sources/MinuteOllama/Services/OllamaAPIClient.swift and /Users/roblibob/Projects/FLX/Minute/Minute/MinuteCore/Sources/MinuteOllama/Services/OllamaModelDiscoveryService.swift
- [x] T027 [P] [US3] Implement capability availability evaluation and vision-capability rejection in /Users/roblibob/Projects/FLX/Minute/Minute/MinuteCore/Sources/MinuteCore/Domain/CapabilityAvailabilityState.swift and /Users/roblibob/Projects/FLX/Minute/Minute/MinuteCore/Sources/MinuteCore/Services/InferenceRuntimeFactory.swift
- [x] T028 [US3] Surface capability-specific readiness, validation, and refresh actions in /Users/roblibob/Projects/FLX/Minute/Minute/Minute/Sources/Views/Settings/ModelsSettingsViewModel.swift, /Users/roblibob/Projects/FLX/Minute/Minute/Minute/Sources/Views/Settings/ModelsSettingsSection.swift, and /Users/roblibob/Projects/FLX/Minute/Minute/Minute/Sources/Views/Settings/InferenceCapabilityStatusView.swift
- [x] T029 [US3] Surface onboarding validation and preserved-selection feedback in /Users/roblibob/Projects/FLX/Minute/Minute/Minute/Sources/Views/Onboarding/OnboardingViewModel.swift and /Users/roblibob/Projects/FLX/Minute/Minute/Minute/Sources/Views/Onboarding/OnboardingView.swift
- [x] T030 [US3] Freeze immutable provider/model bindings for active summarization and vision tasks in /Users/roblibob/Projects/FLX/Minute/Minute/Minute/Sources/ViewModels/MeetingPipelineViewModel.swift and /Users/roblibob/Projects/FLX/Minute/Minute/MinuteCore/Sources/MinuteCore/Pipeline/MeetingPipelineCoordinator.swift

**Checkpoint**: User Story 3 is independently functional when settings can validate and explain invalid or unavailable advanced AI configurations without breaking saved independent selections.

---

## Phase 6: Polish & Cross-Cutting Concerns

**Purpose**: Final cleanup, documentation, and full-feature validation across stories.

- [x] T031 [P] Update feature validation guidance in /Users/roblibob/Projects/FLX/Minute/Minute/specs/017-ollama-summarization-option/quickstart.md
- [x] T032 [P] Update high-level product documentation for advanced inference configuration in /Users/roblibob/Projects/FLX/Minute/Minute/docs/overview.md
- [x] T033 Record final validation results and coverage notes in /Users/roblibob/Projects/FLX/Minute/Minute/specs/017-ollama-summarization-option/quickstart.md after running `swift test --package-path /Users/roblibob/Projects/FLX/Minute/Minute/MinuteCore` and `xcodebuild -project /Users/roblibob/Projects/FLX/Minute/Minute/Minute.xcodeproj -scheme Minute -configuration Debug test`

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies; start immediately.
- **Foundational (Phase 2)**: Depends on Setup; blocks all user stories.
- **User Story 1 (Phase 3)**: Depends on Foundational; delivers the MVP summarization path.
- **User Story 2 (Phase 4)**: Depends on Foundational; can proceed after Phase 2, though it will integrate more smoothly after US1 runtime-factory work exists.
- **User Story 3 (Phase 5)**: Depends on Foundational; recommended after US1 and US2 because it hardens both capability flows with discovery and validation.
- **Polish (Phase 6)**: Depends on all desired user stories being complete.

### User Story Dependencies

- **US1 (P1)**: No dependency on other stories after Phase 2.
- **US2 (P2)**: No hard dependency on US1 after Phase 2, but it reuses the same runtime-factory infrastructure.
- **US3 (P3)**: No hard dependency on US1/US2 for design purposes, but practically validates and hardens both capability flows and should land after the underlying selections exist.

### Within Each User Story

- Tests MUST be written and fail before implementation.
- Runtime/domain support precedes view-model wiring.
- View-model wiring precedes view updates.
- Processing and coordinator integration happens after provider/model persistence exists.

---

## Parallel Opportunities

- **Setup**: T003 and T004 can run in parallel after T001 and T002 start.
- **Foundational**: T005 and T006 can run in parallel; T008 and T009 can run in parallel after T007 begins.
- **US1**: T011 and T012 can run in parallel; T013 and T014 can run in parallel; T015 can proceed once T014 exists.
- **US2**: T017 and T018 can run in parallel; T019, T020, and T021 can run in parallel; T022 depends on T019 and T020.
- **US3**: T024 and T025 can run in parallel; T026 and T027 can run in parallel; T028 and T029 can run in parallel after T026 and T027.

---

## Parallel Example: User Story 1

```bash
Task: "Add failing onboarding summarization-selection coverage in /Users/roblibob/Projects/FLX/Minute/Minute/MinuteTests/OnboardingInferenceProviderTests.swift"
Task: "Add failing summarization runtime-binding coverage in /Users/roblibob/Projects/FLX/Minute/Minute/MinuteCore/Tests/MinuteCoreTests/InferenceRuntimeFactoryTests.swift and /Users/roblibob/Projects/FLX/Minute/Minute/MinuteCore/Tests/MinuteCoreTests/MeetingPipelineCoordinatorTests.swift"

Task: "Implement Ollama-backed summarization runtime in /Users/roblibob/Projects/FLX/Minute/Minute/MinuteCore/Sources/MinuteOllama/Services/OllamaSummarizationService.swift"
Task: "Implement onboarding summarization configuration state in /Users/roblibob/Projects/FLX/Minute/Minute/Minute/Sources/Views/Onboarding/OnboardingViewModel.swift"
```

## Parallel Example: User Story 2

```bash
Task: "Add failing independent capability-selection coverage in /Users/roblibob/Projects/FLX/Minute/Minute/MinuteTests/ModelsSettingsInferenceProviderTests.swift"
Task: "Add failing vision runtime-binding coverage in /Users/roblibob/Projects/FLX/Minute/Minute/MinuteCore/Tests/MinuteCoreTests/InferenceRuntimeFactoryTests.swift and /Users/roblibob/Projects/FLX/Minute/Minute/MinuteCore/Tests/MinuteCoreTests/ScreenContextCaptureServiceWindowLifecycleTests.swift"

Task: "Implement separate vision configuration persistence in /Users/roblibob/Projects/FLX/Minute/Minute/MinuteCore/Sources/MinuteCore/Services/VisionModelSelectionStore.swift and /Users/roblibob/Projects/FLX/Minute/Minute/MinuteCore/Sources/MinuteCore/Services/InferenceProviderSelectionStore.swift"
Task: "Implement Ollama-backed vision inference runtime in /Users/roblibob/Projects/FLX/Minute/Minute/MinuteCore/Sources/MinuteOllama/Services/OllamaVisionInferenceService.swift"
Task: "Add separate vision configuration controls in /Users/roblibob/Projects/FLX/Minute/Minute/Minute/Sources/Views/Settings/ModelsSettingsViewModel.swift, /Users/roblibob/Projects/FLX/Minute/Minute/Minute/Sources/Views/Settings/ModelsSettingsSection.swift, and /Users/roblibob/Projects/FLX/Minute/Minute/Minute/Sources/Views/Settings/VisionProviderPicker.swift"
```

## Parallel Example: User Story 3

```bash
Task: "Add failing Ollama discovery and validation coverage in /Users/roblibob/Projects/FLX/Minute/Minute/MinuteCore/Tests/MinuteCoreTests/OllamaModelDiscoveryServiceTests.swift"
Task: "Add failing settings validation coverage in /Users/roblibob/Projects/FLX/Minute/Minute/MinuteTests/ModelsSettingsInferenceProviderTests.swift and /Users/roblibob/Projects/FLX/Minute/Minute/MinuteTests/MeetingPipelineViewModelScreenContextAlertsTests.swift"

Task: "Implement local Ollama discovery and details lookup in /Users/roblibob/Projects/FLX/Minute/Minute/MinuteCore/Sources/MinuteOllama/Services/OllamaAPIClient.swift and /Users/roblibob/Projects/FLX/Minute/Minute/MinuteCore/Sources/MinuteOllama/Services/OllamaModelDiscoveryService.swift"
Task: "Implement capability availability evaluation and vision-capability rejection in /Users/roblibob/Projects/FLX/Minute/Minute/MinuteCore/Sources/MinuteCore/Domain/CapabilityAvailabilityState.swift and /Users/roblibob/Projects/FLX/Minute/Minute/MinuteCore/Sources/MinuteCore/Services/InferenceRuntimeFactory.swift"
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Complete Phase 1: Setup.
2. Complete Phase 2: Foundational.
3. Complete Phase 3: User Story 1.
4. Stop and validate onboarding-driven summarization provider/model selection independently.

### Incremental Delivery

1. Setup + Foundational create the shared capability/provider infrastructure.
2. Deliver US1 for onboarding summarization selection and summarization runtime binding.
3. Deliver US2 for independent vision configuration.
4. Deliver US3 for Ollama discovery, validation, and settings hardening.
5. Finish with polish, docs, and full quickstart validation.

### Parallel Team Strategy

1. One developer handles package/runtime scaffolding while another prepares failing tests during Phases 1 and 2.
2. After Phase 2:
   - Developer A: US1 onboarding and summarization runtime tasks.
   - Developer B: US2 vision configuration tasks.
   - Developer C: US3 discovery and validation tasks once the shared stores/factory exist.

---

## Notes

- All tasks use the required checklist format with task ID, optional `[P]`, optional user story label, and exact file paths.
- User stories remain independently testable even though they share foundational runtime-selection infrastructure.
- The recommended MVP scope is **User Story 1 only**.
