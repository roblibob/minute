# Tasks: LM Studio Provider Support

**Input**: Design documents from `/Users/roblibob/Projects/FLX/Minute/Minute/specs/018-lm-studio-support/`
**Prerequisites**: `/Users/roblibob/Projects/FLX/Minute/Minute/specs/018-lm-studio-support/plan.md`, `/Users/roblibob/Projects/FLX/Minute/Minute/specs/018-lm-studio-support/spec.md`, `/Users/roblibob/Projects/FLX/Minute/Minute/specs/018-lm-studio-support/research.md`, `/Users/roblibob/Projects/FLX/Minute/Minute/specs/018-lm-studio-support/data-model.md`, `/Users/roblibob/Projects/FLX/Minute/Minute/specs/018-lm-studio-support/contracts/openapi.yaml`

**Tests**: Tests are REQUIRED for this feature because the Minute constitution requires TDD and this feature changes `MinuteCore`, runtime-selection contracts, provider persistence, and deterministic-output safety.

**Organization**: Tasks are grouped by user story so each story can be implemented and validated independently.

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Wire the package and project structure for the new LM Studio runtime surface.

- [X] T001 Update package target and product wiring for `MinuteLMStudio` in `/Users/roblibob/Projects/FLX/Minute/Minute/MinuteCore/Package.swift`
- [X] T002 Update app target package references for `MinuteLMStudio` in `/Users/roblibob/Projects/FLX/Minute/Minute/Minute.xcodeproj/project.pbxproj`
- [X] T003 [P] Create LM Studio runtime service scaffolding in `/Users/roblibob/Projects/FLX/Minute/Minute/MinuteCore/Sources/MinuteLMStudio/Services/LMStudioAPIClient.swift`, `/Users/roblibob/Projects/FLX/Minute/Minute/MinuteCore/Sources/MinuteLMStudio/Services/LMStudioModelDiscoveryService.swift`, `/Users/roblibob/Projects/FLX/Minute/Minute/MinuteCore/Sources/MinuteLMStudio/Services/LMStudioSummarizationService.swift`, and `/Users/roblibob/Projects/FLX/Minute/Minute/MinuteCore/Sources/MinuteLMStudio/Services/LMStudioVisionInferenceService.swift`
- [X] T004 [P] Create provider-neutral LM Studio scaffolding in `/Users/roblibob/Projects/FLX/Minute/Minute/MinuteCore/Sources/MinuteCore/Domain/LMStudioModelDescriptor.swift` and `/Users/roblibob/Projects/FLX/Minute/Minute/MinuteCore/Sources/MinuteCore/Services/ProviderConnectionSettingsStore.swift`

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Establish shared provider, persistence, and runtime infrastructure that MUST be complete before any user story work begins.

**⚠️ CRITICAL**: No user story work should begin until this phase is complete.

