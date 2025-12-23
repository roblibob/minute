# 07 — Validation, JSON Repair, and Markdown Rendering

## Goal
Convert raw model output into a safe, validated `MeetingExtraction` and render deterministic Markdown that exactly matches the v1 template.

This phase is where correctness and determinism are enforced.

## Deliverables
- Strict JSON decoding into typed schema
- One repair attempt if decoding fails
- Fallback extraction if still invalid
- Deterministic Markdown rendering (no model-written Markdown)
- Unit tests that lock the rendering output

## Validation and repair pipeline
### Step 1: strict decode
- Attempt to decode raw JSON into `MeetingExtraction`.
- Reject if:
  - required keys missing
  - types mismatch
  - JSON contains trailing junk beyond the object

### Step 2: repair (single pass)
If strict decode fails:
- Send the raw output into a “repair JSON” llama prompt:
  - Input: invalid JSON text
  - Output: JSON-only conforming to schema
- Attempt strict decode again.

### Step 3: fallback
If still invalid:
- Create a fallback `MeetingExtraction`:
  - title: `"Untitled"` (or derived from date)
  - date: today
  - summary: `"Failed to structure output; see audio for details."`
  - other arrays: empty

Store the failure reason for UI display/logging, but proceed to writing a valid note.

## Additional schema validation
After decoding, validate content:
- `date` must match `YYYY-MM-DD` (regex)
  - If invalid, replace with recording date
- Ensure arrays are non-nil (Codable model should already do this)
- Sanitize strings to avoid unescaped YAML/Markdown issues

## Deterministic Markdown rendering
### Rendering rules
- Use a single renderer implementation that produces stable output:
  - fixed ordering
  - fixed section headers
  - fixed bullet formatting
  - consistent newline handling (e.g., `\n`)
- Never include transcript.

### YAML frontmatter
Render exactly:
```
---
type: meeting
date: YYYY-MM-DD
title: "<Title>"
audio: "Meetings/_audio/YYYY-MM-DD HH.MM - <Title>.wav"
source: "Minute"
---
```

Rules:
- Title must be YAML-escaped and quoted.
- Audio path must be quoted.

### Body template
Render exactly:
- `# <Title>`
- Sections in order: Summary, Decisions, Action Items, Open Questions, Key Points, Audio
- Action items formatted:
  - `- [ ] <task> (Owner: <name>) (Due: <YYYY-MM-DD or blank>)`

### Escaping and sanitization
- Prevent Markdown injection from model text by:
  - normalizing newlines
  - trimming whitespace
  - replacing `\r\n` with `\n`
- Keep content readable; do not over-escape unless necessary.

## Filename sanitization
Define a single function for turning `<Title>` into a safe filename:
- remove or replace `/` `:` and other forbidden characters
- collapse whitespace
- trim
- if empty → `Untitled`

Also prevent path traversal (`..`).

## Testing
Add golden tests:
- Given a known `MeetingExtraction`, rendered Markdown equals an expected string.
- YAML quoting tests for edge-case titles.

## Exit criteria checklist
- [ ] Invalid JSON triggers exactly one repair attempt
- [ ] Persistent invalid output yields a valid fallback note
- [ ] Markdown renderer output matches the v1 template deterministically
- [ ] Unit tests lock key rendering behaviors
