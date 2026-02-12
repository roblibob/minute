# Release QA: App Store Release Readiness

**Feature**: `009-app-store-release`  
**Date**: 2026-02-11  
**Owner**: Codex execution log

## Focused QA Checklist

1. App Store profile hides update controls  
Status: PASS  
Evidence:
- `UpdaterProfileBehaviorTests.settingsSections_hideUpdatesWhenUpdaterDisabled`
- `UpdaterViewModelProfileTests.disabledMode_noopsUpdateActions`

2. Direct profile retains update controls  
Status: PASS  
Evidence:
- `UpdaterProfileBehaviorTests.settingsSections_includeUpdatesWhenUpdaterEnabled`
- `UpdaterViewModelProfileTests.enabledMode_updatesDriverState`

3. App Store release preflight fails fast for invalid signing/entitlements  
Status: PASS  
Evidence:
- `scripts/tests/release-app-store-preflight-smoke.sh`

4. Profile-specific artifact policy is enforced  
Status: PASS  
Evidence:
- `scripts/tests/release-direct-profile-smoke.sh`
- `scripts/tests/release-app-store-artifacts-smoke.sh`

5. Validation summary is emitted per run  
Status: PASS  
Evidence:
- `specs/009-app-store-release/artifacts/direct-release-summary.json`
- `specs/009-app-store-release/artifacts/app-store-release-summary.json`

6. Regression risk check for core app behavior  
Status: PASS  
Evidence:
- `xcodebuild -project Minute.xcodeproj -scheme Minute -configuration Debug test -destination 'platform=macOS'` (14 tests passed)
- `xcodebuild -workspace Minute.xcworkspace -scheme MinuteCore -configuration Debug test -destination 'platform=macOS'` (159 tests passed)

## Notes

- GUI-interactive release submission to App Store Connect was not executed in this QA pass.
- This QA run validates local build/profile gating, preflight checks, and release script behavior.
