# Research: LM Studio Provider Support

**Feature Branch**: `018-lm-studio-support`  
**Date**: 2026-04-02  
**Spec**: [spec.md](../018-lm-studio-support/spec.md)

## Decision 1: Use LM Studio's OpenAI-compatible local endpoints for summarization and vision

**Decision**: Implement LM Studio inference through its OpenAI-compatible local server endpoints, using the same provider-binding flow for both summarization and vision.

**Rationale**:
- LM Studio documents OpenAI-compatible local endpoints for `GET /v1/models`, `POST /v1/responses`, and `POST /v1/chat/completions`, and explicitly states that chat completions support text and images.
- Reusing OpenAI-style request and response shapes keeps the runtime boundary simple and avoids forcing `MinuteCore` to learn a provider-specific request dialect for every capability.
- This preserves the existing Minute contract where provider resolution happens once at task start and the downstream summarization or vision service then behaves like any other local runtime.

**Alternatives considered**:
- Use LM Studio's SDKs directly: rejected because Minute already centers runtime integrations behind local service boundaries and Foundation networking is sufficient.
- Use only `POST /v1/responses`: rejected for initial scope because chat completions already covers text and image inputs and matches the current app's provider-service split more directly.
- Use a custom provider-specific prompt pipeline in the app target: rejected because orchestration belongs in `MinuteCore`, not the UI layer.

## Decision 2: Use LM Studio model-discovery endpoints for readiness and capability validation

**Decision**: Discover and validate LM Studio models through the local server's model-listing endpoints, using the richer LM Studio REST API metadata to distinguish text-only and vision-capable models.

**Rationale**:
- LM Studio's OpenAI-compatible `GET /v1/models` lists models visible to the server.
- LM Studio's documented REST API v0 exposes `GET /api/v0/models` and `GET /api/v0/models/{model}` with richer metadata including model `type`, load `state`, and `max_context_length`.
- The example model metadata distinguishes `llm` from `vlm`, which gives Minute a concrete local signal for rejecting non-vision LM Studio models when users configure screen-context vision.
- Using local discovery preserves the advanced-user workflow already established for Ollama: validate what is currently available on the user's machine instead of guessing from model names.

**Alternatives considered**:
- Use only `GET /v1/models`: rejected because it is not sufficient on its own to reliably identify vision-capable models.
- Infer vision support from model names: rejected because name-based heuristics are brittle and not a provider contract.
- Skip readiness validation and fail only when inference starts: rejected because the spec requires actionable guidance before or at task start.

## Decision 3: Keep LM Studio local-only and scoped to loopback by default

**Decision**: Treat LM Studio as a loopback-local runtime for this feature, with a default base URL of `http://127.0.0.1:1234`, and do not plan support for remote LM Studio hosts in this scope.

**Rationale**:
- Minute's constitution permits outbound network access only for model downloads and requires local-first processing.
- LM Studio documentation shows the local server on port `1234`; that gives the feature a clear parity default with the current Ollama base-URL flow.
- Limiting scope to loopback keeps the privacy contract clear and avoids introducing a new category of networked inference behavior through an advanced-provider feature.

**Alternatives considered**:
- Allow any user-supplied LAN host: rejected because it conflicts with Minute's stricter local-only constitution.
- Hardcode the default without exposing configuration: rejected because advanced users still need to point Minute at their local LM Studio server configuration.
- Bundle or launch LM Studio from Minute: rejected because LM Studio remains user-managed infrastructure outside Minute's responsibility.

## Decision 4: Add a dedicated `MinuteLMStudio` runtime target and keep provider-neutral orchestration in `MinuteCore`

**Decision**: Implement LM Studio transport, discovery, validation, and service adapters in a new `MinuteLMStudio` package target while keeping selection, persistence, runtime binding, and capability orchestration in `MinuteCore`.

**Rationale**:
- The repository already uses runtime-specific targets such as `MinuteLlama` and `MinuteOllama`.
- `InferenceRuntimeFactory` is already the central provider-binding seam; keeping it provider-neutral while adding LM Studio-specific builders matches the current architecture and minimizes UI coupling.
- A dedicated target keeps provider-specific networking and response mapping out of the core domain layer.

**Alternatives considered**:
- Put LM Studio code directly in `MinuteCore`: rejected because it would mix provider-neutral orchestration with transport-specific behavior.
- Extend `MinuteOllama` to also handle LM Studio: rejected because the providers have different discovery and request contracts.
- Put LM Studio integration in the app target: rejected because runtime selection and validation must remain testable in `MinuteCore`.

## Decision 5: Generalize advanced-provider persistence and readiness state instead of cloning Ollama-only structures

**Decision**: Refactor the current Ollama-specific persistence and readiness seams into provider-neutral capability settings, while still allowing provider-specific discovery payloads behind those abstractions.

**Rationale**:
- The current `InferenceProviderSelectionStore`, `InferenceRuntimeFactory`, onboarding view model, and settings view model are provider-aware but still carry Ollama-specific fields and naming.
- Adding LM Studio by duplicating `selectedOllama...`, `ollamaDiscoverySnapshot`, and Ollama-only storage keys would increase UI branching and make future provider work more expensive.
- Provider-neutral state makes it easier to preserve the user-facing behavior required by the spec: separate summarization and vision configuration, actionable readiness, and stable in-flight task binding.

**Alternatives considered**:
- Add LM Studio as a second provider-specific path beside Ollama with mirrored fields: rejected because it would spread provider-specific branching across settings, onboarding, runtime factories, and persistence.
- Replace the current advanced-provider model with one generic opaque string field: rejected because the app still needs explicit readiness, validation, and provider-specific guidance.

## Decision 6: Keep initial LM Studio scope aligned with current advanced-provider ergonomics

**Decision**: Scope the feature to user-managed local base URL plus model selection, without adding provider-specific download orchestration or authentication workflows in the first iteration.

**Rationale**:
- The feature request is to support LM Studio "just as" Ollama, which currently centers on choosing the provider, entering the local connection, selecting a local model, and surfacing readiness.
- This keeps the feature bounded around provider parity rather than expanding into provider administration.
- Existing deterministic note rendering, vault writing, and transcription behavior remain unchanged.

**Alternatives considered**:
- Add LM Studio model download management inside Minute: rejected because it expands scope beyond provider parity.
- Add token-based authentication flows now: rejected because the current Minute advanced-provider flows do not include auth management and the feature can provide value without it.

## References

- LM Studio OpenAI Compatibility Endpoints: https://lmstudio.ai/docs/developer/openai-compat
- LM Studio List Models (`GET /v1/models`): https://lmstudio.ai/docs/developer/openai-compat/models
- LM Studio REST API v0: https://lmstudio.ai/docs/developer/rest/endpoints