- [X] T005 [P] Add failing provider-expansion and migration coverage in `/Users/roblibob/Projects/FLX/Minute/Minute/MinuteCore/Tests/MinuteCoreTests/AppConfigurationTests.swift` and `/Users/roblibob/Projects/FLX/Minute/Minute/MinuteCore/Tests/MinuteCoreTests/InferenceProviderSelectionStoreTests.swift`
- [ ] T006 [P] Add failing runtime-binding and reprocessing coverage in `/Users/roblibob/Projects/FLX/Minute/Minute/MinuteCore/Tests/MinuteCoreTests/InferenceRuntimeFactoryTests.swift` and `/Users/roblibob/Projects/FLX/Minute/Minute/MinuteCore/Tests/MinuteCoreTests/MeetingPipelineCoordinatorReprocessingTests.swift`
- [X] T007 [P] Add failing deterministic-output and model-manager regression coverage in `/Users/roblibob/Projects/FLX/Minute/Minute/MinuteCore/Tests/MinuteCoreTests/OutputContractCoverageTests.swift` and `/Users/roblibob/Projects/FLX/Minute/Minute/MinuteCore/Tests/MinuteCoreTests/DefaultModelManagerTests.swift`
- [X] T008 Extend the shared provider catalog and readiness statuses for `LM Studio` in `/Users/roblibob/Projects/FLX/Minute/Minute/MinuteCore/Sources/MinuteCore/Domain/InferenceProvider.swift` and `/Users/roblibob/Projects/FLX/Minute/Minute/MinuteCore/Sources/MinuteCore/Domain/CapabilityAvailabilityState.swift`
- [X] T009 Implement LM Studio defaults and provider-connection persistence in `/Users/roblibob/Projects/FLX/Minute/Minute/MinuteCore/Sources/MinuteCore/Configuration/AppConfiguration.swift`, `/Users/roblibob/Projects/FLX/Minute/Minute/MinuteCore/Sources/MinuteCore/Services/InferenceProviderSelectionStore.swift`, and `/Users/roblibob/Projects/FLX/Minute/Minute/MinuteCore/Sources/MinuteCore/Services/ProviderConnectionSettingsStore.swift`
- [ ] T010 [P] Extend shared provider protocols, default-model orchestration, and base LM Studio client support in `/Users/roblibob/Projects/FLX/Minute/Minute/MinuteCore/Sources/MinuteCore/Services/ServiceProtocols.swift`, `/Users/roblibob/Projects/FLX/Minute/Minute/MinuteCore/Sources/MinuteCore/Services/DefaultModelManager.swift`, and `/Users/roblibob/Projects/FLX/Minute/Minute/MinuteCore/Sources/MinuteLMStudio/Services/LMStudioAPIClient.swift`
- [ ] T011 Implement LM Studio task-binding and runtime-resolution paths in `/Users/roblibob/Projects/FLX/Minute/Minute/MinuteCore/Sources/MinuteCore/Services/InferenceRuntimeFactory.swift` and `/Users/roblibob/Projects/FLX/Minute/Minute/MinuteCore/Sources/MinuteCore/Pipeline/MeetingPipelineCoordinator.swift`

**Checkpoint**: Foundation ready. User story implementation can now begin.

---

## Phase 3: User Story 1 - Choose LM Studio During AI Setup (Priority: P1) 🎯 MVP

**Goal**: Let advanced users choose `LM Studio` for summarization and vision during onboarding and ensure later summarization runs use the saved LM Studio summarization selection.

**Independent Test**: Start from a clean app state, complete onboarding with `LM Studio` selected for summarization and vision, and verify that the saved summarization provider/model are used by a later summarization run.

### Tests for User Story 1 (REQUIRED) ⚠️

> **NOTE: Write these tests first, ensure they fail before implementation.**

- [X] T012 [P] [US1] Add failing onboarding LM Studio selection coverage in `/Users/roblibob/Projects/FLX/Minute/Minute/MinuteTests/OnboardingInferenceProviderTests.swift`
- [X] T013 [P] [US1] Add failing LM Studio summarization binding coverage in `/Users/roblibob/Projects/FLX/Minute/Minute/MinuteCore/Tests/MinuteCoreTests/InferenceRuntimeFactoryTests.swift` and `/Users/roblibob/Projects/FLX/Minute/Minute/MinuteCore/Tests/MinuteCoreTests/MeetingPipelineCoordinatorTests.swift`

### Implementation for User Story 1

- [X] T014 [P] [US1] Implement LM Studio summarization service mapping in `/Users/roblibob/Projects/FLX/Minute/Minute/MinuteCore/Sources/MinuteLMStudio/Services/LMStudioSummarizationService.swift`
- [X] T015 [P] [US1] Add onboarding LM Studio provider, connection, and model state in `/Users/roblibob/Projects/FLX/Minute/Minute/Minute/Sources/Views/Onboarding/OnboardingViewModel.swift`
- [X] T016 [P] [US1] Add onboarding LM Studio controls and copy in `/Users/roblibob/Projects/FLX/Minute/Minute/Minute/Sources/Views/Onboarding/OnboardingView.swift`
- [X] T017 [US1] Integrate saved LM Studio summarization binding into processing and reprocessing flows in `/Users/roblibob/Projects/FLX/Minute/Minute/Minute/Sources/ViewModels/MeetingPipelineViewModel.swift` and `/Users/roblibob/Projects/FLX/Minute/Minute/Minute/Sources/Views/MeetingNotes/MeetingNotesBrowserViewModel.swift`

