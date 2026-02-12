#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(CDPATH="" cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
RELEASE_SCRIPT="$ROOT_DIR/scripts/release-notarize.sh"

make_fake_app() {
  local app_path="$1"
  mkdir -p "$app_path/Contents/MacOS"
  cat > "$app_path/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleIdentifier</key>
  <string>com.minute.tests.direct</string>
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
  <string>YES</string>
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
summary_path="$output_dir/direct-summary.json"
make_fake_app "$app_path"

/usr/bin/codesign --force --deep --sign - "$app_path"

DIST_PROFILE="direct" \
ENABLE_NOTARIZATION=0 \
CREATE_DMG=0 \
CREATE_ZIP=1 \
GENERATE_APPCAST=0 \
OUTPUT_DIR="$output_dir" \
RELEASE_SUMMARY_PATH="$summary_path" \
"$RELEASE_SCRIPT" "$app_path"

zip_path="$output_dir/Minute-0.99.0.zip"
if [ ! -f "$zip_path" ]; then
  echo "expected direct profile ZIP artifact at $zip_path" >&2
  exit 1
fi

if [ ! -f "$summary_path" ]; then
  echo "expected release summary at $summary_path" >&2
  exit 1
fi

SUMMARY_PATH="$summary_path" python3 <<'PY'
import json
import os
import sys

with open(os.environ["SUMMARY_PATH"], encoding="utf-8") as handle:
    payload = json.load(handle)

if payload.get("profile") != "direct":
    print("expected summary profile direct", file=sys.stderr)
    sys.exit(1)
if payload.get("status") != "completed":
    print("expected completed status for direct smoke run", file=sys.stderr)
    sys.exit(1)
artifact_types = {artifact.get("artifactType") for artifact in payload.get("artifacts", [])}
if "zip" not in artifact_types:
    print("expected zip artifact in summary", file=sys.stderr)
    sys.exit(1)
if "appcast" in artifact_types or "dmg" in artifact_types:
    print("did not expect appcast or dmg artifacts in this smoke run", file=sys.stderr)
    sys.exit(1)
PY

echo "direct profile artifact smoke checks passed"
