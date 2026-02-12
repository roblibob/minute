# Research: App Store Release Readiness

**Branch**: 009-app-store-release  
**Date**: 2026-02-11

## Goals

- Make App Store and direct-distribution releases selectable through one consistent release workflow.
- Ensure signature and sandbox validation failures stop the release before packaging/submission.
- Ensure App Store builds do not expose self-update behavior while direct builds retain it.
- Integrate profile handling into existing scripts and Makefile commands.

## Research Inputs

- Repository sources: `scripts/release-notarize.sh`, `scripts/sign-hardened-runtime.sh`, `Makefile`, `Minute/Sources/App/MinuteApp.swift`, `Minute/Sources/ViewModels/UpdaterViewModel.swift`, `Minute.xcodeproj/project.pbxproj`.
- Existing product constraints: local-only runtime behavior and deterministic 3-file meeting output contract.
- External policy references (primary sources): Apple App Review Guidelines (macOS) and App Sandbox/entitlement guidance.

## Decisions

### 1. Release profile must be explicit and required

**Decision**: Introduce a required distribution profile value with two allowed values: `app-store` and `direct`.

**Rationale**: A required explicit profile prevents accidental mixing of App Store and direct-distribution release steps.

**Alternatives considered**:
- Infer profile from signing identity (rejected: brittle and opaque to operators).
- Maintain separate scripts per channel (rejected: duplicates logic and increases drift risk).

### 2. App Store profile should fail fast on preflight validation

**Decision**: Run signature and sandbox-policy preflight checks before generating final artifacts or submission handoff.

**Rationale**: Fast failure reduces operator time and prevents invalid artifacts entering submission flow.

**Alternatives considered**:
- Validate only after packaging (rejected: slower feedback and wasted release work).
- Rely only on App Store upload diagnostics (rejected: too late in the process).

### 3. Updater behavior must be build-profile gated

**Decision**: App Store profile excludes self-update behavior at build time; direct profile keeps current update flow.

**Rationale**: Channel-safe behavior must be guaranteed by build configuration, not runtime operator memory.

**Alternatives considered**:
- Runtime toggle only (rejected: higher risk of shipping incorrect behavior).
- Keep updater code in all channels but hide UI only (rejected: insufficient policy safety).

### 4. Existing release script is the integration point

**Decision**: Extend `scripts/release-notarize.sh` and `Makefile release` with profile-aware branching instead of adding a new top-level release tool.

**Rationale**: Current release process already depends on these entry points; extending them minimizes retraining and migration costs.

**Alternatives considered**:
- New standalone release orchestrator script (rejected: operational duplication).
- Manual profile-specific command recipes only in docs (rejected: high operator error risk).

### 5. App Store and direct packaging outputs should be profile-specific

**Decision**: `direct` profile retains DMG/ZIP/appcast flow; `app-store` profile produces only App Store-relevant outputs and skips direct-only artifacts.

**Rationale**: This keeps artifacts aligned with distribution channel requirements and avoids accidental appcast-related outputs in App Store runs.

**Alternatives considered**:
- Always generate all artifacts for both profiles (rejected: unnecessary work and compliance ambiguity).
- Remove direct artifacts for all profiles (rejected: breaks existing non-App-Store distribution).

### 6. Release validation summary must be generated every run

**Decision**: Persist a per-run validation summary containing profile, checks executed, check outcomes, and final pass/fail.

**Rationale**: Operators need auditable evidence for release QA and debugging.

**Alternatives considered**:
- Console logs only (rejected: hard to audit and compare across runs).
- Manual checklist without machine output (rejected: not reliable at release time).

### 7. Test strategy must include app behavior and release automation

**Decision**: Add automated coverage for profile policy selection and updater gating, plus script integration checks for preflight failures and profile branching.

**Rationale**: This feature spans Swift app behavior and Bash release automation; both layers need regression coverage.

**Alternatives considered**:
- UI-only manual verification (rejected: misses script regressions).
- Script-only checks (rejected: misses shipped app behavior differences).

## Resolved Clarifications

- Required profile names and behavior boundaries are defined.
- App Store preflight validation gates are defined.
- Updater behavior policy per profile is defined.
- Artifact generation expectations per profile are defined.

No unresolved `NEEDS CLARIFICATION` items remain.
