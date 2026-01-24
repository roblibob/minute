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

TEMP_ZIP="$TEMP_DIR/Minute-notary.zip"
ditto -c -k --keepParent "$APP_PATH" "$TEMP_ZIP"

submit_and_wait() {
  local file="$1"
  local label="$2"
  local output status id

  echo "Submitting $label for notarization via $file"
  output="$(xcrun notarytool submit "$file" --keychain-profile "$NOTARY_PROFILE" --wait --output-format json)"
  status="$(printf "%s" "$output" | python - <<'PY'
import json, sys
data = json.load(sys.stdin)
print(data.get("status", ""))
PY
)"
  id="$(printf "%s" "$output" | python - <<'PY'
import json, sys
data = json.load(sys.stdin)
print(data.get("id", ""))
PY
)"

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
  scripts/generate-appcast.sh "$OUTPUT_DIR" "$APPCAST_DOWNLOAD_URL_PREFIX"

  if [ -n "$APPCAST_DEST" ]; then
    mkdir -p "$(dirname "$APPCAST_DEST")"
    cp "$OUTPUT_DIR/appcast.xml" "$APPCAST_DEST"
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
