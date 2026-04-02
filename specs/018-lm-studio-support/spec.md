# Feature Specification: LM Studio Provider Support

**Feature Branch**: `018-lm-studio-support`  
**Created**: 2026-04-02  
**Status**: Draft  
**Input**: User description: "spec prefix 018 LM Studio support. Just as ollama implementation but for LM Studio."

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Choose LM Studio During AI Setup (Priority: P1)

As an advanced user, I want to choose LM Studio for summarization and for screen-context vision during setup so I can use the local runtime stack I already manage.

**Why this priority**: Setup is the first place advanced users expect to define their preferred inference provider, and LM Studio support has the most value when it is available from first use.

**Independent Test**: Start from a clean app state, enter the setup flow, choose LM Studio for summarization and for vision, provide the required local LM Studio connection and model details, finish setup, and verify those selections are saved for later use.

**Acceptance Scenarios**:

1. **Given** the user is configuring AI behavior during setup, **When** the user opens provider choices for summarization, **Then** `LM Studio` appears alongside the existing local provider options.
2. **Given** the user is configuring AI behavior during setup, **When** the user opens provider choices for screen-context vision, **Then** `LM Studio` appears alongside the existing local provider options.
3. **Given** the user selects `LM Studio` for summarization or vision during setup, **When** the user enters the required local connection and model details and completes setup, **Then** future runs for that capability use the saved LM Studio selection.
4. **Given** the user revisits the setup flow before confirmation, **When** the user changes a provider or model selection, **Then** only the latest selections are saved.

---

### User Story 2 - Manage LM Studio Configuration Later in Settings (Priority: P2)

As an advanced user, I want to switch a capability to LM Studio later in settings and adjust its saved connection or model details without re-running onboarding.

**Why this priority**: Advanced users often refine their local model setup after first launch, so the feature must remain fully manageable after onboarding.

**Independent Test**: Open settings in an already configured app, switch either summarization or vision to LM Studio, adjust the saved local connection or model details, save the change, and verify the chosen capability uses the updated LM Studio selection without altering the other capability.

**Acceptance Scenarios**:

1. **Given** the app has already been configured, **When** the user opens settings, **Then** summarization and vision each expose editable provider and model choices that include `LM Studio`.
2. **Given** the user changes summarization to `LM Studio`, **When** the change is saved, **Then** the saved vision provider and model remain unchanged.
3. **Given** the user changes vision to `LM Studio`, **When** the change is saved, **Then** the saved summarization provider and model remain unchanged.
4. **Given** the user temporarily switches away from `LM Studio`, **When** the user returns to `LM Studio` later, **Then** the previously saved LM Studio details for that capability remain available unless the user replaces them.

---

### User Story 3 - Receive Clear Readiness Feedback for LM Studio (Priority: P3)

As an advanced user, I want clear feedback when LM Studio is unavailable or a chosen model is unsuitable so I can fix the local configuration without guessing.

**Why this priority**: Advanced-provider features fail in practice if users cannot tell whether the local runtime is reachable, correctly configured, or compatible with the task they selected.

**Independent Test**: Configure LM Studio for summarization or vision with an unavailable local connection or an incompatible model, then verify that the app keeps the saved settings, blocks only the affected capability, and shows actionable guidance.

**Acceptance Scenarios**:

1. **Given** the user has selected `LM Studio` for a capability, **When** the app cannot reach the configured local LM Studio runtime, **Then** the app shows a clear message explaining that the local runtime is unavailable and how the user can correct the configuration.
2. **Given** the user has selected `LM Studio` for vision, **When** the chosen LM Studio model cannot support vision work, **Then** the app blocks that vision configuration and explains what needs to change.
3. **Given** an LM Studio configuration is temporarily unavailable, **When** the local runtime becomes available again, **Then** the app can use the saved LM Studio selection without requiring the user to enter it again.

### Edge Cases