**Checkpoint**: User Story 1 is complete when onboarding can save LM Studio selections and later summarization uses the saved LM Studio configuration.

---

## Phase 4: User Story 2 - Manage LM Studio Configuration Later in Settings (Priority: P2)

**Goal**: Let users switch summarization or vision to `LM Studio` in settings, keep capability settings independent, and preserve LM Studio selections when they switch providers.

**Independent Test**: Open settings in an already configured app, change either summarization or vision to `LM Studio`, save a local connection and model, and verify that the changed capability updates without overwriting the other capability.

### Tests for User Story 2 (REQUIRED) ⚠️

- [X] T018 [P] [US2] Add failing settings LM Studio persistence coverage in `/Users/roblibob/Projects/FLX/Minute/Minute/MinuteTests/ModelsSettingsInferenceProviderTests.swift` and `/Users/roblibob/Projects/FLX/Minute/Minute/MinuteCore/Tests/MinuteCoreTests/AppConfigurationTests.swift`
- [ ] T019 [P] [US2] Add failing independent capability and reprocessing coverage in `/Users/roblibob/Projects/FLX/Minute/Minute/MinuteTests/MeetingNotesBrowserViewModelReprocessingTests.swift` and `/Users/roblibob/Projects/FLX/Minute/Minute/MinuteCore/Tests/MinuteCoreTests/InferenceRuntimeFactoryTests.swift`

### Implementation for User Story 2

- [X] T020 [P] [US2] Implement LM Studio vision service mapping in `/Users/roblibob/Projects/FLX/Minute/Minute/MinuteCore/Sources/MinuteLMStudio/Services/LMStudioVisionInferenceService.swift`
- [X] T021 [P] [US2] Add settings LM Studio provider, connection, and preserved-selection state in `/Users/roblibob/Projects/FLX/Minute/Minute/Minute/Sources/Views/Settings/ModelsSettingsViewModel.swift` and `/Users/roblibob/Projects/FLX/Minute/Minute/Minute/Sources/Views/Settings/ModelsSettingsSection.swift`
- [X] T022 [P] [US2] Add settings LM Studio controls for summarization and vision in `/Users/roblibob/Projects/FLX/Minute/Minute/Minute/Sources/Views/Settings/SummarizationProviderPicker.swift`, `/Users/roblibob/Projects/FLX/Minute/Minute/Minute/Sources/Views/Settings/VisionProviderPicker.swift`, and `/Users/roblibob/Projects/FLX/Minute/Minute/Minute/Sources/Views/Settings/SettingsFieldComponents.swift`
- [X] T023 [US2] Wire settings-driven LM Studio selection into screen-context and reprocessing flows in `/Users/roblibob/Projects/FLX/Minute/Minute/Minute/Sources/ViewModels/MeetingPipelineViewModel.swift` and `/Users/roblibob/Projects/FLX/Minute/Minute/Minute/Sources/Views/MeetingNotes/MeetingNotesBrowserViewModel.swift`
- [X] T024 [US2] Preserve per-capability LM Studio selections when switching providers in `/Users/roblibob/Projects/FLX/Minute/Minute/MinuteCore/Sources/MinuteCore/Services/InferenceProviderSelectionStore.swift` and `/Users/roblibob/Projects/FLX/Minute/Minute/Minute/Sources/Views/Settings/ModelsSettingsViewModel.swift`

**Checkpoint**: User Story 2 is complete when settings can manage LM Studio for either capability without disturbing the other capability.

---

## Phase 5: User Story 3 - Receive Clear Readiness Feedback for LM Studio (Priority: P3)

**Goal**: Discover local LM Studio models, validate readiness, reject incompatible vision models, and surface actionable recovery guidance without leaking internal errors.

**Independent Test**: Configure LM Studio for summarization or vision with an unavailable local server or an incompatible model, then verify that the app keeps the saved settings, blocks only the affected capability, and shows actionable guidance.

### Tests for User Story 3 (REQUIRED) ⚠️

