#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(CDPATH="" cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
RELEASE_SCRIPT="$ROOT_DIR/scripts/release-notarize.sh"

make_fake_app() {
  local app_path="$1"
  local updater_enabled="$2"
  mkdir -p "$app_path/Contents/MacOS"
  cat > "$app_path/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleIdentifier</key>
  <string>com.minute.tests.preflight</string>
  <key>CFBundleName</key>
  <string>Minute</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleExecutable</key>
  <string>Minute</string>
  <key>CFBundleVersion</key>
  <string>1</string>
  <key>CFBundleShortVersionString</key>
  <string>0.99.0</string>
  <key>MINUTEEnableUpdater</key>
  <string>${updater_enabled}</string>
</dict>
</plist>
PLIST
  cp /usr/bin/true "$app_path/Contents/MacOS/Minute"
  chmod +x "$app_path/Contents/MacOS/Minute"
}

sign_app_with_entitlements() {
  local app_path="$1"
  local entitlements_file="$2"
  /usr/bin/codesign --force --deep --entitlements "$entitlements_file" --sign - "$app_path"
}

tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT

# Case 1: unsigned app must fail signature preflight
unsigned_app="$tmp_dir/Unsigned.app"
make_fake_app "$unsigned_app" "NO"

unsigned_output="$({
  DIST_PROFILE="app-store" \
  CREATE_DMG=0 \
  CREATE_ZIP=0 \
  GENERATE_APPCAST=0 \
  "$RELEASE_SCRIPT" "$unsigned_app"
} 2>&1 || true)"

if [[ "$unsigned_output" != *"signature"* ]]; then
  echo "expected signature preflight failure output" >&2
  echo "$unsigned_output" >&2
  exit 1
fi

# Case 2: signed app without sandbox entitlement must fail sandbox preflight
signed_no_sandbox="$tmp_dir/SignedNoSandbox.app"
make_fake_app "$signed_no_sandbox" "NO"
/usr/bin/codesign --force --deep --sign - "$signed_no_sandbox"

sandbox_output="$({
  DIST_PROFILE="app-store" \
  CREATE_DMG=0 \
  CREATE_ZIP=0 \
  GENERATE_APPCAST=0 \
  "$RELEASE_SCRIPT" "$signed_no_sandbox"
} 2>&1 || true)"

if [[ "$sandbox_output" != *"sandbox"* ]]; then
  echo "expected sandbox preflight failure output" >&2
  echo "$sandbox_output" >&2
  exit 1
fi

# Case 3: signed app with screen recording entitlement must fail app-store preflight
screen_recording_app="$tmp_dir/ScreenRecording.app"
screen_recording_entitlements="$tmp_dir/screen-recording-entitlements.plist"
make_fake_app "$screen_recording_app" "NO"
cat > "$screen_recording_entitlements" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>com.apple.security.app-sandbox</key>
  <true/>
  <key>com.apple.security.device.screen-recording</key>
  <true/>
</dict>
</plist>
PLIST
sign_app_with_entitlements "$screen_recording_app" "$screen_recording_entitlements"

screen_recording_output="$({
  DIST_PROFILE="app-store" \
  CREATE_DMG=0 \
  CREATE_ZIP=0 \
  GENERATE_APPCAST=0 \
  "$RELEASE_SCRIPT" "$screen_recording_app"
} 2>&1 || true)"

if [[ "$screen_recording_output" != *"screen recording"* ]]; then
  echo "expected screen recording entitlement preflight failure output" >&2
  echo "$screen_recording_output" >&2
  exit 1
fi

# Case 4: updater-enabled app must fail updater policy preflight
updater_enabled_app="$tmp_dir/UpdaterEnabled.app"
updater_enabled_entitlements="$tmp_dir/updater-enabled-entitlements.plist"
make_fake_app "$updater_enabled_app" "YES"
cat > "$updater_enabled_entitlements" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>com.apple.security.app-sandbox</key>
  <true/>
</dict>
</plist>
PLIST
sign_app_with_entitlements "$updater_enabled_app" "$updater_enabled_entitlements"

updater_enabled_output="$({
  DIST_PROFILE="app-store" \
  CREATE_DMG=0 \
  CREATE_ZIP=0 \
  GENERATE_APPCAST=0 \
  "$RELEASE_SCRIPT" "$updater_enabled_app"
} 2>&1 || true)"

if [[ "$updater_enabled_output" != *"self-update behavior"* ]]; then
  echo "expected updater policy preflight failure output" >&2
  echo "$updater_enabled_output" >&2
  exit 1
fi

echo "app-store preflight smoke checks passed"
