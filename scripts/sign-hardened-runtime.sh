#!/bin/sh
set -euo pipefail

if [ "${CODE_SIGNING_ALLOWED:-NO}" != "YES" ]; then
  exit 0
fi

if [ -z "${EXPANDED_CODE_SIGN_IDENTITY:-}" ]; then
  exit 0
fi

if [ -z "${TARGET_BUILD_DIR:-}" ] || [ -z "${CONTENTS_FOLDER_PATH:-}" ]; then
  exit 0
fi

APP_DIR="$TARGET_BUILD_DIR/$CONTENTS_FOLDER_PATH"
if [ ! -d "$APP_DIR" ]; then
  exit 0
fi

SIGN_IDENTITY="$EXPANDED_CODE_SIGN_IDENTITY"
DIST_PROFILE="${MINUTE_DISTRIBUTION_PROFILE:-direct}"
MINUTE_HELPER_ENTITLEMENTS_FILE="${MINUTE_HELPER_ENTITLEMENTS_FILE:-Minute/Sources/App/MinuteHelper.entitlements}"

if [ "${MINUTE_HELPER_ENTITLEMENTS_FILE#/}" = "$MINUTE_HELPER_ENTITLEMENTS_FILE" ]; then
  HELPER_ENTITLEMENTS="$SRCROOT/$MINUTE_HELPER_ENTITLEMENTS_FILE"
else
  HELPER_ENTITLEMENTS="$MINUTE_HELPER_ENTITLEMENTS_FILE"
fi

PROFILE_IS_APP_STORE=0
if [ "$DIST_PROFILE" = "app-store" ]; then
  PROFILE_IS_APP_STORE=1
  if [ ! -f "$HELPER_ENTITLEMENTS" ]; then
    echo "error: helper entitlements file not found at $HELPER_ENTITLEMENTS" >&2
    exit 1
  fi
fi

TEMP_DIR="$(mktemp -d)"
cleanup() {
  rm -rf "$TEMP_DIR"
}
trap cleanup EXIT

sign_path() {
  local path="$1"
  local fallback_entitlements="${2:-}"
  local existing_entitlements

  if [ ! -e "$path" ]; then
    return 0
  fi

  existing_entitlements="$(mktemp "$TEMP_DIR/entitlements.XXXXXX")"
  if /usr/bin/codesign -d --entitlements :- "$path" > "$existing_entitlements" 2>/dev/null && [ -s "$existing_entitlements" ] && grep -q "<key>" "$existing_entitlements"; then
    /usr/bin/codesign --force --timestamp --options runtime --entitlements "$existing_entitlements" --sign "$SIGN_IDENTITY" "$path"
    return 0
  fi

  if [ -n "$fallback_entitlements" ] && [ -f "$fallback_entitlements" ]; then
    /usr/bin/codesign --force --timestamp --options runtime --entitlements "$fallback_entitlements" --sign "$SIGN_IDENTITY" "$path"
    return 0
  fi

  /usr/bin/codesign --force --timestamp --options runtime --sign "$SIGN_IDENTITY" "$path"
}

HELPER_FALLBACK=""
if [ "$PROFILE_IS_APP_STORE" -eq 1 ]; then
  HELPER_FALLBACK="$HELPER_ENTITLEMENTS"
fi

for name in ffmpeg ffmpg llama-mtmd-cli whisper; do
  candidate="$APP_DIR/Contents/Resources/$name"
  if [ -f "$candidate" ]; then
    sign_path "$candidate" "$HELPER_FALLBACK"
  fi
done

for lib in "$APP_DIR/Contents/Resources"/lib*.dylib; do
  if [ -f "$lib" ]; then
    sign_path "$lib"
  fi
done

if [ -d "$APP_DIR/Contents/XPCServices" ]; then
  find "$APP_DIR/Contents/XPCServices" -type d -name "*.xpc" -print0 | while IFS= read -r -d '' xpc; do
    sign_path "$xpc" "$HELPER_FALLBACK"
  done
fi

SPARKLE_FRAMEWORK="$APP_DIR/Contents/Frameworks/Sparkle.framework"
if [ -d "$SPARKLE_FRAMEWORK" ]; then
  find "$SPARKLE_FRAMEWORK/Versions" -type d -name "Updater.app" -print0 2>/dev/null | while IFS= read -r -d '' updater_app; do
    sign_path "$updater_app" "$HELPER_FALLBACK"
  done

  find "$SPARKLE_FRAMEWORK/Versions" -type d -path "*/XPCServices/*.xpc" -print0 2>/dev/null | while IFS= read -r -d '' xpc; do
    sign_path "$xpc" "$HELPER_FALLBACK"
  done

  find "$SPARKLE_FRAMEWORK/Versions" -type f -name "Autoupdate" -print0 2>/dev/null | while IFS= read -r -d '' autoupdate; do
    sign_path "$autoupdate" "$HELPER_FALLBACK"
  done

  sign_path "$SPARKLE_FRAMEWORK"
fi

VENDOR_DIR="$SRCROOT/MinuteCore/Vendor"
if [ -d "$VENDOR_DIR" ]; then
  framework_names=$(find "$VENDOR_DIR" -type d -path "*macos*/*.framework" -print 2>/dev/null | awk -F/ '{print $NF}' | sort -u)
  if [ -n "$framework_names" ]; then
    for framework in $framework_names; do
      find "$APP_DIR" -type d -name "$framework" -print0 | while IFS= read -r -d '' framework_path; do
        sign_path "$framework_path"
      done
    done
  fi
fi

if [ -n "${DERIVED_FILE_DIR:-}" ]; then
  touch "$DERIVED_FILE_DIR/sign-bundled-binaries.stamp"
fi
