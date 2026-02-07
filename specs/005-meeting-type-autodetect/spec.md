# Feature Specification: Meeting Type Autodetect Calibration

**Feature Branch**: `005-meeting-type-autodetect`  
**Created**: 2026-02-07  
**Status**: Draft  
**Input**: User description: "The autodetect meeting type is not satisfactory. It often picks the wrong type. If the LLM is uncertain it should pick General. Propose several suggestions to improve the prompting."

## User Scenarios & Testing *(mandatory)*

<!--
  IMPORTANT: User stories should be PRIORITIZED as user journeys ordered by importance.
  Each user story/journey must be INDEPENDENTLY TESTABLE - meaning if you implement just ONE of them,
  you should still have a viable MVP (Minimum Viable Product) that delivers value.
  
  Assign priorities (P1, P2, P3, etc.) to each story, where P1 is the most critical.
  Think of each story as a standalone slice of functionality that can be:
  - Developed independently
  - Tested independently
  - Deployed independently
  - Demonstrated to users independently
-->

### User Story 1 - Reliable Autodetect Defaults (Priority: P1)

As a user who leaves meeting type set to Autodetect, I want the app to avoid overconfident misclassification, so that the summary style is rarely “wrong for the meeting” and defaults to a safe General format when the meeting type is ambiguous.

**Why this priority**: Autodetect is the default path; wrong types are a high-frequency paper cut that reduces trust and increases manual rework.

**Independent Test**: Can be fully tested by running meeting-type classification against a fixed set of transcript snippets and verifying it selects a specific type only when evidence is strong, otherwise returning General.

**Acceptance Scenarios**:

1. **Given** a transcript snippet with mixed signals across multiple meeting types, **When** meeting type is Autodetect, **Then** the app chooses General.
2. **Given** a transcript snippet with clear, repeated signals for a specific meeting type, **When** meeting type is Autodetect, **Then** the app chooses that specific meeting type.
3. **Given** a transcript snippet that is too short or low-information to classify, **When** meeting type is Autodetect, **Then** the app chooses General.

---

### User Story 2 - Fewer Wrong-Format Summaries (Priority: P2)

As a user, I want the meeting type used for summarization to be stable and sensible, so that my summary structure matches the meeting (e.g., standups don’t look like planning docs and presentations don’t invent action items).

**Why this priority**: The main value of meeting types is better summaries; improvements should be noticeable in day-to-day usage.

**Independent Test**: Can be tested by sampling a small suite of representative transcripts and verifying the classification aligns with human expectation for “obvious” examples.

**Acceptance Scenarios**:

1. **Given** a daily standup transcript with person-by-person updates and blockers, **When** meeting type is Autodetect, **Then** the app selects Standup.
2. **Given** a transcript that is primarily a talk/demo with Q&A about presented content, **When** meeting type is Autodetect, **Then** the app selects Presentation.

---

### User Story 3 - Predictable Behavior Under Failure (Priority: P3)

As a user, I want Autodetect to behave predictably if classification fails, so that I still get a usable General-style summary rather than a misleading specialized type.

**Why this priority**: Fail-safe behavior preserves trust, reduces surprise, and aligns with the existing “fallback to General” product expectation.

**Independent Test**: Can be tested by forcing invalid or non-matching classifier output and verifying the app uses General.

**Acceptance Scenarios**:

1. **Given** classification output that does not match any supported type, **When** meeting type is Autodetect, **Then** the app uses General.

---

[Add more user stories as needed, each with an assigned priority]

### Edge Cases

- Very short or noisy transcripts (e.g., a few sentences, heavy small talk) should result in General.
- Meetings that genuinely combine multiple formats (e.g., planning + design review) should result in General unless one format clearly dominates.
- Keyword traps (e.g., saying “sprint” once) should not force Planning.
- When the transcript begins with context that is misleading (e.g., a brief agenda) but the meeting content differs, the system should avoid overfitting to early lines and prefer General unless evidence is strong.
- If the classifier produces extra text, punctuation, or multiple labels, the system should treat it as invalid and default to General.

## Requirements *(mandatory)*

<!--
  ACTION REQUIRED: The content in this section represents placeholders.
  Fill them out with the right functional requirements.
-->

### Functional Requirements

- **FR-001**: When the user selects Autodetect, the system MUST select exactly one supported meeting type to drive summarization.
- **FR-002**: The system MUST be conservative: it MUST choose a specific non-General type only when there is strong evidence that the transcript matches that type.
- **FR-003**: If the system is uncertain or the transcript is ambiguous, the system MUST choose General.
- **FR-004**: If the classification output is invalid, unrecognized, or otherwise cannot be mapped to a supported meeting type, the system MUST choose General.
- **FR-005**: The system MUST treat “mixed meetings” (clear signals for multiple different types) as uncertain and choose General unless one type clearly dominates.
- **FR-006**: Supported meeting types for Autodetect MUST include: General, Standup, Design Review, One-on-One, Presentation, Planning.
- **FR-007**: The system MUST not change the app’s core “three files per meeting” output contract as a result of this feature.

### Non-Functional Requirements *(mandatory)*

- **NFR-001**: System MUST preserve local-only processing and avoid outbound
  network calls except model downloads.
- **NFR-002**: System MUST maintain deterministic output for any note rendering
  or contract changes.
- **NFR-003**: Long-running operations MUST support cancellation and avoid
  blocking the UI thread.
- **NFR-004**: UX changes MUST align with the pipeline state machine and
  provide clear user status/errors without leaking internal details.

### Key Entities *(include if feature involves data)*

- **Meeting Type**: One of the supported meeting-type categories used to choose an appropriate summarization style.
- **Classification Uncertainty**: A determination that the available transcript evidence is insufficient, conflicting, or unclear to select a specific non-General meeting type.

## Success Criteria *(mandatory)*

<!--
  ACTION REQUIRED: Define measurable success criteria.
  These must be technology-agnostic and measurable.
-->

### Measurable Outcomes

- **SC-001**: On an internal evaluation set of transcript snippets labeled by humans, Autodetect selects the correct specific type for at least 90% of “clear” examples.
- **SC-002**: On an internal evaluation set of intentionally ambiguous snippets, Autodetect returns General at least 95% of the time.
- **SC-003**: The rate of users needing to manually change meeting type after recording (from Autodetect to another type) decreases compared to the current baseline.
- **SC-004**: No regressions to privacy/local-only constraints: classification and summarization continue to run locally and do not introduce additional network usage.

## Assumptions

- Autodetect remains the default selection for meeting type.
- General is the safest and most broadly acceptable summary format when classification is uncertain.
- The meeting type taxonomy remains unchanged for this feature (General, Standup, Design Review, One-on-One, Presentation, Planning).
