# Feature Specification: Advanced Inference Provider Options

**Feature Branch**: `017-ollama-summarization-option`  
**Created**: 2026-03-24  
**Status**: Draft  
**Input**: User description: "Create a specification with prefix 017. As an advanced user I want an option to use Ollama for summarizations instead of llama.cpp. The option should be surfaced in both wizard and settings." Follow-up direction: "Since we are talking about advanced users, perhaps it is better to leave the configuration up to them. Perhaps we need to separate the model choice for vision and summarization. The user could choose a built-in model or Ollama."

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Choose a Summarization Provider and Model During Setup (Priority: P1)

As an advanced user, I want to choose which provider and model Minute uses for summarization during setup so I can align summary generation with the local runtime stack I prefer.

**Why this priority**: First-run setup is where advanced users expect to make AI-runtime decisions, and summarization is the primary workflow affected by this feature.

**Independent Test**: Complete the setup wizard on a clean app state, choose each available summarization provider in turn, select a model for that provider, and verify that the selected summarization configuration is saved and used for later summarization runs.

**Acceptance Scenarios**:

1. **Given** the user is in the setup wizard, **When** the user reaches AI configuration, **Then** the wizard presents summarization choices that include both `Built-in` and `Ollama`.
2. **Given** the user selects `Built-in` for summarization, **When** the user chooses a built-in summarization model and completes setup, **Then** future summarization runs use that built-in model.
3. **Given** the user selects `Ollama` for summarization, **When** the user chooses or enters an Ollama model tag and completes setup, **Then** future summarization runs use that Ollama model.
4. **Given** the user revisits the setup flow before final confirmation, **When** the user changes the summarization provider or model selection, **Then** the latest summarization selection is the one that is saved.

---

### User Story 2 - Configure Vision Separately From Summarization (Priority: P2)

As an advanced user, I want to configure vision and screen-context inference separately from summarization so I can choose the best local runtime for each task.

**Why this priority**: Vision and summarization do not have identical runtime requirements, and advanced users need separate control to avoid being boxed into one global model decision.

**Independent Test**: Configure one provider/model for summarization and a different provider/model for vision, then verify that summarization and screen-context inference each use their own saved configuration without overwriting one another.

**Acceptance Scenarios**:

1. **Given** the user is configuring AI behavior, **When** the user reviews the settings or wizard, **Then** summarization and vision each have their own provider and model controls.
2. **Given** the user chooses different providers for summarization and vision, **When** the configuration is saved, **Then** each capability retains its own provider and model selection.
3. **Given** the user changes the summarization provider or model, **When** the change is confirmed, **Then** the saved vision provider and model remain unchanged.
4. **Given** the user changes the vision provider or model, **When** the change is confirmed, **Then** the saved summarization provider and model remain unchanged.

---

### User Story 3 - Adjust Advanced AI Configuration Later in Settings (Priority: P3)

As an advanced user, I want to change summarization and vision configuration later in settings and receive clear feedback when a chosen provider or model cannot be used.

**Why this priority**: The feature only works for advanced users if the app remains editable after onboarding and makes invalid local configurations understandable.

**Independent Test**: Open settings from an already configured app, change either summarization or vision to an unavailable provider/model, and verify that the app preserves the rest of the configuration while showing an actionable validation message.

**Acceptance Scenarios**:

1. **Given** the app has already been configured, **When** the user opens settings, **Then** the active summarization and vision configurations are both visible and editable.
2. **Given** the user selects a provider or model that is not currently available for summarization or vision, **When** the app validates the selection or starts the related work, **Then** the app presents a clear user-facing message explaining what is missing.
3. **Given** a previously unavailable provider or model becomes available later, **When** the user keeps that configuration selected, **Then** the related summarization or vision task can proceed without requiring the user to reselect it.

### Edge Cases

