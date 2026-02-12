# Releasing Minute

This document describes the profile-driven local release flow and CI follow-up
steps.

## Prerequisites
- Apple Developer Program membership
- Signing identities configured locally
- Notarytool keychain profile (for direct distribution notarization)
- Sparkle keys configured for direct-distribution appcast signing

## Distribution Profiles

Release profile selection is required for `make archive` and `make release`.

- `direct`:
  - updater enabled
  - DMG/ZIP output allowed
  - appcast generation allowed
  - notarization enabled by default
- `app-store`:
  - updater disabled at build time
  - DMG and appcast generation blocked
  - notarization disabled by default (App Store submission channel)

Each run emits a validation summary JSON.
Default summary path: `updates/release-validation-summary.json`

## Build + Release Commands

1. Create a direct-distribution release:
   ```bash
   make release DIST_PROFILE=direct ARCHIVE="/path/to/Minute.xcarchive" \
     NOTARY_PROFILE=minute-notary \
     APPCAST_DOWNLOAD_URL_PREFIX="https://github.com/roblibob/Minute/releases/download/vX.Y.Z/" \
     SPARKLE_APPCAST_ARGS="--ed-key-file $HOME/.config/minute/sparkle_ed25519.key"
   ```

2. Create an App Store release:
   ```bash
   make release DIST_PROFILE=app-store ARCHIVE="/path/to/Minute.xcarchive"
   ```

3. Optional direct-only appcast generation entry point:
   ```bash
   DIST_PROFILE=direct scripts/generate-appcast.sh updates "https://github.com/roblibob/Minute/releases/download/vX.Y.Z/"
   ```

## Dry-Run Mode

For validation-only runs without notarization:

```bash
make release DIST_PROFILE=direct ARCHIVE="/path/to/Minute.app" ENABLE_NOTARIZATION=0 CREATE_DMG=0 CREATE_ZIP=0 GENERATE_APPCAST=0
make release DIST_PROFILE=app-store ARCHIVE="/path/to/Minute.app" CREATE_DMG=0 CREATE_ZIP=0 GENERATE_APPCAST=0
```

Validation summaries from the latest dry-run evidence are stored at:
- `specs/009-app-store-release/artifacts/direct-release-summary.json`
- `specs/009-app-store-release/artifacts/app-store-release-summary.json`

## CI: publish appcast only (direct profile)

Workflow: `.github/workflows/publish-appcast.yml`
- Trigger: release published (or manual dispatch)
- Action: publish `appcast.xml` to `roblibob/roblibob.github.io/appcast.xml`
- Secret required: `APPCAST_PUBLISH_TOKEN`

## CI: update Homebrew cask (direct profile)

Workflow: `.github/workflows/update-brew-cask.yml`
- Trigger: release published
- Action: update tap with released DMG SHA
- Secret required: `BREW_TAP_TOKEN`

## Troubleshooting
- `error: DIST_PROFILE is required`: provide `DIST_PROFILE=direct` or `DIST_PROFILE=app-store`
- App Store preflight failure: fix signing, sandbox entitlement, or updater policy mismatch
- Direct appcast failure: ensure `DIST_PROFILE=direct` and valid `SPARKLE_APPCAST_ARGS`
