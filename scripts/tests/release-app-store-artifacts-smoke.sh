#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(CDPATH="" cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
RELEASE_SCRIPT="$ROOT_DIR/scripts/release-notarize.sh"
APP_STORE_ENTITLEMENTS="$ROOT_DIR/Minute/Sources/App/MinuteAppStore.entitlements"

make_fake_app() {
  local app_path="$1"
  mkdir -p "$app_path/Contents/MacOS"
  cat > "$app_path/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleIdentifier</key>
  <string>com.minute.tests.appstore</string>
  <key>CFBundleName</key>
  <string>Minute</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleExecutable</key>
  <string>Minute</string>
  <key>CFBundleVersion</key>
  <string>1</string>
  <key>CFBundleShortVersionString</key>
  <string>1.2.3</string>
  <key>MINUTEEnableUpdater</key>
  <string>NO</string>
</dict>
</plist>
PLIST
  cp /usr/bin/true "$app_path/Contents/MacOS/Minute"
  chmod +x "$app_path/Contents/MacOS/Minute"
}

tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT

app_path="$tmp_dir/Minute.app"
output_dir="$tmp_dir/updates"
summary_path="$output_dir/app-store-summary.json"
entitlements_file="$tmp_dir/entitlements.plist"

make_fake_app "$app_path"

cat > "$entitlements_file" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>com.apple.security.app-sandbox</key>
  <true/>
</dict>
</plist>
PLIST

/usr/bin/codesign --force --deep --entitlements "$entitlements_file" --sign - "$app_path"

DIST_PROFILE="app-store" \
CREATE_DMG=0 \
CREATE_ZIP=1 \
GENERATE_APPCAST=0 \
OUTPUT_DIR="$output_dir" \
RELEASE_SUMMARY_PATH="$summary_path" \
"$RELEASE_SCRIPT" "$app_path"

zip_path="$output_dir/Minute-1.2.3.zip"
if [ ! -f "$zip_path" ]; then
  echo "expected app-store profile ZIP artifact at $zip_path" >&2
  exit 1
fi

if [ -f "$output_dir/Minute-1.2.3.dmg" ]; then
  echo "app-store profile must not produce a DMG artifact" >&2
  exit 1
fi

if [ -f "$output_dir/appcast.xml" ]; then
  echo "app-store profile must not produce appcast output" >&2
  exit 1
fi

if zipinfo -1 "$zip_path" | grep -Eq '(^|/)\._'; then
  echo "app-store ZIP must not contain AppleDouble sidecar entries" >&2
  exit 1
fi

unzipped_dir="$tmp_dir/unzipped"
mkdir -p "$unzipped_dir"
(
  cd "$unzipped_dir"
  unzip -q "$zip_path"
)

if ! /usr/bin/codesign --verify --deep --strict "$unzipped_dir/Minute.app" >/dev/null 2>&1; then
  echo "unzipped app-store ZIP app must pass code-sign verification" >&2
  exit 1
fi

if ! grep -q "com.apple.security.temporary-exception.shared-preference.read-write" "$APP_STORE_ENTITLEMENTS"; then
  echo "app-store entitlements template must include Sparkle shared preference access" >&2
  exit 1
fi

SUMMARY_PATH="$summary_path" python3 <<'PY'
import json
import os
import sys

with open(os.environ["SUMMARY_PATH"], encoding="utf-8") as handle:
    payload = json.load(handle)

if payload.get("profile") != "app-store":
    print("expected summary profile app-store", file=sys.stderr)
    sys.exit(1)
if payload.get("status") != "completed":
    print("expected completed status for app-store smoke run", file=sys.stderr)
    sys.exit(1)
artifact_types = {artifact.get("artifactType") for artifact in payload.get("artifacts", [])}
if "zip" not in artifact_types:
    print("expected zip artifact in summary", file=sys.stderr)
    sys.exit(1)
if "appcast" in artifact_types or "dmg" in artifact_types:
    print("app-store profile summary must not include appcast/dmg artifacts", file=sys.stderr)
    sys.exit(1)
PY

echo "app-store artifact exclusion smoke checks passed"
