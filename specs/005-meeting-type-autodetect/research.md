# Research: Meeting Type Autodetect Calibration

**Feature Branch**: `005-meeting-type-autodetect`
**Date**: 2026-02-07

## 1. Prompting Strategy (Conservative / Default-Safe)

**Decision**: Use a conservative, “selective classification” prompt: only choose a non-General meeting type when evidence is strong; otherwise output `General`.

### Rationale
- Real-world meeting transcripts often contain mixed formats and keyword noise.
- Overconfident misclassification is worse than a safe `General` summary style.
- A conservative policy is easy to test and aligns with the product requirement “uncertain ⇒ General”.

### Key Prompt Elements
- **Explicit default rule**: “If uncertain / ambiguous / low-information ⇒ return `General`.”
- **Strong-signal rubric**: Require at least two strong signals for any non-General type.
- **Anti-signals**: Explicitly warn against “keyword traps” (e.g., single mentions of “sprint”, “design”, “demo”).
- **Few-shot examples**: Include (a) clear positives for each type and (b) ambiguous/hybrid examples that correctly map to `General`.
- **Strict output whitelist**: Output must be exactly one of the allowed labels (no punctuation, no extra words).

### Alternatives Considered
- **“Always choose one best label”**: Rejected because it forces overconfident guesses.
- **Heuristic keyword detection**: Rejected as brittle and hard to maintain.
- **Ask model for a numeric confidence**: Often poorly calibrated; still requires a deterministic fallback policy.

## 2. Output Constraint & Validation

**Decision**: Keep the classifier output contract as a single label, but tighten post-parse validation.

### Rationale
- A label-only contract is simple and compatible with the existing pipeline.
- Deterministic behavior should be enforced in code: invalid, ambiguous, or multi-label responses must map to `General`.

### Alternatives Considered
- **JSON output with fields (type, signals, confidence)**: Potential future improvement, but increases complexity and requires schema + parsing changes.

## 3. Constraining Llama Output (Pragmatic Guidance)

**Decision**: Prefer deterministic sampling controls + strict post-parse validation in v1; consider token-level constraints (grammar / schema-to-grammar) only if supported by the current local llama integration.

### Rationale
- Token-level constraints (GBNF grammar / JSON-schema→grammar) are the only robust way to *guarantee* output format at inference time, but they depend on integration support.
- Even with constraints, semantic validation in code is still required (truncation, edge cases).

### Practical Controls
- Use conservative generation settings for classification: low temperature (ideally 0), fixed seed, and small max tokens.
- Stop early on newline / end-of-output when feasible.
- Retry at most a small bounded number of times; on failure, default to `General`.

## 4. Offline Evaluation Dataset

**Decision**: Add a deterministic offline evaluation set as unit tests in `MinuteCore`.

### Rationale
- Prevents prompt tweaks from regressing classification behavior.
- Allows measuring the precision–coverage tradeoff, especially the “ambiguous ⇒ General” requirement.

### Metrics / Targets
- High precision for non-General types on “clear” examples.
- High rate of `General` on intentionally ambiguous examples.

