# Research: Meeting Type Prompts

**Feature Branch**: `003-meeting-type-prompts`
**Date**: 2026-02-04

## 1. Prompt Engineering Strategy

**Decision**: Use a Protocol-oriented strategy pattern for prompt generation.

### Rationale
- Allows easy extension for new meeting types.
- Isolates prompt logic from the main service.
- Enables individual unit testing of each prompt template.

### Meeting Type Definitions and Prompt Focus
Based on spec requirements:

| Meeting Type | Primary Focus | JSON Field Priority | System Prompt Nuance |
| :--- | :--- | :--- | :--- |
| **General** | Balanced summary | All balanced | Standard "business meeting" context. |
| **Standup** | Progress & Blockers | `action_items` (Blockers), `summary` (Progress) | "Daily standup context. Focus on what was done, what will be done, and blockers. Ignore small talk." |
| **Presentation** | Content Delivery | `key_points`, `summary` | "Presentation/Talk context. Focus on the core message, slides content, and key takeaways. Minimize 'decisions' unless explicit." |
| **Design Review** | Feedback & Decisions | `decisions`, `open_questions` | "Design critique context. Focus on feedback given, design decisions made, and open questions on UX/UI." |
| **One-on-One** | Actionable Outcomes | `action_items`, `decisions` | "1:1 context. focus on agreements, career growth discussions (if appropriate), and tasks. Be discreet." |
| **Planning** | Scope & Assignment | `action_items`, `decisions` (Scope) | "Sprint/Project planning. Focus on what is in/out of scope, who is doing what, and deadlines." |

## 2. Autodetect Strategy (Two-Pass)

**Decision**:
Pass 1: Classification
Pass 2: Summarization (using result from Pass 1)

### Pass 1: Classification
- **Input**: First 2000 tokens (approx 5-10 minutes) or full transcript if short.
- **Model**: Same local model (Llama).
- **Prompt**: "Analyze this transcript snippet and classify it into exactly one category: [General, Standup, Design Review, One-on-One, Presentation, Planning]. efficiency is key. Return ONLY the category name."
- **Fallback**: If output is not one of the enums, default to "General".

### Alternatives Considered
- **Heuristic (Keyword)**: Check for "standup", "sprint", "slides". Too brittle.
- **Single Pass**: "Summarize this meeting, adapting your style to the detected type." Harder to test and validate strict JSON schema compliance if the model gets confused.

## 3. Metadata Persistence

**Decision**: Add `meetingType: String` to the JSON metadata file contract.

### Rationale
- The app already uses JSON files for persistence.
- Adding a new optional field is backward compatible.
- `String` raw value of the Enum ensures future-proofing if Enum names change in code (though we should keep raw values stable).

## 4. UI/UX Strategy

**Decision**:
- Add a `Picker` (Menu) next to the "Stop" button or in the header of the recorder.
- Default selection: "Autodetect".
- Changing selection updates the live State and writes to disk immediately.
