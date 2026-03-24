# Quickstart: Advanced Inference Provider Options

## Goal

Validate that Minute can configure summarization and vision independently, using either the built-in runtime or a local Ollama daemon for each capability, while preserving the existing vault contract.

This feature is intended for advanced users. Minute now treats summarization and screen-context vision as separate capabilities with separate provider/model choices, separate validation state, and immutable per-run bindings once work starts.

## Preconditions

- The app is built from branch `017-ollama-summarization-option`.
- A local vault is configured.
- At least one built-in summarization model is available through the existing model-management path.
- At least one built-in vision-capable model is available through the existing model-management path.
- Ollama is installed locally and running for Ollama-specific validation scenarios.
- At least one Ollama summarization-capable model is already downloaded locally for the happy-path summarization scenario.
- At least one Ollama vision-capable model is already downloaded locally for the happy-path vision scenario.

## Validation Scenarios

### 1. Choose separate summarization and vision providers during onboarding

1. Launch the app in a clean onboarding state.
2. Move to the models step in onboarding.
3. Verify the AI configuration shows separate controls for summarization and vision.
4. Select `Built-in` or `Ollama` for summarization.
5. Select `Built-in` or `Ollama` for vision.
6. Choose provider-appropriate model references for both capabilities.
7. If either capability uses `Ollama`, verify the readiness row shows the current daemon/model status.
8. Complete onboarding.

Expected result:
- Onboarding completes without requiring a reinstall or a separate setup flow.
- The selected summarization configuration persists independently from the selected vision configuration.
- The app shows capability-specific readiness text instead of generic shared AI copy.
- Onboarding remains blocked until invalid or unavailable Ollama selections become ready or are changed.

### 2. Change summarization and vision independently in settings

1. Start with onboarding completed and built-in selected for both capabilities.
2. Open settings and navigate to AI models.
3. Change summarization to one provider/model combination.
4. Change vision to a different provider/model combination.
5. Confirm the provider-specific selection/status updates for both capabilities.
5. Close and reopen settings.
6. Confirm both saved configurations remain intact.

Expected result:
- Summarization and vision configuration persist across settings reloads.
- Changing one capability does not erase or overwrite the other capability’s saved model selection.
- The UI clearly distinguishes summarization, vision, and transcription.

### 3. Discover downloaded Ollama models and capabilities

1. Ensure Ollama is running locally with at least one downloaded model.
2. Open onboarding or settings with Ollama selected.
3. Trigger provider refresh if needed.
4. Inspect the discovered Ollama model list.

Expected result:
- The app lists downloaded local Ollama models.
- The selected model can be validated against the discovered tags.
- Capability metadata is available for discovered models, including whether the model advertises vision support.
- Discovery is local-only and only reflects models already available to the local Ollama daemon.

### 4. Reject a non-vision model for vision configuration

1. Select `Ollama` for vision.
2. Choose or enter an Ollama model tag that does not advertise vision support.
3. Save or validate the vision configuration.

Expected result:
- The app blocks the vision selection.
- The error explains that the selected model does not support vision.
- Summarization configuration remains unchanged.

### 5. Handle missing local Ollama prerequisites cleanly

1. Stop the Ollama daemon or select an Ollama model tag that is not installed.
2. Open settings with Ollama selected.
3. Attempt to keep Ollama selected for summarization or vision and start related work.

Expected result:
- The app reports a concise, actionable readiness error.
- The error explains whether the daemon is unavailable or the selected model tag is missing.
- The app does not leak raw transport errors, transcript content, or captured image content.
- The user can switch the affected capability back to `Built-in` without losing unrelated settings.
- Starting recording with invalid vision configuration continues audio capture and shows a corrective alert instead of hard-failing the session.

### 6. Bind provider choice at task start

1. Start a meeting-processing run with one summarization configuration.
2. While the run is still active, open settings and change summarization configuration.
3. Let the in-flight run finish.
4. Start a second run after the switch.
5. Repeat the same pattern for active screen-context inference and the vision configuration.

Expected result:
- The in-flight task completes using the provider/model it started with.
- The later task uses the newly selected provider/model.
- No extra vault files are created and the existing three-file contract is preserved.

## Suggested Test Commands

Run MinuteCore tests:

```bash
swift test --package-path MinuteCore
```

Run app and integration tests:

```bash
xcodebuild -project Minute.xcodeproj -scheme Minute -configuration Debug test
```

## Focused Test Additions

- Capability-aware provider selection store persistence and migration defaults
- Ollama discovery parsing for local tags and model details
- Capability extraction including `vision`
- Runtime factory/provider binding for summarization and vision tasks
- Onboarding and settings provider-selection persistence and messaging
- Contract regression tests for unchanged three-file meeting output

## Final Validation Results

Validated on `2026-03-24 10:14 CET`.

- `swift test --package-path MinuteCore`
  - Result: passed
  - Scope: 326 tests covering capability persistence, Ollama discovery/validation, runtime binding, pipeline determinism, and vault contract regressions
- `xcodebuild -project Minute.xcodeproj -scheme Minute -configuration Debug -only-testing:MinuteTests test`
  - Result: passed
  - Scope: 70 tests covering onboarding, settings, live pipeline alerts, and app-level capability configuration behavior
- `xcodebuild -project Minute.xcodeproj -scheme Minute -configuration Debug test`
  - Result: passed
  - Scope: full app test run completed successfully after the feature landed

## Coverage Notes

- Ollama discovery is verified against local daemon endpoints for downloaded tags and per-model capability lookup.
- Vision validation rejects Ollama models that do not advertise `vision` capability.
- Settings and onboarding preserve independent summarization and vision selections while surfacing actionable readiness state.
- Active summarization and vision work bind to the provider/model resolved at task start so later settings changes only affect future work.
- The deterministic three-file vault contract remains unchanged across built-in and Ollama provider combinations.
