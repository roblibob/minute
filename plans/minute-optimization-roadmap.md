# Minute Optimization Roadmap

Status: draft starter roadmap (v0). This is a working document that should evolve as we implement and measure.

## Goals

- Reduce duplication and sharpen boundaries between UI and core logic.
- Improve performance and memory usage without changing v1 behavior.
- Keep the output contract stable and deterministic.

## Guardrails (non-negotiable)

- v1 output contract from `docs/overview.md` stays stable.
- Exactly three files written to the vault per meeting.
- WAV format: mono, 16 kHz, 16-bit PCM, verified after export.
- No outbound network calls except model downloads.
- Model output is JSON only; Markdown is rendered deterministically.
- Atomic writes for vault outputs.
- Do not log raw transcripts by default.

## Inputs and References

- `docs/overview.md` (contract and architecture)
- `docs/tasks/` (execution order)
- `plans/minute-optimization-plan.md` (issue inventory)
- `plans/minute-implementation-priorities.md` (tactical steps)
- `plans/minute-performance-optimizations.md` (perf ideas)

## Roadmap Phases

### Phase 0: Baseline and Observability (1 week)

Deliverables:
- Add OSLog signposts for pipeline phases (record, transcribe, summarize, write).
- Capture simple timing metrics (wall time per phase) and memory snapshots.
- Document current performance baselines for a representative 30-60 min meeting.

Tests:
- Confirm signposts compile in release and do not log transcript content.

### Phase 1: Foundation and Determinism (1-2 weeks)

Deliverables:
- Centralize string normalization (single utility) and update renderer/validation.
- Consolidate configuration access into a single type with validation.
- Standardize error mapping to a small `MinuteError` set and consistent UI messages.
- Ensure all vault writes use the atomic writer in `MinuteCore`.
- Add/expand tests for renderer, filename sanitization, and file contract paths.

Exit criteria:
- No duplicate string normalization logic.
- Atomic write used for all vault outputs.
- Renderer and path tests cover the fixed contract.

### Phase 2: State and Service Organization (2-3 weeks)

Deliverables:
- Split `MeetingPipelineViewModel` into focused view models (recording, processing).
- Move business logic into `MinuteCore` coordinators/services.
- Introduce a single composition root for service construction (no ad-hoc init).
- Standardize progress reporting across pipeline stages.

Exit criteria:
- UI layer owns presentation only; core owns orchestration.
- Pipeline state transitions are centralized and testable.

### Phase 3: Performance and Resource Management (2-3 weeks)

Deliverables:
- Stream or chunk audio processing to reduce peak memory.
- Prefer ffmpeg-based WAV conversion when available; verify format after export.
- Buffer file I/O and ensure proper cleanup on cancellation.
- Progressive model loading with responsive UI progress.
- Audit concurrency for cancellation support in long-running tasks.

Exit criteria:
- Memory usage does not spike with long recordings.
- WAV format validation is enforced before writing to vault.

### Phase 4: UX and Resilience (1-2 weeks)

Deliverables:
- Improve progress UI clarity and failure recovery guidance.
- Consistent error messaging and retry options per failure class.
- Verify sandbox bookmark flows and vault access reliability.

Exit criteria:
- Users can recover from common failures without relaunching.
- Manual QA checklist in `docs/tasks/10-packaging-sandbox-signing-and-qa.md` passes.

## Open Questions

- Which performance baselines best reflect real usage (duration, input devices)?
- Do we want a service locator or a more explicit DI graph?
- Where should progress instrumentation live (core vs UI)?

## Definition of Done (for any phase)

- Tests updated and passing for impacted components.
- Docs updated if note format or paths change.
- No new outbound network calls beyond model downloads.