- [X] T025 [P] [US3] Add failing LM Studio discovery and validation coverage in `/Users/roblibob/Projects/FLX/Minute/Minute/MinuteCore/Tests/MinuteCoreTests/LMStudioAPIClientTests.swift` and `/Users/roblibob/Projects/FLX/Minute/Minute/MinuteCore/Tests/MinuteCoreTests/LMStudioModelDiscoveryServiceTests.swift`
- [X] T026 [P] [US3] Add failing readiness and alert coverage in `/Users/roblibob/Projects/FLX/Minute/Minute/MinuteTests/ModelsSettingsInferenceProviderTests.swift`, `/Users/roblibob/Projects/FLX/Minute/Minute/MinuteTests/OnboardingInferenceProviderTests.swift`, and `/Users/roblibob/Projects/FLX/Minute/Minute/MinuteTests/MeetingPipelineViewModelScreenContextAlertsTests.swift`

### Implementation for User Story 3

- [X] T027 [P] [US3] Implement LM Studio discovery endpoints and model metadata mapping in `/Users/roblibob/Projects/FLX/Minute/Minute/MinuteCore/Sources/MinuteLMStudio/Services/LMStudioAPIClient.swift`, `/Users/roblibob/Projects/FLX/Minute/Minute/MinuteCore/Sources/MinuteLMStudio/Services/LMStudioModelDiscoveryService.swift`, and `/Users/roblibob/Projects/FLX/Minute/Minute/MinuteCore/Sources/MinuteCore/Domain/LMStudioModelDescriptor.swift`
- [X] T028 [P] [US3] Implement LM Studio capability validation and readiness-state evaluation in `/Users/roblibob/Projects/FLX/Minute/Minute/MinuteCore/Sources/MinuteCore/Services/InferenceRuntimeFactory.swift` and `/Users/roblibob/Projects/FLX/Minute/Minute/MinuteCore/Sources/MinuteCore/Domain/CapabilityAvailabilityState.swift`
- [X] T029 [US3] Surface settings readiness, refresh, and validation feedback in `/Users/roblibob/Projects/FLX/Minute/Minute/Minute/Sources/Views/Settings/ModelsSettingsViewModel.swift`, `/Users/roblibob/Projects/FLX/Minute/Minute/Minute/Sources/Views/Settings/ModelsSettingsSection.swift`, and `/Users/roblibob/Projects/FLX/Minute/Minute/Minute/Sources/Views/Settings/InferenceCapabilityStatusView.swift`
- [X] T030 [US3] Surface onboarding readiness and recovery feedback in `/Users/roblibob/Projects/FLX/Minute/Minute/Minute/Sources/Views/Onboarding/OnboardingViewModel.swift` and `/Users/roblibob/Projects/FLX/Minute/Minute/Minute/Sources/Views/Onboarding/OnboardingView.swift`
- [ ] T031 [US3] Keep active summarization and vision tasks pinned to their starting LM Studio binding in `/Users/roblibob/Projects/FLX/Minute/Minute/Minute/Sources/ViewModels/MeetingPipelineViewModel.swift`, `/Users/roblibob/Projects/FLX/Minute/Minute/MinuteCore/Sources/MinuteCore/Pipeline/MeetingPipelineCoordinator.swift`, and `/Users/roblibob/Projects/FLX/Minute/Minute/MinuteCore/Sources/MinuteCore/Services/ScreenContextCaptureService.swift`

**Checkpoint**: User Story 3 is complete when LM Studio readiness failures are validated and explained cleanly without breaking saved configuration or in-flight work.

---

## Phase 6: Polish & Cross-Cutting Concerns

**Purpose**: Finish documentation, validate contract alignment, and record full regression results.

