# 06 — Summarization and Structure Extraction (llama.cpp)

## Goal
Invoke `llama.cpp` locally to convert the transcript into strictly valid JSON matching the fixed extraction schema.

Critical constraint: the model output must be machine-validated JSON; the model does not write Markdown.

## Deliverables
- `SummarizationService` that:
  - Loads configured GGUF model from Application Support
  - Runs a JSON-only prompt
  - Returns raw JSON string (or `Data`) on success
  - Provides debug output on failure
  - Supports one repair pass (wired to phase 07)
- A bundled llama **library** integrated into the app/Swift package (e.g., `llama.xcframework`)

## Prompting strategy
### System prompt goals
- Produce JSON only (no markdown, no prose)
- Conform to schema exactly
- Ensure arrays are always present (even if empty)
- Keep `date` as `YYYY-MM-DD`

### User prompt inputs
- Transcript text
- Recording date/time (if known)
- Optional: user-provided meeting title (v1 can omit this)

### Output contract
The prompt must instruct:
- Output must be a single JSON object
- No code fences
- No leading/trailing text

## JSON schema types
Represent the schema as `Codable` models in `MinuteCore`:
- `MeetingExtraction`
  - `title: String`
  - `date: String`
  - `summary: String`
  - `decisions: [String]`
  - `action_items: [ActionItem]`
  - `open_questions: [String]`
  - `key_points: [String]`
- `ActionItem`
  - `owner: String`
  - `task: String`
  - `due: String`

Keep `due` as a string to preserve blank values per v1 (`""`). Date validation happens in phase 07.

## Deterministic llama invocation
Define stable parameters:
- temperature (low)
- top_p (optional)
- seed (fixed) if supported/desired
- max tokens limit

## Model location
- Model weights stored at:
  - `~/Library/Application Support/Minute/models/`
- `SummarizationService` receives a resolved model URL from `ModelManager`.

## Output capture and sanitization
Like whisper:
- Capture raw model output
- Remove any progress logs if present
- Extract the JSON object (in case llama prints extra whitespace)

Prefer strictness: if output contains anything besides JSON, treat it as invalid and route through repair/fallback.

## Error handling
Map:
- model missing → `MinuteError.modelMissing`
- non-zero exit → `MinuteError.llamaFailed(exitCode:output:)`
- JSON extraction failure → `MinuteError.jsonInvalid`

## Exit criteria checklist
- [ ] Llama runs locally using the downloaded GGUF model
- [ ] Output is JSON-only under normal conditions
- [ ] Failures surface clear domain errors and include debug output
- [ ] No model output is written into the vault directly
