# Quickstart: App Store Release Readiness

**Branch**: 009-app-store-release  
**Date**: 2026-02-11

## Prerequisites

- Apple Developer credentials configured on the release machine.
- A valid archive build input for the target version.
- Existing release prerequisites from `docs/releasing.md` are satisfied.

## Build

- Create a release archive:
  - `xcodebuild -workspace Minute.xcworkspace -scheme Minute -configuration Release -destination 'generic/platform=macOS' -archivePath build/Minute.xcarchive MINUTE_DISTRIBUTION_PROFILE=direct archive`
  - `xcodebuild -workspace Minute.xcworkspace -scheme Minute -configuration Release -destination 'generic/platform=macOS' -archivePath build/Minute.xcarchive MINUTE_DISTRIBUTION_PROFILE=app-store MINUTE_ENABLE_UPDATER=NO MINUTE_SU_FEED_URL= archive`

## Automated Checks

- Run tests (project):
  - `xcodebuild -project Minute.xcodeproj -scheme Minute -configuration Debug test -destination 'platform=macOS'`

- Run core package tests:
  - `xcodebuild -workspace Minute.xcworkspace -scheme MinuteCore -configuration Debug test -destination 'platform=macOS'`

## Profile Validation Runs

1. App Store profile run:
   - Start release flow using `app-store` profile.
   - Confirm preflight includes signature, sandbox-policy, updater-policy, and profile-config checks.
   - Confirm direct-only artifacts (appcast, DMG) are not generated.
   - Confirm release summary is generated with pass/fail results.

2. Direct profile run:
   - Start release flow using `direct` profile.
   - Confirm existing direct distribution artifacts are generated.
   - Confirm updater policy remains enabled.
   - Confirm appcast generation behavior remains unchanged.

## Manual QA (focused)

1. Launch App Store-profile build and verify no self-update menu action or update settings controls are available.
2. Launch direct-profile build and verify update controls remain available.
3. Execute a failure-path App Store run (for example, invalid signing input) and verify fail-fast behavior before packaging.
4. Verify each run emits a validation summary with profile, checks, and final status.
5. Verify meeting capture/transcription/summarization behavior is unchanged and still local-only.

## Guardrails

- Do not alter the deterministic vault output contract (exactly three files per processed meeting).
- Do not add runtime outbound network calls beyond model downloads.
- Keep release profile selection explicit; avoid implicit profile inference.

## Execution Notes (2026-02-11)

- `bash scripts/tests/run-release-tests.sh` passed all release smoke tests:
  - `release-profile-args-smoke.sh`
  - `release-app-store-preflight-smoke.sh`
  - `release-direct-profile-smoke.sh`
  - `release-app-store-artifacts-smoke.sh`
- `xcodebuild -project Minute.xcodeproj -scheme Minute -configuration Debug test -destination 'platform=macOS'` passed with 14 tests (including updater profile suites).
- `xcodebuild -workspace Minute.xcworkspace -scheme MinuteCore -configuration Debug test -destination 'platform=macOS'` passed with 159 tests.
- Profile dry-run summaries were generated at:
  - `specs/009-app-store-release/artifacts/direct-release-summary.json`
  - `specs/009-app-store-release/artifacts/app-store-release-summary.json`
