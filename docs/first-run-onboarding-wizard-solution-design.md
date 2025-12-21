# First-Run Onboarding Wizard Solution Design

## Goal
Present a first-run wizard in the main content window that guides the user through required permissions and vault setup, then exits to the normal app UI once all requirements are satisfied.

## Non-goals
- Replace or remove the existing Settings screen.
- Change the recording/transcription/summarization pipeline.
- Persist identities or sync settings across devices.

## Constraints (from AGENT.md and docs)
- macOS 14+ native app with SwiftUI.
- No outbound network calls except model downloads.
- Vault access uses security-scoped bookmarks.
- UI stays thin; business logic stays in MinuteCore when practical.
- Permissions for microphone and screen recording must be requested via system prompts.

## Proposed Architecture
Introduce a lightweight onboarding flow that gates the main UI until requirements are met.

### New Views
- `OnboardingView`
  - Hosts a wizard-style UI in the main window.
  - Renders step content and a bottom action bar (Continue/Done).
- `OnboardingStepIntroView`
  - Short description of Minute and why permissions are needed.
- `OnboardingStepPermissionsView`
  - Big permission buttons with status icons (red X / green check).
  - Actions request microphone and screen recording access.
- `OnboardingStepModelsView`
  - Shows model readiness status (checkmark vs retry icon).
  - Allows download/retry of required whisper and llama models.
- `OnboardingStepVaultView`
  - Reuses vault picker and path fields from Settings.

### New View Model
- `OnboardingViewModel` (Minute target)
  - Tracks current step, completion status, and button enablement.
  - Depends on:
    - `PermissionStatusProvider` (wrapper around AVFoundation and CG preflight)
    - `ModelStatusProvider` (wraps `ModelManaging` and checksum verification)
    - `VaultStatusProvider` (uses existing `VaultAccess`/bookmark store)
  - Exposes `isComplete` to allow app root to switch to main UI.

### Shared Subviews
Extract a reusable `VaultConfigurationView` from Settings so the wizard and Settings share the same UI and logic (picker + path text fields + verify).

## Wizard State Model
```
enum OnboardingStep: Int {
    case intro
    case permissions
    case models
    case vault
    case complete
}

struct OnboardingRequirements {
    var microphoneGranted: Bool
    var screenRecordingGranted: Bool
    var modelsReady: Bool
    var vaultConfigured: Bool
}
```

- `OnboardingViewModel.currentStep` is derived from `OnboardingRequirements`:
  - If `!microphoneGranted` or `!screenRecordingGranted` -> `.permissions`
  - Else if `!modelsReady` -> `.models`
  - Else if `!vaultConfigured` -> `.vault`
  - Else -> `.complete`
- `intro` is always shown on first run before computing requirements.

## Persistence and Restart Behavior
- Store `didShowIntro` and `didCompleteOnboarding` in `UserDefaults` (or `@AppStorage`).
- On launch:
  - If `didCompleteOnboarding` is true and all requirements are still met, show `ContentView`.
  - Otherwise, show `OnboardingView` and compute `currentStep` from live statuses.
- When requesting screen recording:
  - Call `CGRequestScreenCaptureAccess()`.
  - Present a short message: "Requires restart to take effect."
  - Do not advance; after restart, `CGPreflightScreenCaptureAccess()` will drive the green checkmark.
- Model readiness:
  - Validate model presence and checksums on launch and after download.
  - If checksums fail, remain on the Models step with a retry affordance.

## UI Flow
1. Intro
   - Short description of what Minute does.
   - "Continue" advances to Permissions.
2. Permissions
   - Two large buttons:
     - "Microphone Access"
     - "Screen + System Audio Recording"
   - Each button includes a trailing status icon:
     - Red X when missing
     - Green check when granted
   - "Continue" enabled only when both permissions are granted.
3. Models
   - Check required whisper and llama models for presence and checksum validity.
   - Show a progress indicator and overall status (pending/in progress/complete).
   - Status icon:
     - Green check when all checksums pass.
     - Retry icon when any required model is missing or invalid.
   - "Continue" enabled only when all required models pass checksum verification.
   - Retry action re-downloads missing/invalid models.
4. Vault
   - Directory picker for vault root.
   - Path fields for Meetings, _audio, _transcripts (reuse Settings).
   - Checkmark appears when vault root is selected and verification succeeds.
   - "Done" replaces "Continue" and completes onboarding.

## Error Handling
- Permission requests that are denied:
  - Keep red X and show a short inline explanation.
  - Provide a "Open System Settings" action if needed.
- Model downloads or checksum verification failures:
  - Show a retry icon and a short inline error.
  - Allow re-download without leaving the step.
- Vault selection or verification failure:
  - Reuse existing error messages from `VaultSettingsModel`.
  - Keep the step locked until verification passes.

## Testing Plan
- Unit tests (MinuteCore if refactored, otherwise in Minute target):
  - Step derivation given various `OnboardingRequirements`.
  - Persistence of `didShowIntro` and `didCompleteOnboarding`.
  - Model readiness gating when checksums fail.
- Manual QA:
  - Fresh install: intro -> permissions -> models -> vault -> main UI.
  - Deny microphone, then allow: status updates.
  - Request screen recording, restart app: wizard resumes with updated status.
  - Missing or corrupted model: retry icon shows; re-download succeeds; continue enabled.
  - Vault selection persists across relaunch.

## Risks and Mitigations
- Permission state divergence after app restart: always derive current step from live permission checks.
- UI duplication between Settings and onboarding: extract shared view to avoid drift.
- Users revoke permissions later: show an inline banner on the main screen and optionally re-open onboarding.
- Partial/corrupt model downloads: rely on checksum verification and re-download on failure.

## Open Questions
- Should onboarding reappear if permissions are later revoked, or should we show a warning only?
- Do we want a "Quit and Relaunch" button after requesting screen recording to encourage restart?
