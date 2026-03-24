# Research: Advanced Inference Provider Options

**Feature Branch**: `017-ollama-summarization-option`  
**Date**: 2026-03-24  
**Spec**: [spec.md](spec.md)

## Decision 1: Add a first-class provider layer per inference capability

**Decision**: Introduce a distinct provider-and-model selection model per inference capability rather than encoding all runtime choices in the existing summarization model selection.

**Rationale**:
- The current code assumes summarization models come from `SummarizationModelCatalog` and screen-context inference comes from the built-in llama MTMD path.
- The follow-up direction changes the problem from “choose one summarization backend” to “configure summarization and vision independently.”
- Provider choice, model identity, and readiness checks now vary by capability, so the configuration model must reflect that directly.

**Alternatives considered**:
- Overload `SummarizationModelSelectionStore` with mixed provider/capability IDs: rejected because summarization and vision have different validation rules and runtime expectations.
- Replace llama.cpp entirely with Ollama: rejected because the feature explicitly adds an option, not a migration.
- Keep provider state only in the app layer: rejected because runtime selection, reprocessing, and tests belong in `MinuteCore`.

## Decision 2: Put Ollama integration in a dedicated `MinuteOllama` target

**Decision**: Add a small `MinuteOllama` Swift package target for Ollama API calls, discovery, summarization, and vision service implementation.

**Rationale**:
- The package already separates runtime-specific integrations into `MinuteWhisper` and `MinuteLlama`.
- Keeping Ollama-specific transport and mapping code out of `MinuteCore` preserves a clean capability-neutral boundary.
- A dedicated target reduces coupling and makes it easier to test discovery, summarization, and vision behavior without dragging in llama-specific dependencies.

**Alternatives considered**:
- Put Ollama code directly in `MinuteCore`: rejected because it would mix provider-neutral orchestration with daemon-specific networking.
- Put Ollama code into `MinuteLlama`: rejected because Ollama is a separate runtime contract, not a variant of the embedded llama XCFramework path.
- Implement Ollama only in the app target: rejected because orchestration, persistence, and testability belong in the package layer.

## Decision 3: Use local Ollama API discovery for downloaded models and capabilities

**Decision**: Use `GET /api/tags` to list downloaded models and `POST /api/show` to inspect detailed model metadata, including advertised capabilities such as `vision`.

**Rationale**:
- The official Ollama API documents `GET /api/tags` as the model-listing endpoint and `POST /api/show` as the details endpoint.
- `POST /api/show` explicitly includes a `capabilities` array in the documented response, and the example shows `"vision"` when a model supports it.
- This gives the app enough information to validate whether the selected local Ollama model exists and whether it is suitable for vision configuration.

**Alternatives considered**:
- Infer capabilities from the tag name alone: rejected because tags are not a reliable capability contract.
- Use only `GET /api/ps`: rejected because it lists currently loaded models, not installed/downloaded inventory.
- Hardcode Ollama model capability assumptions in the app: rejected because the daemon already exposes more authoritative metadata.

## Decision 4: Let advanced users manage model selection explicitly

**Decision**: Scope local discovery to downloaded models only and let advanced users choose model tags explicitly, instead of requiring the app to browse remote model inventory.

**Rationale**:
- The official local API documentation covers listing local models, running models, pulling models, and showing details, but it does not document a local endpoint that enumerates all pullable-but-not-installed models.
- Ollama’s docs also state that `https://ollama.com/api` is available for cloud access and requires authentication, which is not appropriate as a requirement for a local-first provider-selection feature.
- The follow-up requirement explicitly favors advanced-user control over a more opinionated curated flow.
- The simplest reliable user flow is to validate against installed Ollama tags and, when absent, instruct the user to pull the desired model in Ollama first.

**Alternatives considered**:
- Call Ollama’s cloud API to build a “not downloaded yet” catalog: rejected because it introduces unnecessary remote coupling for a local-first feature and does not reflect the local daemon’s installed state.
- Scrape the public model library: rejected because it is brittle and not a documented local API contract.
- Force users into an app-curated Ollama model list: rejected because the requested direction is to leave advanced configuration up to the user.

## Decision 5: Support separate built-in or Ollama choices for vision and summarization

**Decision**: Allow users to choose `Built-in` or `Ollama` independently for summarization and for vision-based screen-context inference.

**Rationale**:
- The follow-up direction explicitly calls for separate model choice for vision and summarization.
- Ollama’s official docs describe vision support through `POST /api/chat` using an `images` array, which makes a local vision path technically viable.
- Keeping built-in as one option preserves current behavior while giving advanced users the control they asked for.

**Alternatives considered**:
- Keep vision fixed to the built-in path: rejected because it conflicts with the new requirement for separate advanced-user choice.
- Couple summarization provider and vision provider into a single setting: rejected because advanced users may prefer different runtimes for each capability.
- Hide `vision` metadata and assume any Ollama model will work for images: rejected because the app should validate that a chosen model actually supports vision.
