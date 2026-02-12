# Implementation Plan: App Store Release Readiness

**Branch**: `009-app-store-release` | **Date**: 2026-02-11 | **Spec**: [specs/009-app-store-release/spec.md](spec.md)
**Input**: Feature specification from [specs/009-app-store-release/spec.md](spec.md)

**Note**: This template is filled in by the `/speckit.plan` command. See `.specify/templates/commands/plan.md` for the execution workflow.

## Summary

Add profile-driven release behavior so the same project can produce both App Store and direct-distribution releases safely.

Core outcomes:
- App Store release profile validates signatures and sandbox policy before release output.
- App Store profile disables self-update behavior at build time.
- Direct-distribution profile preserves existing updater and appcast workflow.
- Existing release scripts and Makefile entry points drive both profiles without manual script edits.

## Technical Context

**Language/Version**: Swift 5.9 (Xcode 15.x) + Bash (release scripts)  
**Primary Dependencies**: SwiftUI, MinuteCore, Sparkle (direct-distribution profile only), Xcode signing/notary tooling (`codesign`, `xcrun`, `xcodebuild`)  
**Storage**: Files (archives, packaged artifacts, appcast, validation summaries)  
**Testing**: Swift Testing/XCTest for app behavior + script-level integration checks for profile selection and preflight failures  
**Target Platform**: macOS 14+ (App Store Connect and direct distribution channels)
**Project Type**: Native macOS app + shell-based release automation  
**Performance Goals**: Profile preflight checks complete in under 2 minutes on a standard release machine; fail fast before packaging when invalid  
**Constraints**: Local-only app behavior; no outbound network at runtime except model downloads; deterministic meeting output contract unchanged; App Store profile must not expose self-update controls  
**Scale/Scope**: One app target, one Xcode project, two release profiles, and existing release pipeline scripts

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

- Output contract unchanged or updated docs/tests included.
- Local-only processing preserved; no outbound network calls beyond model downloads.
- Deterministic Markdown rendering maintained for any note changes.
- MinuteCore tests added/updated for new behavior (renderer, file contracts, JSON validation).
- Pipeline state machine and cancellation support respected for long-running work.

**Gate evaluation (pre-design)**: PASS

- Output contract: unchanged (release/distribution feature only).
- Local-only: unchanged runtime network policy.
- Determinism: unchanged rendering and file contract behavior.
- Tests: plan requires tests for profile-policy evaluation and updater profile gating.
- Pipeline/cancellation: no changes to meeting pipeline flow.

## Project Structure

### Documentation (this feature)

```text
specs/[###-feature]/
├── plan.md              # This file (/speckit.plan command output)
├── research.md          # Phase 0 output (/speckit.plan command)
├── data-model.md        # Phase 1 output (/speckit.plan command)
├── quickstart.md        # Phase 1 output (/speckit.plan command)
├── contracts/           # Phase 1 output (/speckit.plan command)
└── tasks.md             # Phase 2 output (/speckit.tasks command - NOT created by /speckit.plan)
```

```text
specs/009-app-store-release/
├── plan.md
├── research.md
├── data-model.md
├── quickstart.md
├── contracts/
│   └── openapi.yaml
└── checklists/
    └── requirements.md
```

### Source Code (repository root)

```text
Minute/
├── Sources/App/                     # App entry point and updater wiring
├── Sources/ViewModels/              # Updater view model/profile-aware behavior
└── Sources/Views/Settings/          # Profile-dependent update UI visibility

Config/
└── MinuteInfo.plist                 # Channel/profile-sensitive updater metadata

scripts/
├── release-notarize.sh              # Existing release flow to be profile-aware
├── sign-hardened-runtime.sh         # Embedded signing flow to be profile-aware
├── generate-appcast.sh              # Direct-distribution only
└── build-release-dmg.sh             # Direct-distribution only

Makefile                             # Profile-aware release entry points
Minute.xcodeproj/project.pbxproj     # Build settings, compilation conditions, profile configs

MinuteCore/
└── Tests/MinuteCoreTests/           # Policy/validation tests for new release profile logic (if modeled in core)
```

**Structure Decision**: Keep app behavior gating in app target and keep packaging/signing orchestration in existing shell scripts; introduce profile-policy primitives in shared code only where testability requires it.

## Complexity Tracking

> **Fill ONLY if Constitution Check has violations that must be justified**

| Violation | Why Needed | Simpler Alternative Rejected Because |
|-----------|------------|-------------------------------------|
| None | N/A | N/A |

## Phase 0 — Research (complete)

Outputs:
- [specs/009-app-store-release/research.md](research.md)

Key resolutions:
- Selected explicit distribution profile model (`app-store` vs `direct`).
- Defined profile-specific release checks and packaging rules.
- Defined channel-safe updater behavior approach (disabled in App Store profile, preserved in direct profile).
- Defined script integration pattern for Makefile and existing release scripts.

## Phase 1 — Design & Contracts (complete)

Outputs:
- [specs/009-app-store-release/data-model.md](data-model.md)
- [specs/009-app-store-release/contracts/openapi.yaml](contracts/openapi.yaml)
- [specs/009-app-store-release/quickstart.md](quickstart.md)

Design notes:
- Add a first-class distribution profile concept shared by release orchestration and app behavior gating.
- Add release validation summary model for script output and QA traceability.
- Keep direct-distribution Sparkle/appcast behavior untouched under the `direct` profile.

**Constitution re-check (post-design)**: PASS

- Output contract: preserved; no meeting artifact format/path changes.
- Local-only + privacy: preserved; no new runtime outbound calls.
- Determinism: note rendering/output unchanged.
- Tests: design includes test coverage for profile selection, updater gating, and release preflight validation outcomes.
- Pipeline/cancellation: no long-running pipeline regressions introduced.

## Phase 2 — Implementation Planning (next step)

Proceed with `/speckit.tasks` to generate a task breakdown for:
- Build/profile configuration updates (App Store vs direct distribution)
- Updater gating and settings/menu behavior per profile
- Release script and Makefile profile integration with fail-fast validation summaries
- Automated tests and release-focused manual QA checklist coverage