- A user upgrades from a version that supports `Built-in` and `Ollama` only and must keep their existing behavior unless they actively choose `LM Studio`.
- Summarization uses `LM Studio` while vision uses `Built-in` or `Ollama`, and each capability must remain independently editable.
- Vision uses `LM Studio` while summarization stays on another provider, and the app must validate only the affected capability.
- The saved LM Studio connection becomes unavailable between app launches, but the user must still be able to open settings and correct it.
- A selected LM Studio model is no longer available locally, and the app must explain the issue without discarding the user's saved choice.
- The user changes LM Studio settings while summarization or vision work is already in progress; the active work must keep its starting configuration and later work must use the updated one.
- Adding LM Studio must not change transcription behavior or the deterministic three-file meeting output contract.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The system MUST offer `LM Studio` as a provider option for summarization.
- **FR-002**: The system MUST offer `LM Studio` as a provider option for screen-context vision.
- **FR-003**: The setup flow MUST present `LM Studio` anywhere users currently choose a local provider for summarization or vision.
- **FR-004**: Settings MUST present `LM Studio` anywhere users currently choose a local provider for summarization or vision.
- **FR-005**: The system MUST let users save the local LM Studio connection details needed to reach their LM Studio runtime.
- **FR-006**: The system MUST let users save the LM Studio model selection separately for summarization and for vision.
- **FR-007**: The system MUST persist LM Studio choices independently from `Built-in` and `Ollama` choices so switching one capability does not overwrite another capability's saved selection.
- **FR-008**: The system MUST preserve existing `Built-in` and `Ollama` behavior for users who do not choose `LM Studio`.
- **FR-009**: The system MUST assign non-disruptive defaults for upgraded users so existing summarization and vision behavior remains unchanged after LM Studio support is added.
- **FR-010**: The system MUST show which provider and model are currently active for summarization and which are currently active for vision.
- **FR-011**: The system MUST validate whether the saved LM Studio configuration is currently usable for the selected capability.
- **FR-012**: The system MUST provide actionable user-facing guidance when the saved LM Studio runtime cannot be reached.
- **FR-013**: The system MUST provide actionable user-facing guidance when the selected LM Studio model is unavailable for the chosen capability.
- **FR-014**: The system MUST prevent a vision configuration from proceeding when the selected LM Studio model cannot perform vision work.
- **FR-015**: The system MUST allow users to change summarization provider or model without changing vision provider or model.
- **FR-016**: The system MUST allow users to change vision provider or model without changing summarization provider or model.
- **FR-017**: The system MUST preserve previously entered LM Studio details for a capability when the user switches that capability to another provider and later returns to LM Studio.
- **FR-018**: A summarization run already in progress MUST keep the provider and model it started with even if the user changes summarization settings before the run completes.
- **FR-019**: A screen-context vision task already in progress MUST keep the provider and model it started with even if the user changes vision settings before the task completes.
- **FR-020**: New summarization runs started after a configuration change MUST use the most recently saved summarization provider and model.
- **FR-021**: New screen-context vision tasks started after a configuration change MUST use the most recently saved vision provider and model.
- **FR-022**: The system MUST keep LM Studio configuration local to the device and MUST NOT require a cloud account or hosted service.
- **FR-023**: The configuration experience MUST continue to distinguish summarization, vision, and transcription so users do not confuse the three responsibilities.
- **FR-024**: The system MUST continue to support reprocessing or later note generation using the currently saved summarization provider and model, including when that provider is `LM Studio`.
- **FR-025**: If screen context is disabled, the system MUST preserve the saved LM Studio vision configuration for later use without affecting summarization behavior.

### Non-Functional Requirements *(mandatory)*

- **NFR-001**: The feature MUST preserve local-only processing and avoid outbound network calls except model downloads explicitly initiated for supported local runtimes.
- **NFR-002**: The feature MUST preserve deterministic note rendering and the existing three-file meeting output contract regardless of whether summarization or vision uses `Built-in`, `Ollama`, or `LM Studio`.
- **NFR-003**: Provider validation, switching, and readiness checks MUST keep the app responsive and MUST NOT block primary user interactions.
- **NFR-004**: User-facing LM Studio status and error messages MUST be concise, actionable, and must not expose raw transcript content or raw captured images by default.
- **NFR-005**: The setup and settings experience MUST remain consistent with the app's existing information architecture and predictable macOS UX expectations.

### Key Entities *(include if feature involves data)*

- **Inference Capability**: A configurable AI task category, either `summarization` or `vision`, each with its own provider and model selection.
- **Inference Provider**: A user-selectable local runtime option, including `Built-in`, `Ollama`, and `LM Studio`, used for one inference capability.
- **Local Provider Configuration**: The saved local connection and model details needed for one capability to use a selected provider.
- **Capability Readiness State**: The current availability and compatibility status for a capability's saved provider and model selection.
- **Inference Run Context**: The per-task record of which provider and model were resolved when a summarization or vision task began.

## Assumptions

- LM Studio is treated as a local-first runtime option managed by the user, similar to other advanced local provider choices.
- This feature extends the existing advanced provider workflow rather than replacing `Built-in` or `Ollama`.
- Users who choose LM Studio are comfortable providing the local connection and model details required for their setup.
- This feature covers provider selection, validation, persistence, and runtime choice, not changes to note structure, prompts, or vault file layout.

## Dependencies

- Existing onboarding and settings flows must continue to support separate configuration for summarization and vision.
- The summarization and vision pipelines must continue to resolve provider and model choice at task start so in-flight work remains stable.
- User-managed LM Studio installation, model availability, and local runtime setup remain outside Minute's direct control.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: In acceptance testing, 100% of clean-install users can find and select `LM Studio` for summarization during setup without leaving the AI configuration flow.
- **SC-002**: In acceptance testing, 100% of clean-install users can find and select `LM Studio` for vision during setup without leaving the AI configuration flow.
- **SC-003**: In acceptance testing, 100% of existing users can switch either summarization or vision to `LM Studio` from settings in 45 seconds or less.
- **SC-004**: In validation testing, 100% of unavailable or incompatible LM Studio configurations produce an actionable user-facing message before or at task start.
- **SC-005**: In migration testing, 100% of upgraded users retain their pre-existing summarization and vision behavior until they actively choose `LM Studio`.
- **SC-006**: In concurrency testing, 100% of in-progress summarization and vision tasks complete with the provider and model they started with even if the user changes settings mid-task.
- **SC-007**: In usability validation, at least 90% of advanced test users correctly distinguish summarization, vision, and transcription configuration on first attempt after LM Studio is added.
- **SC-008**: In release QA, adding LM Studio introduces zero regressions to the deterministic three-file vault output contract for processed meetings.
