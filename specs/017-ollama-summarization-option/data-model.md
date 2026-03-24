# Data Model: Advanced Inference Provider Options

This feature preserves the existing vault artifacts and adds capability-aware inference preferences, local Ollama discovery state, and per-task provider/model binding.

## Entities

### InferenceCapability

Represents one configurable AI task category.

**Fields**:
- `id: String`
  - Enum: `summarization | vision`
- `displayName: String`

**Validation**:
- `id` must be one of the supported capability identifiers.

### InferenceProvider

Represents the runtime family used for one capability.

**Fields**:
- `id: String`
  - Enum: `builtIn | ollama`
- `displayName: String`
- `description: String`

**Validation**:
- `id` must be one of the supported provider identifiers.

### InferenceConfigurationPreference

Represents the persisted local configuration for one capability.

**Fields**:
- `capabilityID: String`
- `selectedProviderID: String`
- `builtInModelID: String?`
- `ollamaModelTag: String?`
- `lastUpdatedAt: Date?`

**Validation**:
- `capabilityID` must resolve to a known `InferenceCapability`.
- `selectedProviderID` must resolve to a known `InferenceProvider`.
- `builtInModelID`, when present, must resolve to a known built-in model for that capability.
- `ollamaModelTag`, when present, must be a non-empty trimmed tag string.
- Changing configuration for one capability must not erase the stored selection values for the other capability.

### OllamaDiscoverySnapshot

Represents the most recent view of the local Ollama daemon and the downloaded model inventory.

**Fields**:
- `daemonReachable: Bool`
- `daemonVersion: String?`
- `discoveredAt: Date`
- `models: [OllamaModelDescriptor]`
- `failureReason: String?`

**Validation**:
- `models` may be empty when the daemon is reachable but no local models are installed.
- `failureReason` is present only when discovery could not complete successfully.

### OllamaModelDescriptor

Represents one downloaded Ollama model discovered from the local daemon.

**Fields**:
- `tag: String`
- `displayName: String`
- `digest: String`
- `sizeBytes: Int64`
- `modifiedAt: Date?`
- `families: [String]`
- `parameterSizeLabel: String?`
- `quantizationLabel: String?`
- `capabilities: [String]`
- `supportsVision: Bool`
- `contextLength: Int?`

**Validation**:
- `tag` must be unique within one discovery snapshot.
- `supportsVision == true` when `capabilities` contains `vision`.
- `sizeBytes >= 0`

### CapabilityAvailabilityState

Represents the user-facing readiness state for one capability's current provider/model selection.

**Fields**:
- `capabilityID: String`
- `providerID: String`
- `isReady: Bool`
- `status: String`
  - Enum: `ready | needs_configuration | daemon_unavailable | model_missing | unsupported | vision_unsupported | unknown`
- `message: String?`
- `selectedReference: String?`

**Validation**:
- `capabilityID` must match the capability being evaluated.
- `providerID` must match the provider being evaluated.
- `isReady == true` only when `status == ready`.

### InferenceTaskBinding

Represents the immutable provider/runtime selection captured when an inference task starts.

**Fields**:
- `capabilityID: String`
- `providerID: String`
- `providerReference: String`
  - built-in model ID or Ollama tag
- `capturedAt: Date`
- `supportsVisionInputs: Bool`

**Validation**:
- `capabilityID` must match a known capability.
- `providerID` must match a known provider.
- `providerReference` must be non-empty.
- The binding must not change after the task is created.

## Relationships

- `InferenceConfigurationPreference` belongs to exactly one `InferenceCapability`.
- Each `InferenceCapability` selects exactly one active `InferenceProvider`.
- `OllamaDiscoverySnapshot` contains zero or more `OllamaModelDescriptor` records discovered from the local daemon.
- `CapabilityAvailabilityState` is derived from `InferenceConfigurationPreference`, local runtime checks, and `OllamaDiscoverySnapshot`.
- `InferenceTaskBinding` is derived from `InferenceConfigurationPreference` at task start and is consumed by the active summarization or vision pipeline for the duration of that task.

## State Transitions

### Capability configuration flow

1. `builtIn selected` -> `ollama selected`
2. `ollama selected` -> `validating daemon`
3. `validating daemon` -> `ready`
4. `validating daemon` -> `daemon_unavailable`
5. `validating daemon` -> `model_missing`
6. `validating daemon` -> `vision_unsupported`
7. `ollama selected` -> `builtIn selected`

### Ollama discovery flow

1. `idle` -> `checking daemon`
2. `checking daemon` -> `inventory available`
3. `checking daemon` -> `daemon unavailable`
4. `inventory available` -> `details loading`
5. `details loading` -> `capabilities resolved`

### Task binding flow

1. User updates summarization or vision configuration in onboarding or settings.
2. A new summarization or vision task starts.
3. The system resolves an `InferenceTaskBinding` from the current configuration for that capability.
4. The task executes entirely with that binding.
5. Later configuration changes affect only future tasks.
