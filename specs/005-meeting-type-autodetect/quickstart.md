# Quickstart: Meeting Type Autodetect Calibration

## Goal

Make meeting-type Autodetect conservative: select a specific non-General type only when evidence is strong; otherwise default to `General`.

## Where to Look

- Classifier prompt + parsing: `MinuteCore/Sources/MinuteCore/Summarization/Services/MeetingTypeClassifier.swift`
- Classifier call site: `MinuteCore/Sources/MinuteLlama/Services/LlamaLibrarySummarizationService.swift`
- Prompt strategies (downstream use): `MinuteCore/Sources/MinuteCore/Summarization/Prompts/`
- Tests: `MinuteCore/Tests/` (add a small evaluation set)

## How to Run Tests

From repo root:

- Run core tests: `cd MinuteCore && swift test`

(Use the smallest test surface area first; this feature should be covered by `MinuteCore` unit tests.)

## Evaluation Notes

- Prompt changes are locked by unit tests; see `MinuteCore/Tests/MinuteCoreTests/Summarization/MeetingTypeClassifier*Tests.swift`.
- Classification is conservative: low-information, mixed-signal, or keyword-trap snippets should default to `General`.
- Parsing is strict (exact label match only); any invalid or messy output maps to `General`.

## Latest Test Run

- Command: `cd MinuteCore && swift test`
- Result: PASS (98 tests, 37 suites)

## How to Extend the Evaluation Set

1. Add a new transcript snippet fixture (short, synthetic, no private content).
2. Label it as:
   - Clear positive for one type, or
   - Ambiguous / hybrid (expected `General`), or
   - Keyword trap (expected `General`).
3. Add a unit test assertion for the expected classification.

## Output Contract

The classifier output is a single label string restricted to:
- `General`
- `Standup`
- `Design Review`
- `One-on-One`
- `Presentation`
- `Planning`

See schema: `specs/005-meeting-type-autodetect/contracts/meeting-type-classification-output.schema.json`

## Safety Defaults

- Any invalid or ambiguous output must map to `General`.
- Do not log raw transcript content.
- Keep inference bounded (small max tokens; conservative sampling).

