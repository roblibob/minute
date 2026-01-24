#!/usr/bin/env bash
set -euo pipefail

ARCHIVE_PATH="${1:-}"
NOTARY_PROFILE="${NOTARY_PROFILE:-minute-notary}"
OUTPUT_DIR="${OUTPUT_DIR:-updates}"
CREATE_DMG="${CREATE_DMG:-1}"
CREATE_ZIP="${CREATE_ZIP:-1}"
GENERATE_APPCAST="${GENERATE_APPCAST:-1}"
APPCAST_DOWNLOAD_URL_PREFIX="${APPCAST_DOWNLOAD_URL_PREFIX:-}"
APPCAST_DEST="${APPCAST_DEST:-appcast.xml}"

if [ -z "$ARCHIVE_PATH" ]; then
  cat <<EOF
Usage: scripts/release-notarize.sh /path/to/Minute.xcarchive|Minute.app

Environment overrides:
  NOTARY_PROFILE=minute-notary
  OUTPUT_DIR=updates
  CREATE_DMG=1
  CREATE_ZIP=1
  GENERATE_APPCAST=1
  APPCAST_DOWNLOAD_URL_PREFIX=
  APPCAST_DEST=appcast.xml
  SPARKLE_APPCAST_ARGS=
EOF
  exit 1
fi

if [ -d "$ARCHIVE_PATH" ] && [[ "$ARCHIVE_PATH" == *.xcarchive ]]; then
  APP_PATH="$ARCHIVE_PATH/Products/Applications/Minute.app"
else
APP_PATH="$ARCHIVE_PATH"
fi

if [ ! -d "$APP_PATH" ]; then
  echo "Release app not found at: $APP_PATH" >&2
  exit 1
fi

SIGN_IDENTITY="$(
  /usr/bin/codesign -dv --verbose=4 "$APP_PATH" 2>&1 | sed -n 's/^Authority=//p' | head -n 1
)"
if [ -z "$SIGN_IDENTITY" ]; then
  echo "error: unable to determine signing identity for $APP_PATH" >&2
  exit 1
fi

sign_path() {
  local path="$1"
  if [ -e "$path" ]; then
    /usr/bin/codesign --force --timestamp --options runtime --sign "$SIGN_IDENTITY" "$path"
  fi
}

sign_app_bundle() {
  local entitlements_file="$TEMP_DIR/app-entitlements.plist"
  /usr/bin/codesign -d --entitlements :- "$APP_PATH" > "$entitlements_file" 2>/dev/null || true
  if [ -s "$entitlements_file" ]; then
    /usr/bin/codesign --force --timestamp --options runtime --entitlements "$entitlements_file" --sign "$SIGN_IDENTITY" "$APP_PATH"
  else
    /usr/bin/codesign --force --timestamp --options runtime --sign "$SIGN_IDENTITY" "$APP_PATH"
  fi
}

sign_sparkle_helpers() {
  local sparkle_framework="$APP_PATH/Contents/Frameworks/Sparkle.framework"
  if [ ! -d "$sparkle_framework" ]; then
    return 0
  fi

  find "$sparkle_framework/Versions" -type d -name "Updater.app" -print0 2>/dev/null | while IFS= read -r -d '' updater_app; do
    sign_path "$updater_app"
  done

  find "$sparkle_framework/Versions" -type d -path "*/XPCServices/*.xpc" -print0 2>/dev/null | while IFS= read -r -d '' xpc; do
    sign_path "$xpc"
  done

  find "$sparkle_framework/Versions" -type f -name "Autoupdate" -print0 2>/dev/null | while IFS= read -r -d '' autoupdate; do
    sign_path "$autoupdate"
  done

  sign_path "$sparkle_framework"
}

INFO_PLIST="$APP_PATH/Contents/Info.plist"
VERSION="$(
  /usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$INFO_PLIST" 2>/dev/null || true
)"
if [ -z "$VERSION" ]; then
  VERSION="0.1a"
fi
FILE_VERSION="${VERSION// /-}"
ZIP_PATH="$OUTPUT_DIR/Minute-$FILE_VERSION.zip"
DMG_PATH="$OUTPUT_DIR/Minute-$FILE_VERSION.dmg"

mkdir -p "$OUTPUT_DIR"

TEMP_DIR="$(mktemp -d)"
cleanup() {
  rm -rf "$TEMP_DIR"
}
trap cleanup EXIT

sign_sparkle_helpers
sign_app_bundle

TEMP_ZIP="$TEMP_DIR/Minute-notary.zip"
ditto -c -k --keepParent "$APP_PATH" "$TEMP_ZIP"

