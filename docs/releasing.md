# Releasing Minute

This document describes the local release flow and the lightweight CI step that
publishes the Sparkle appcast to GitHub Pages.

## Prerequisites
- Apple Developer Program membership
- Developer ID Application certificate installed
- Notarytool keychain profile (example name: `minute-notary`)
- Sparkle public key already in `Config/MinuteInfo.plist`
- Sparkle private key available locally for signing the appcast (recommended)

## Local release flow (authoritative)
1. Archive in Xcode (Release configuration).
2. Run the release script (notarizes + staples + builds artifacts):
   ```
   scripts/release-notarize.sh "/path/to/Minute.xcarchive"
   ```

3. Generate the appcast (stored in `updates/appcast.xml` alongside the artifacts):
   ```
   APPCAST_DOWNLOAD_URL_PREFIX="https://github.com/roblibob/Minute/releases/download/vX.Y.Z/" \
   SPARKLE_APPCAST_ARGS="--ed-key-file $HOME/.config/minute/sparkle_ed25519.key" \
   scripts/generate-appcast.sh updates
   ```

4. Upload the release assets to GitHub Releases:
   - `updates/Minute-<version>.dmg`
   - `updates/Minute-<version>.zip`
   - `updates/appcast.xml`

5. The GitHub Actions workflow publishes `appcast.xml` to
   `https://roblibob.github.io/appcast.xml`.
6. The Homebrew cask is updated automatically after the GitHub Release is published.

## Makefile shortcut
```
make release ARCHIVE="/path/to/Minute.xcarchive" \
  NOTARY_PROFILE=minute-notary \
  APPCAST_DOWNLOAD_URL_PREFIX="https://github.com/roblibob/Minute/releases/download/vX.Y.Z/" \
  SPARKLE_APPCAST_ARGS="--ed-key-file $HOME/.config/minute/sparkle_ed25519.key"
```

This runs notarization + stapling + DMG/ZIP generation, then regenerates
`updates/appcast.xml` using the ZIP only (Sparkle does not accept duplicate DMG+ZIP).
You upload the appcast as a release asset alongside the DMG/ZIP.

## CI: publish appcast only
Workflow: `.github/workflows/publish-appcast.yml`
- Trigger: release published (or manual dispatch)
- Action: download `appcast.xml` from the GitHub Release assets and copy it to `roblibob/roblibob.github.io/appcast.xml`
- Secret required: `APPCAST_PUBLISH_TOKEN` (PAT with write access to the pages repo)

## CI: update Homebrew cask
Workflow: `.github/workflows/update-brew-cask.yml`
- Trigger: release published
- Action: download `Minute-<version>.dmg`, compute SHA256, update the tap cask
- Secret required: `BREW_TAP_TOKEN` (PAT with write access to `roblibob/homebrew-minute`)

## Homebrew tap (local)
Tap repo lives at:
`~/Projects/FLX/Minute/homebrew-minute`

## Troubleshooting
- Notarytool stuck: resubmit with `xcrun notarytool submit ... --wait`
- Gatekeeper “Unnotarized”: ensure you stapled the app and DMG
- Sparkle signature missing: pass `SPARKLE_APPCAST_ARGS` with your private key
