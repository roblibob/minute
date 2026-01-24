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

3. Generate and commit the appcast (copied to `appcast.xml` in repo root):
   ```
   APPCAST_DOWNLOAD_URL_PREFIX="https://github.com/roblibob/Minute/releases/download/vX.Y.Z/" \
   SPARKLE_APPCAST_ARGS="--ed-key-file $HOME/.config/minute/sparkle_ed25519.key" \
   scripts/generate-appcast.sh updates
   ```

4. Commit `appcast.xml` to `main`.
5. Upload the release assets to GitHub Releases:
   - `updates/Minute-<version>.dmg`
   - `updates/Minute-<version>.zip`

6. The GitHub Actions workflow publishes `updates/appcast.xml` to
   `https://roblibob.github.io/appcast.xml`.

## Makefile shortcut
```
make release ARCHIVE="/path/to/Minute.xcarchive" \
  NOTARY_PROFILE=minute-notary \
  APPCAST_DOWNLOAD_URL_PREFIX="https://github.com/roblibob/Minute/releases/download/vX.Y.Z/" \
  SPARKLE_APPCAST_ARGS="--ed-key-file $HOME/.config/minute/sparkle_ed25519.key"
```

This runs notarization + stapling + DMG/ZIP generation, then regenerates
`appcast.xml` using the ZIP only (Sparkle does not accept duplicate DMG+ZIP).
You still commit the appcast and publish the assets.

## CI: publish appcast only
Workflow: `.github/workflows/publish-appcast.yml`
- Trigger: push to `main` when `appcast.xml` changes
- Action: copy appcast to `roblibob/roblibob.github.io/appcast.xml`
- Secret required: `APPCAST_PUBLISH_TOKEN` (PAT with write access to the pages repo)

## Troubleshooting
- Notarytool stuck: resubmit with `xcrun notarytool submit ... --wait`
- Gatekeeper “Unnotarized”: ensure you stapled the app and DMG
- Sparkle signature missing: pass `SPARKLE_APPCAST_ARGS` with your private key
