# Data Model: LM Studio Provider Support

This feature preserves the existing vault artifacts and extends capability-aware inference configuration so summarization and vision can each use `Built-in`, `Ollama`, or `LM Studio`.

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
  - Enum: `builtIn | ollama | lmStudio`
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
- `lmStudioModelIdentifier: String?`
- `lastUpdatedAt: Date?`

**Validation**:
- `capabilityID` must resolve to a known `InferenceCapability`.
- `selectedProviderID` must resolve to a known `InferenceProvider`.
- `builtInModelID`, when present, must resolve to a known built-in model for that capability.
- `ollamaModelTag`, when present, must be a non-empty trimmed tag string.
- `lmStudioModelIdentifier`, when present, must be a non-empty trimmed local model identifier.
- Changing configuration for one capability must not erase the stored selection values for the other capability.

### ProviderConnectionPreference

Represents persisted local connection details for an advanced provider.

**Fields**:
- `providerID: String`
  - Enum: `ollama | lmStudio`
- `baseURL: String`
- `lastValidatedAt: Date?`

**Validation**:
- `providerID` must identify a provider that uses a user-managed local server.
- `baseURL` must be a valid HTTP or HTTPS URL.
- For `lmStudio`, the default value is the local loopback server on port `1234`.

### LMStudioDiscoverySnapshot

Represents the most recent view of the local LM Studio server and the models it exposes.

**Fields**:
- `serverReachable: Bool`
- `discoveredAt: Date`
- `models: [LMStudioModelDescriptor]`
- `failureReason: String?`

**Validation**:
- `models` may be empty when the server is reachable but no compatible local models are visible.
- `failureReason` is present only when discovery could not complete successfully.

### LMStudioModelDescriptor

Represents one LM Studio model exposed by the local server.

**Fields**:
- `identifier: String`
- `displayName: String`
- `modelType: String`
  - Examples: `llm`, `vlm`, `embeddings`
- `publisher: String?`
- `architecture: String?`
- `compatibilityType: String?`
- `quantizationLabel: String?`
- `state: String?`
- `maxContextLength: Int?`
- `supportsVision: Bool`

**Validation**:
- `identifier` must be unique within one discovery snapshot.
- `supportsVision == true` when `modelType` indicates a vision-capable model.
- `maxContextLength`, when present, must be greater than zero.

### CapabilityAvailabilityState

Represents the user-facing readiness state for one capability's current provider and model selection.

**Fields**:
- `capabilityID: String`
- `providerID: String`
- `isReady: Bool`
- `status: String`
  - Enum: `ready | needs_configuration | daemon_unavailable | server_unavailable | model_missing | unsupported | vision_unsupported | unknown`
- `message: String?`
- `selectedReference: String?`

**Validation**:
- `capabilityID` must match the capability being evaluated.
- `providerID` must match the provider being evaluated.
- `isReady == true` only when `status == ready`.
- `daemon_unavailable` is used for providers backed by a daemon-style local service such as Ollama.
- `server_unavailable` is used for providers backed by a local HTTP server such as LM Studio.

### InferenceTaskBinding

Represents the immutable provider/runtime selection captured when an inference task starts.

**Fields**:
- `capabilityID: String`
- `providerID: String`
- `providerReference: String`
  - built-in model ID, Ollama tag, or LM Studio model identifier
- `connectionBaseURLString: String?`
- `capturedAt: Date`
- `supportsVisionInputs: Bool`

**Validation**:
- `capabilityID` must match a known capability.
- `providerID` must match a known provider.
- `providerReference` must be non-empty.
- `connectionBaseURLString` is persisted for advanced providers so in-flight work stays pinned to the endpoint it started with.
- The binding must not change after the task is created.

## Relationships

- `InferenceConfigurationPreference` belongs to exactly one `InferenceCapability`.
- Each `InferenceCapability` selects exactly one active `InferenceProvider`.
- `ProviderConnectionPreference` belongs to one advanced provider and may be shared across both capabilities.
- `LMStudioDiscoverySnapshot` contains zero or more `LMStudioModelDescriptor` records discovered from the local LM Studio server.
- `CapabilityAvailabilityState` is derived from `InferenceConfigurationPreference`, `ProviderConnectionPreference`, and provider-specific readiness checks.
- `InferenceTaskBinding` is derived from `InferenceConfigurationPreference` at task start and is consumed by the active summarization or vision pipeline for the duration of that task.

## State Transitions

### Capability configuration flow

1. `builtIn selected` -> `lmStudio selected`
2. `ollama selected` -> `lmStudio selected`
3. `lmStudio selected` -> `validating connection`
4. `validating connection` -> `ready`
5. `validating connection` -> `service_unavailable`
6. `validating connection` -> `model_missing`
7. `validating connection` -> `vision_unsupported`
8. `lmStudio selected` -> `builtIn selected`
9. `lmStudio selected` -> `ollama selected`

### LM Studio discovery flow

1. `idle` -> `checking local server`
2. `checking local server` -> `inventory available`
3. `checking local server` -> `service unavailable`
4. `inventory available` -> `capabilities resolved`

### Task binding flow

1. User updates summarization or vision configuration in onboarding or settings.
2. A new summarization or vision task starts.
3. The system resolves an `InferenceTaskBinding` from the current configuration for that capability.
4. The task executes entirely with that binding.
5. Later configuration changes affect only future tasks.