submit_and_wait() {
  local file="$1"
  local label="$2"
  local output status id

  echo "Submitting $label for notarization via $file"
  local stdout_file stderr_file
  stdout_file="$(mktemp)"
  stderr_file="$(mktemp)"

  if ! xcrun notarytool submit "$file" --keychain-profile "$NOTARY_PROFILE" --wait --output-format json --no-progress \
    >"$stdout_file" 2>"$stderr_file"; then
    echo "Notarization command failed for $label." >&2
    cat "$stderr_file" >&2 || true
    rm -f "$stdout_file" "$stderr_file"
    return 1
  fi

  output="$(cat "$stdout_file")"
  if [ -z "$output" ]; then
    echo "Notarization command produced no JSON output for $label." >&2
    cat "$stderr_file" >&2 || true
    rm -f "$stdout_file" "$stderr_file"
    return 1
  fi

  set +e
  parse_result="$(/usr/bin/python3 -c 'import json,sys; data=json.load(open(sys.argv[1])); print(data.get("status","")); print(data.get("id",""))' "$stdout_file")"
  parse_rc=$?
  set -e
  if [ "$parse_rc" -ne 0 ]; then
    echo "Notarization JSON parse failed for $label (rc=$parse_rc)." >&2
    echo "Raw output:" >&2
    printf "%s\n" "$output" >&2
    cat "$stderr_file" >&2 || true
    rm -f "$stdout_file" "$stderr_file"
    return 1
  fi

  status="$(printf "%s" "$parse_result" | sed -n '1p')"
  id="$(printf "%s" "$parse_result" | sed -n '2p')"

  if [ -z "$status" ]; then
    echo "Notarization JSON parse returned empty status for $label." >&2
    echo "Raw output:" >&2
    printf "%s\n" "$output" >&2
    cat "$stderr_file" >&2 || true
    rm -f "$stdout_file" "$stderr_file"
    return 1
  fi

  rm -f "$stdout_file" "$stderr_file"

  if [ "$status" != "Accepted" ]; then
    echo "Notarization failed for $label (status: $status, id: $id)" >&2
    if [ -n "$id" ]; then
      echo "Fetching notary log..." >&2
      xcrun notarytool log "$id" --keychain-profile "$NOTARY_PROFILE" >&2 || true
    fi
    return 1
  fi
}

submit_and_wait "$TEMP_ZIP" "app"

echo "Stapling app"
xcrun stapler staple "$APP_PATH"

if [ "$CREATE_DMG" = "1" ]; then
  echo "Building DMG"
  scripts/build-release-dmg.sh "$APP_PATH"

  if [ ! -f "$DMG_PATH" ]; then
    echo "DMG not found at: $DMG_PATH" >&2
    exit 1
  fi

  submit_and_wait "$DMG_PATH" "DMG"

  echo "Stapling DMG"
  xcrun stapler staple "$DMG_PATH"
fi

if [ "$CREATE_ZIP" = "1" ]; then
  echo "Creating release ZIP"
  rm -f "$ZIP_PATH"
  ditto -c -k --keepParent "$APP_PATH" "$ZIP_PATH"
fi

if [ "$GENERATE_APPCAST" = "1" ]; then
  echo "Generating Sparkle appcast"
  if [ ! -f "$ZIP_PATH" ]; then
    echo "error: appcast generation requires ZIP at $ZIP_PATH" >&2
    exit 1
  fi

  APPCAST_TEMP_DIR="$TEMP_DIR/appcast"
  mkdir -p "$APPCAST_TEMP_DIR"

  if [ -f "$APPCAST_DEST" ]; then
    cp "$APPCAST_DEST" "$APPCAST_TEMP_DIR/appcast.xml"
  elif [ -f "$OUTPUT_DIR/appcast.xml" ]; then
    cp "$OUTPUT_DIR/appcast.xml" "$APPCAST_TEMP_DIR/appcast.xml"
  fi

  cp "$ZIP_PATH" "$APPCAST_TEMP_DIR/$(basename "$ZIP_PATH")"

  scripts/generate-appcast.sh "$APPCAST_TEMP_DIR" "$APPCAST_DOWNLOAD_URL_PREFIX"

  if [ -n "$APPCAST_DEST" ]; then
    mkdir -p "$(dirname "$APPCAST_DEST")"
    cp "$APPCAST_TEMP_DIR/appcast.xml" "$APPCAST_DEST"
    echo "Copied appcast to $APPCAST_DEST"
  fi
fi

echo "Release artifacts:"
if [ -f "$ZIP_PATH" ]; then
  echo "  ZIP: $ZIP_PATH"
fi
if [ -f "$DMG_PATH" ]; then
  echo "  DMG: $DMG_PATH"
fi
