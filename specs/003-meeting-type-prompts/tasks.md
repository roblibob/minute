# Implementation Tasks: Meeting Type Prompts

**Branch**: `003-meeting-type-prompts`
**Spec**: [specs/003-meeting-type-prompts/spec.md](specs/003-meeting-type-prompts/spec.md)

## Phase 1: Setup

- [x] T001 Create prompt strategies directory structure in `MinuteCore/Sources/MinuteCore/Summarization/Prompts/Strategies/`

## Phase 2: Foundational (Blocking Prerequisites)

- [x] T002 Define `MeetingType` enum in `MinuteCore/Sources/MinuteCore/Domain/MeetingType.swift`
- [x] T003 Define `PromptStrategy` protocol in `MinuteCore/Sources/MinuteCore/Summarization/Prompts/PromptStrategy.swift`

## Phase 3: User Story 1 - Tailored Summaries via Meeting Type

**Goal**: Enable users to select meeting types and receive tailored summaries.

### Models & Strategies
- [x] T004 [P] [US1] Implement `GeneralPromptStrategy` in `MinuteCore/Sources/MinuteCore/Summarization/Prompts/Strategies/GeneralPromptStrategy.swift`
- [x] T005 [P] [US1] Implement `StandupPromptStrategy` in `MinuteCore/Sources/MinuteCore/Summarization/Prompts/Strategies/StandupPromptStrategy.swift`
- [x] T006 [P] [US1] Implement `PresentationPromptStrategy` in `MinuteCore/Sources/MinuteCore/Summarization/Prompts/Strategies/PresentationPromptStrategy.swift`
- [x] T007 [P] [US1] Implement `DesignReviewPromptStrategy` in `MinuteCore/Sources/MinuteCore/Summarization/Prompts/Strategies/DesignReviewPromptStrategy.swift`
- [x] T008 [P] [US1] Implement `OneOnOnePromptStrategy` in `MinuteCore/Sources/MinuteCore/Summarization/Prompts/Strategies/OneOnOnePromptStrategy.swift`
- [x] T009 [P] [US1] Implement `PlanningPromptStrategy` in `MinuteCore/Sources/MinuteCore/Summarization/Prompts/Strategies/PlanningPromptStrategy.swift`
- [x] T010 [US1] Implement `PromptFactory` in `MinuteCore/Sources/MinuteCore/Summarization/Prompts/PromptFactory.swift`

### Services
- [x] T011 [US1] Implement `MeetingTypeClassifier` for autodetect logic in `MinuteCore/Sources/MinuteCore/Summarization/Services/MeetingTypeClassifier.swift`
- [x] T012 [US1] Update `LlamaLibrarySummarizationService` to use strategies in `MinuteCore/Sources/MinuteLlama/Services/LlamaLibrarySummarizationService.swift`

### UI & Integration
- [x] T013 [US1] Create `MeetingTypePicker` component in `Minute/Sources/Components/MeetingTypePicker.swift`
- [x] T014 [US1] Update `RecorderViewModel` with state and persistence in `Minute/Sources/ViewModels/RecorderViewModel.swift`
- [x] T015 [US1] Integrate picker into `RecorderView` in `Minute/Sources/Views/RecorderView.swift`

### Testing
- [x] T016 [US1] Add unit tests for prompt generation in `MinuteTests/PromptTests.swift`

## Phase 4: Polish

- [x] T017 Verify all meeting type prompts produce valid JSON output manually
- [x] T018 Check backward compatibility with existing meeting files

## Dependencies

- All tasks in Phase 2 must be completed before Phase 3 tasks.
- Service updates (T011, T012) depend on Factory (T010).
- UI tasks (T013-T015) can theoretically run in parallel with Strategy implementation, but depend on `MeetingType` enum (T002).

## Implementation Strategy

1.  **Foundation**: Establish the `MeetingType` and `PromptStrategy` contract.
2.  **Strategies**: Port the existing prompt to `GeneralPromptStrategy` first to ensure no regression, then add others.
3.  **Service**: Refactor the service to use the factory.
4.  **UI**: Hook up the UI to drive the new service parameter.
