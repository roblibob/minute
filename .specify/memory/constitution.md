<!--
Sync Impact Report
- Version: N/A -> 0.1.0
- Modified Principles: None (initial constitution)
- Added Sections: Product Constraints (v1), Development Workflow & Quality Gates
- Removed Sections: None
- Templates requiring updates:
  - ✅ .specify/templates/plan-template.md
  - ✅ .specify/templates/spec-template.md
  - ✅ .specify/templates/tasks-template.md
  - ⚠️ .specify/templates/commands/*.md (directory missing)
- Follow-up TODOs:
  - TODO(RATIFICATION_DATE): Original adoption date unknown.
-->
# Minute Constitution

## Core Principles

### I. Deterministic Output Contract
The app MUST write exactly three files per processed meeting with the defined
paths, and the note content MUST be rendered deterministically from JSON-only
model output. Any change to file paths, note structure, or rendering rules MUST
update docs and tests in the same change. This protects long-term vault
stability and user automation.

### II. Local-Only Processing and Privacy
All audio capture, transcription, and summarization MUST run locally. The only
permitted outbound network access is for model downloads. Logs MUST avoid raw
transcript content by default. This preserves the local-first privacy contract.

### III. Test-Gated Core Logic
Every new feature or contract change MUST add or update tests in MinuteCore,
including golden tests for Markdown rendering and validations for file contracts
and JSON decoding. Tests MUST be written to verify deterministic behavior. This
ensures reliability of the output contract and pipeline behavior.

### IV. Consistent, Predictable UX
User-facing flows MUST follow the single pipeline state machine and surface
clear status and errors without leaking internal details. UI code stays thin and
delegates business logic to MinuteCore. This keeps the product coherent and
maintainable. UX SHOULD follow apple guidelines for Human Interfaces, however some UI elements are can be excempted if there is a good valid reason.

### V. Performance and Responsiveness
Recording, transcription, summarization, and file writes MUST be cancellable,
non-blocking to the UI, and optimized for macOS 14+ on Apple Silicon. Audio
conversion MUST produce mono 16 kHz 16-bit PCM WAV output, verified after
conversion. This protects real-time usability.

### VI. Test-Driven Development (NON-NEGOTIABLE)
All features MUST follow strict TDD workflow using Swift Testing. Write tests → Watch fail (red) → Implement minimal code (green) → Refactor → Commit.

### VII. SOLID Principles & Functional Programming
Code MUST follow SOLID principles with emphasis on Single Responsibility, Dependency Inversion. Prefer functional patterns where they improve clarity; imperative is acceptable when clearer.

## Product Constraints (v1)

- Native macOS app (Swift + SwiftUI), macOS 14+.
- Audio recorded locally; transcription via Fluidaudio; screen context and summarization via llama.
- Exactly three files per meeting:
  - Meetings/YYYY/MM/YYYY-MM-DD HH.MM - <Title>.md
  - Meetings/_audio/YYYY-MM-DD HH.MM - <Title>.wav
  - Meetings/_transcripts/YYYY-MM-DD HH.MM - <Title>.md
- WAV format: mono, 16 kHz, 16-bit PCM.
- No outbound network calls except model downloads.

## Development Workflow & Quality Gates

- UI stays thin; non-UI logic resides in MinuteCore behind clear interfaces.
- Use Swift Concurrency; long-running operations MUST support cancellation.
- Use a small set of domain errors (MinuteError) with concise user messaging.
- Atomic file writes are mandatory for all vault output.
- All changes that affect output format or paths MUST update docs and tests.
- Manual QA checklist in docs/tasks/10-packaging-sandbox-signing-and-qa.md MUST
  be completed before release.

### Pre-Development Checklist
Before starting ANY feature work:
- [ ] Spec created in `specs/<###-feature-name>/spec.md` with prioritized user stories
- [ ] User stories MUST be independently testable (each story = viable MVP increment)
- [ ] Plan created with constitution check passed

### Code Review Requirements
All PRs MUST pass before merge:
- [ ] All tests pass
- [ ] Build succeeds 
- [ ] Test coverage meets thresholds (100% for critical paths, 80%+ for features)
- [ ] Naming conventions followed
- [ ] Constitution compliance verified

### Git Workflow
- Feature branches from `main` with naming: `<###-feature-name>`
- Commit messages follow Conventional Commits: `feat:`, `fix:`, `docs:`, `refactor:`, `test:`
- Squash merge on approval (clean history)
- NO force pushes to `main`
- NO commits directly to `main` (all changes via PR)

## Governance

- This constitution supersedes other guidance when conflicts arise.
- Amendments require: documentation update, test updates (if behavior changes),
  and explicit version bump using semantic versioning for the constitution.
- Compliance review is required for every spec/plan: verify principles, output
  contract, and local-only constraints before implementation.
  
**Version**: 0.1.0 | **Ratified**: TODO(RATIFICATION_DATE): Original adoption date unknown. | **Last Amended**: 2026-02-03
