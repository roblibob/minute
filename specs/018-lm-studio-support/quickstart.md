# Quickstart: LM Studio Provider Support

## Goal

Validate that Minute can configure summarization and vision independently, using `Built-in`, `Ollama`, or `LM Studio` for each capability, while preserving the existing vault contract.

This feature is intended for advanced users. Minute continues to treat summarization and screen-context vision as separate capabilities with separate provider and model choices, separate readiness state, and immutable per-run bindings once work starts.

## Preconditions

- The app is built from branch `018-lm-studio-support`.
- A local vault is configured.
- At least one built-in summarization model is available through the existing model-management path.
- At least one built-in vision-capable model is available through the existing model-management path.
- Ollama is installed locally for cross-provider regression scenarios.
- LM Studio is installed locally and its local server is running on the configured local base URL for LM Studio-specific scenarios.
- At least one LM Studio text-capable model is visible to the local LM Studio server for the happy-path summarization scenario.
- At least one LM Studio vision-capable model is visible to the local LM Studio server for the happy-path vision scenario.

## Validation Scenarios

### 1. Choose LM Studio during onboarding

1. Launch the app in a clean onboarding state.
2. Move to the AI models step in onboarding.
3. Verify the AI configuration shows separate controls for summarization and vision.
4. Select `LM Studio` for summarization.
5. Select `LM Studio`, `Built-in`, or `Ollama` for vision.
6. Enter the LM Studio base URL and choose provider-appropriate model references.
7. Complete onboarding.

Expected result:
- Onboarding exposes `LM Studio` anywhere summarization or vision provider choice is available.
- The LM Studio connection details and selected model persist.
- Summarization and vision remain independently configurable.
- Onboarding blocks completion when the selected LM Studio configuration is invalid or unavailable.

### 2. Change providers independently in settings

1. Start with onboarding completed and built-in selected for both capabilities.
2. Open settings and navigate to AI models.
3. Change summarization to `LM Studio`.
4. Leave vision on another provider, then switch vision to `LM Studio`.
5. Close and reopen settings.

Expected result:
- Summarization and vision configuration persist across settings reloads.
- Changing one capability does not erase or overwrite the other capability's saved selection.
- Returning to `LM Studio` restores the previously saved LM Studio model selection for that capability unless the user changed it.

### 3. Discover local LM Studio models

1. Ensure the LM Studio local server is running with at least one compatible model visible.
2. Open onboarding or settings with `LM Studio` selected.
3. Trigger provider refresh if needed.
4. Inspect the discovered LM Studio model list.

Expected result:
- The app lists models currently exposed by the local LM Studio server.
- The selected model can be validated against the discovered identifiers.
- The app can distinguish text-only and vision-capable models for readiness checks.
- Discovery remains local-only.

### 4. Reject a non-vision LM Studio model for screen context

1. Select `LM Studio` for vision.
2. Choose an LM Studio model that does not support vision work.
3. Save or validate the vision configuration.

Expected result:
- The app blocks the vision selection.
- The error explains that the selected model does not support vision.
- Summarization configuration remains unchanged.

### 5. Handle missing local LM Studio prerequisites cleanly

1. Stop the LM Studio local server or choose a model that is no longer available.
2. Open settings with `LM Studio` selected.
3. Attempt to keep `LM Studio` selected for summarization or vision and start related work.

Expected result:
- The app reports a concise, actionable readiness error.
- The error explains whether the local server is unavailable or the selected model is missing.
- The app does not leak raw transport errors, transcript content, or captured image content.
- The user can switch the affected capability back to another provider without losing unrelated settings.

### 6. Bind provider choice at task start

1. Start a meeting-processing run with one summarization configuration.
2. While the run is still active, open settings and change summarization configuration to or from `LM Studio`.
3. Let the in-flight run finish.
4. Start a second run after the switch.
5. Repeat the same pattern for active screen-context inference and the vision configuration.

Expected result:
- The in-flight task completes using the provider and model it started with.
- The later task uses the newly selected provider and model.
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

## Validation Results

Validation was attempted on 2026-04-02.

- `swift test --package-path MinuteCore`
  - Blocked by upstream dependency compilation failures in the checked-out `FluidAudio` package.
  - Observed failure area: strict-concurrency errors in `StreamingAsrManager.swift`.
- `xcodebuild -project Minute.xcodeproj -scheme Minute -configuration Debug test`
  - Blocked before project compilation by a local Xcode environment issue.
  - Observed failure area: broken `IDESimulatorFoundation` plugin state with `xcodebuild` suggesting `-runFirstLaunch`.

Feature-specific verification completed through targeted source inspection and updated unit-test coverage, but full automated regression remains pending until the local toolchain issues above are resolved.

## Focused Test Additions

- Provider enum and persistence migration to include `LM Studio`
- LM Studio connection settings validation and persistence
- LM Studio discovery parsing and vision-capability validation
- Runtime factory/provider binding for summarization and vision tasks
- Onboarding and settings provider-selection persistence and readiness messaging
- Contract regression tests for unchanged three-file meeting output