- [X] T032 [P] Update feature validation guidance and product documentation in `/Users/roblibob/Projects/FLX/Minute/Minute/specs/018-lm-studio-support/quickstart.md` and `/Users/roblibob/Projects/FLX/Minute/Minute/docs/overview.md`
- [X] T033 [P] Reconcile internal contract and data-model docs with the implemented provider flows in `/Users/roblibob/Projects/FLX/Minute/Minute/specs/018-lm-studio-support/contracts/openapi.yaml` and `/Users/roblibob/Projects/FLX/Minute/Minute/specs/018-lm-studio-support/data-model.md`
- [X] T034 Run regression validation commands and record results in `/Users/roblibob/Projects/FLX/Minute/Minute/specs/018-lm-studio-support/quickstart.md` after executing `swift test --package-path /Users/roblibob/Projects/FLX/Minute/Minute/MinuteCore` and `xcodebuild -project /Users/roblibob/Projects/FLX/Minute/Minute/Minute.xcodeproj -scheme Minute -configuration Debug test`

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies. Start immediately.
- **Foundational (Phase 2)**: Depends on Setup. Blocks all user stories.
- **User Story 1 (Phase 3)**: Depends on Foundational. This is the MVP.
- **User Story 2 (Phase 4)**: Depends on Foundational. It can begin after Phase 2, but it reuses the shared LM Studio provider infrastructure from Phase 2.
- **User Story 3 (Phase 5)**: Depends on Foundational. It is best completed after US1 and US2 because it hardens both onboarding and settings flows.
- **Polish (Phase 6)**: Depends on all desired user stories being complete.

### User Story Dependencies

- **US1 (P1)**: No dependency on other stories after Phase 2.
- **US2 (P2)**: No hard dependency on US1 after Phase 2, but it assumes the shared LM Studio provider infrastructure already exists.
- **US3 (P3)**: No hard dependency on US1 or US2 by design, but practically validates and hardens the flows delivered by both stories.

### Within Each User Story

- Tests MUST be written and fail before implementation.
- Shared provider/runtime updates must land before UI wiring that depends on them.
- View-model changes must precede view changes.
- Processing and pipeline integration happen after persistence and service resolution exist.

---

## Parallel Opportunities

- **Setup**: T003 and T004 can run in parallel after T001 and T002 are underway.
- **Foundational**: T005, T006, and T007 can run in parallel; T009 and T010 can run in parallel after T008 defines the shared provider surface.
- **US1**: T012 and T013 can run in parallel; T014 and T015 can run in parallel; T016 follows T015.
- **US2**: T018 and T019 can run in parallel; T020, T021, and T022 can run in parallel; T023 depends on T020 and T021; T024 depends on T021.
- **US3**: T025 and T026 can run in parallel; T027 and T028 can run in parallel; T029 and T030 depend on T027 and T028.
- **Polish**: T032 and T033 can run in parallel once implementation is stable.

---

## Parallel Example: User Story 1

```bash
Task: "Add failing onboarding LM Studio selection coverage in /Users/roblibob/Projects/FLX/Minute/Minute/MinuteTests/OnboardingInferenceProviderTests.swift"
Task: "Add failing LM Studio summarization binding coverage in /Users/roblibob/Projects/FLX/Minute/Minute/MinuteCore/Tests/MinuteCoreTests/InferenceRuntimeFactoryTests.swift and /Users/roblibob/Projects/FLX/Minute/Minute/MinuteCore/Tests/MinuteCoreTests/MeetingPipelineCoordinatorTests.swift"

Task: "Implement LM Studio summarization service mapping in /Users/roblibob/Projects/FLX/Minute/Minute/MinuteCore/Sources/MinuteLMStudio/Services/LMStudioSummarizationService.swift"
Task: "Add onboarding LM Studio provider, connection, and model state in /Users/roblibob/Projects/FLX/Minute/Minute/Minute/Sources/Views/Onboarding/OnboardingViewModel.swift"
```

## Parallel Example: User Story 2