- The user upgrades from a version that only supported built-in inference and must receive sensible built-in defaults for both summarization and vision without breaking existing behavior.
- One capability uses `Built-in` while the other uses `Ollama`, and both configurations must remain independently editable.
- The selected provider or model is unavailable at app launch, but the user should still be able to open settings and adjust the affected capability.
- The setup wizard is partially completed and the user navigates backward and forward without losing pending summarization or vision selections.
- The user changes summarization configuration while a summarization job is already in progress; the active job should keep its original summarization configuration and future jobs should use the newly selected one.
- The user changes vision configuration while screen-context inference is active; the active inference should keep its original vision configuration and later inference should use the newly selected one.
- A selected vision model does not actually support vision, and the app must block that configuration clearly.
- Inference-provider selections must not affect transcription runtime selection or the deterministic three-file vault output contract.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The system MUST allow users to choose inference provider and model separately for summarization and for vision-based screen-context inference.
- **FR-002**: The system MUST offer `Built-in` and `Ollama` as provider options for summarization.
- **FR-003**: The system MUST offer `Built-in` and `Ollama` as provider options for vision-based screen-context inference.
- **FR-004**: The setup wizard MUST surface separate summarization and vision configuration controls during AI configuration.
- **FR-005**: Settings MUST surface separate summarization and vision configuration controls after onboarding is complete.
- **FR-006**: The system MUST persist summarization provider/model selection independently from vision provider/model selection.
- **FR-007**: The system MUST use the persisted summarization configuration for new summarization runs until the user changes it.
- **FR-008**: The system MUST use the persisted vision configuration for new screen-context inference runs until the user changes it.
- **FR-009**: The system MUST preserve existing built-in behavior for users who keep `Built-in` selected.
- **FR-010**: The system MUST assign sensible built-in defaults for both summarization and vision when existing users upgrade to this feature.
- **FR-011**: The wizard and settings MUST present the same inference-provider options and the same currently selected values for both capabilities.
- **FR-012**: The system MUST clearly indicate which provider and model are currently active for summarization and which are currently active for vision.
- **FR-013**: The system MUST inform the user when the selected provider or model for either capability cannot currently be used and provide a clear path to change that capability without disturbing the other one.
- **FR-014**: The system MUST allow users to change summarization or vision configuration without re-running onboarding.
- **FR-015**: Changing summarization configuration MUST NOT modify vision configuration, transcription configuration, or unrelated AI settings.
- **FR-016**: Changing vision configuration MUST NOT modify summarization configuration, transcription configuration, or unrelated AI settings.
- **FR-017**: A summarization run already in progress MUST continue using the summarization provider/model it started with even if the user changes summarization settings before that run completes.
- **FR-018**: A screen-context inference task already in progress MUST continue using the vision provider/model it started with even if the user changes vision settings before that task completes.
- **FR-019**: Future summarization runs started after a summarization configuration change MUST use the newly selected summarization provider/model.
- **FR-020**: Future screen-context inference tasks started after a vision configuration change MUST use the newly selected vision provider/model.
- **FR-021**: The system MUST keep provider and model selection local to the device and MUST NOT require a cloud account or remote configuration service.
- **FR-022**: The configuration flow MUST distinguish summarization, vision, and transcription so users do not confuse the three responsibilities.
- **FR-023**: User-facing provider descriptions in wizard and settings MUST explain the choice in plain language suitable for advanced but non-developer users.
- **FR-024**: The system MUST reject a vision configuration that uses a model lacking vision capability.
- **FR-025**: If screen context is disabled, the system MUST preserve the saved vision configuration for later use without affecting summarization behavior.

### Non-Functional Requirements *(mandatory)*

- **NFR-001**: The feature MUST preserve local-only processing and avoid outbound network calls except model downloads explicitly initiated for supported local runtimes.
- **NFR-002**: The feature MUST preserve deterministic note rendering and the existing three-file meeting output contract regardless of summarization provider choice.
- **NFR-003**: Validation, selection, and provider-switching flows MUST keep the UI responsive and MUST NOT block the main interaction thread.
- **NFR-004**: User-facing errors and status messages related to provider or model selection MUST be concise, actionable, and must not expose raw transcript content or raw captured images by default.
- **NFR-005**: The wizard and settings experiences MUST remain consistent with the app's existing information architecture and Apple-style usability expectations.

### Key Entities *(include if feature involves data)*

- **Inference Capability**: A configurable AI task category, either `summarization` or `vision`, each with its own provider and model selection.
- **Inference Provider**: A user-selectable local runtime option, either `Built-in` or `Ollama`, used for one inference capability.
- **Inference Configuration Preference**: The persisted local setting that records provider and model selection for one capability.
- **Capability Availability State**: The current readiness status for one capability's selected provider/model, including whether it can be used immediately or requires user action first.
- **Inference Run Context**: The per-task state that binds a summarization job or screen-context inference task to the provider/model selected at the moment that work begins.

## Assumptions

- The current built-in summarization and vision paths remain supported and continue to be the compatibility baseline for existing users unless they choose otherwise.
- Ollama is treated as a local runtime choice, not as a cloud-hosted service.
- Advanced users are comfortable choosing provider and model explicitly rather than relying on a heavily curated catalog.
- Provider-specific setup guidance can be concise and embedded where the choice is made, rather than requiring a separate onboarding flow.
- This feature covers provider/model selection and persistence; deeper provider-specific tuning is outside scope unless already supported elsewhere in the product.

## Dependencies

- Existing onboarding and settings flows must both support AI configuration updates.
- The summarization pipeline must support a clear boundary where summarization provider/model selection can be applied at run start.
- The screen-context inference pipeline must support a clear boundary where vision provider/model selection can be applied at inference start.
- Existing upgrade/migration behavior for local preferences must be able to assign built-in defaults for prior users.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: In acceptance testing, 100% of clean-install users can identify and set both summarization and vision provider/model choices during the setup wizard without leaving the flow.
- **SC-002**: In acceptance testing, 100% of existing users can change summarization or vision configuration from settings in 45 seconds or less.
- **SC-003**: In migration testing, 100% of upgraded users retain a valid built-in configuration for both summarization and vision after updating to the release that introduces this feature.
- **SC-004**: In validation testing, 100% of new summarization runs use the summarization provider/model most recently selected by the user.
- **SC-005**: In validation testing, 100% of new screen-context inference tasks use the vision provider/model most recently selected by the user.
- **SC-006**: In concurrency testing, 100% of in-progress summarization and vision tasks complete with the provider/model they started with even if the user changes configuration mid-task.
- **SC-007**: In usability validation, at least 90% of advanced test users correctly distinguish summarization, vision, and transcription configuration on first attempt.
- **SC-008**: In release QA, inference-provider configuration introduces zero regressions to the deterministic vault output contract for processed meetings.