```bash
Task: "Add failing settings LM Studio persistence coverage in /Users/roblibob/Projects/FLX/Minute/Minute/MinuteTests/ModelsSettingsInferenceProviderTests.swift and /Users/roblibob/Projects/FLX/Minute/Minute/MinuteCore/Tests/MinuteCoreTests/AppConfigurationTests.swift"
Task: "Add failing independent capability and reprocessing coverage in /Users/roblibob/Projects/FLX/Minute/Minute/MinuteTests/MeetingNotesBrowserViewModelReprocessingTests.swift and /Users/roblibob/Projects/FLX/Minute/Minute/MinuteCore/Tests/MinuteCoreTests/InferenceRuntimeFactoryTests.swift"

Task: "Implement LM Studio vision service mapping in /Users/roblibob/Projects/FLX/Minute/Minute/MinuteCore/Sources/MinuteLMStudio/Services/LMStudioVisionInferenceService.swift"
Task: "Add settings LM Studio provider, connection, and preserved-selection state in /Users/roblibob/Projects/FLX/Minute/Minute/Minute/Sources/Views/Settings/ModelsSettingsViewModel.swift and /Users/roblibob/Projects/FLX/Minute/Minute/Minute/Sources/Views/Settings/ModelsSettingsSection.swift"
Task: "Add settings LM Studio controls for summarization and vision in /Users/roblibob/Projects/FLX/Minute/Minute/Minute/Sources/Views/Settings/SummarizationProviderPicker.swift, /Users/roblibob/Projects/FLX/Minute/Minute/Minute/Sources/Views/Settings/VisionProviderPicker.swift, and /Users/roblibob/Projects/FLX/Minute/Minute/Minute/Sources/Views/Settings/SettingsFieldComponents.swift"
```

## Parallel Example: User Story 3

```bash
Task: "Add failing LM Studio discovery and validation coverage in /Users/roblibob/Projects/FLX/Minute/Minute/MinuteCore/Tests/MinuteCoreTests/LMStudioAPIClientTests.swift and /Users/roblibob/Projects/FLX/Minute/Minute/MinuteCore/Tests/MinuteCoreTests/LMStudioModelDiscoveryServiceTests.swift"
Task: "Add failing readiness and alert coverage in /Users/roblibob/Projects/FLX/Minute/Minute/MinuteTests/ModelsSettingsInferenceProviderTests.swift, /Users/roblibob/Projects/FLX/Minute/Minute/MinuteTests/OnboardingInferenceProviderTests.swift, and /Users/roblibob/Projects/FLX/Minute/Minute/MinuteTests/MeetingPipelineViewModelScreenContextAlertsTests.swift"

Task: "Implement LM Studio discovery endpoints and model metadata mapping in /Users/roblibob/Projects/FLX/Minute/Minute/MinuteCore/Sources/MinuteLMStudio/Services/LMStudioAPIClient.swift, /Users/roblibob/Projects/FLX/Minute/Minute/MinuteCore/Sources/MinuteLMStudio/Services/LMStudioModelDiscoveryService.swift, and /Users/roblibob/Projects/FLX/Minute/Minute/MinuteCore/Sources/MinuteCore/Domain/LMStudioModelDescriptor.swift"
Task: "Implement LM Studio capability validation and readiness-state evaluation in /Users/roblibob/Projects/FLX/Minute/Minute/MinuteCore/Sources/MinuteCore/Services/InferenceRuntimeFactory.swift and /Users/roblibob/Projects/FLX/Minute/Minute/MinuteCore/Sources/MinuteCore/Domain/CapabilityAvailabilityState.swift"
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Complete Phase 1: Setup.
2. Complete Phase 2: Foundational.
3. Complete Phase 3: User Story 1.
4. Stop and validate onboarding-driven LM Studio selection independently.

### Incremental Delivery

1. Setup and Foundational establish the shared provider, persistence, and runtime infrastructure.
2. Deliver US1 to make LM Studio selectable and usable from onboarding.
3. Deliver US2 to make LM Studio fully manageable from settings and reprocessing flows.
4. Deliver US3 to harden discovery, readiness, validation, and error handling.
5. Finish with documentation alignment and full regression validation.

### Parallel Team Strategy

1. One developer handles package/runtime scaffolding while another writes failing tests during Phases 1 and 2.
2. After Phase 2:
   - Developer A: US1 onboarding and summarization tasks.
   - Developer B: US2 settings and vision tasks.
   - Developer C: US3 discovery and readiness tasks after the shared LM Studio client exists.

---

## Notes

- All tasks follow the required checklist format: checkbox, task ID, optional `[P]`, required `[US#]` label for story tasks, and exact file paths.
- The recommended MVP scope is **User Story 1 only**.
- Each user story remains independently testable once Phase 2 is complete.
