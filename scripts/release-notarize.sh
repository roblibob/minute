#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(CDPATH="" cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/release-profile.sh"

ARCHIVE_PATH="${1:-}"
DIST_PROFILE="${DIST_PROFILE:-}"
NOTARY_PROFILE="${NOTARY_PROFILE:-minute-notary}"
OUTPUT_DIR="${OUTPUT_DIR:-updates}"
CREATE_DMG="${CREATE_DMG:-}"
CREATE_ZIP="${CREATE_ZIP:-1}"
GENERATE_APPCAST="${GENERATE_APPCAST:-}"
APPCAST_DOWNLOAD_URL_PREFIX="${APPCAST_DOWNLOAD_URL_PREFIX:-}"
APPCAST_DEST="${APPCAST_DEST:-$OUTPUT_DIR/appcast.xml}"
RELEASE_SUMMARY_PATH="${RELEASE_SUMMARY_PATH:-}"
ENABLE_NOTARIZATION="${ENABLE_NOTARIZATION:-}"

if [ -z "$ARCHIVE_PATH" ]; then
  cat <<EOF_USAGE
Usage: scripts/release-notarize.sh /path/to/Minute.xcarchive|Minute.app

Environment overrides:
  DIST_PROFILE=app-store|direct
  NOTARY_PROFILE=minute-notary
  OUTPUT_DIR=updates
  CREATE_DMG=1 (default direct=1, app-store=0)
  CREATE_ZIP=1
  GENERATE_APPCAST=1 (default direct=1, app-store=0)
  ENABLE_NOTARIZATION=1 (default direct=1, app-store=0)
  APPCAST_DOWNLOAD_URL_PREFIX=
  APPCAST_DEST=$OUTPUT_DIR/appcast.xml
  RELEASE_SUMMARY_PATH=$OUTPUT_DIR/release-validation-summary.json
  SPARKLE_APPCAST_ARGS=
EOF_USAGE
  exit 1
fi

require_dist_profile "$DIST_PROFILE"

if [ -z "$CREATE_DMG" ]; then
  if profile_is_app_store "$DIST_PROFILE"; then
    CREATE_DMG=0
  else
    CREATE_DMG=1
  fi
fi

if [ -z "$GENERATE_APPCAST" ]; then
  if profile_is_app_store "$DIST_PROFILE"; then
    GENERATE_APPCAST=0
  else
    GENERATE_APPCAST=1
  fi
fi

if [ -z "$ENABLE_NOTARIZATION" ]; then
  if profile_is_app_store "$DIST_PROFILE"; then
    ENABLE_NOTARIZATION=0
  else
    ENABLE_NOTARIZATION=1
  fi
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

resolve_path_from_repo() {
  local path="$1"
  if [[ "$path" = /* ]]; then
    echo "$path"
    return
  fi
  echo "$(release_profile_repo_root)/$path"
}

helper_entitlements_input="${MINUTE_HELPER_ENTITLEMENTS_FILE:-$(profile_default_helper_entitlements)}"
HELPER_ENTITLEMENTS_PATH="$(resolve_path_from_repo "$helper_entitlements_input")"

mkdir -p "$OUTPUT_DIR"

RUN_ID="$(date -u +%Y%m%dT%H%M%SZ)-$$"
SUMMARY_PATH="${RELEASE_SUMMARY_PATH:-$(summary_default_path "$OUTPUT_DIR")}" 
summary_init "$SUMMARY_PATH" "$DIST_PROFILE" "$RUN_ID"
summary_add_artifact "$SUMMARY_PATH" "archive" "$APP_PATH" "$DIST_PROFILE"
summary_set_status "$SUMMARY_PATH" "preflight_running"

TEMP_DIR="$(mktemp -d)"
cleanup() {
  rm -rf "$TEMP_DIR"
}
trap cleanup EXIT

fail_preflight() {
  local check_type="$1"
  local target="$2"
  local message="$3"
  local details="${4:-}"
  summary_add_check "$SUMMARY_PATH" "$check_type" "$target" "failed" "$message" "$details"
  summary_set_status "$SUMMARY_PATH" "preflight_failed"
  echo "error: $message" >&2
  if [ -n "$details" ]; then
    echo "$details" >&2
  fi
  exit 1
}

pass_check() {
  local check_type="$1"
  local target="$2"
  local message="$3"
  summary_add_check "$SUMMARY_PATH" "$check_type" "$target" "passed" "$message"
}

skip_check() {
  local check_type="$1"
  local target="$2"
  local message="$3"
  summary_add_check "$SUMMARY_PATH" "$check_type" "$target" "skipped" "$message"
}

plist_bool_is_true() {
  local plist_file="$1"
  local key="$2"
  local raw
  raw="$(/usr/libexec/PlistBuddy -c "Print :$key" "$plist_file" 2>/dev/null || true)"
  raw="$(echo "$raw" | tr '[:upper:]' '[:lower:]' | tr -d '[:space:]')"
  [[ "$raw" == "yes" || "$raw" == "true" || "$raw" == "1" ]]
}

extract_entitlements_to_file() {
  local signed_path="$1"
  local output_file="$2"
  /usr/bin/codesign -d --entitlements :- "$signed_path" > "$output_file" 2>/dev/null && [ -s "$output_file" ]
}

check_profile_config() {
  pass_check "profile-config" "$DIST_PROFILE" "distribution profile is valid"
}

check_signature_preflight() {
  if ! /usr/bin/codesign --verify --deep --strict "$APP_PATH" >/dev/null 2>&1; then
    fail_preflight "signature" "$APP_PATH" "signature preflight failed for $APP_PATH"
  fi
  pass_check "signature" "$APP_PATH" "signature preflight passed"
}

check_sandbox_preflight() {
  if ! profile_is_app_store "$DIST_PROFILE"; then
    skip_check "sandbox-policy" "$APP_PATH" "sandbox preflight not required for direct profile"
    return
  fi

  if [ ! -f "$HELPER_ENTITLEMENTS_PATH" ]; then
    fail_preflight "sandbox-policy" "$APP_PATH" "sandbox preflight failed: helper entitlements file not found at $HELPER_ENTITLEMENTS_PATH"
  fi

  local entitlements_file="$TEMP_DIR/app-entitlements.plist"
  if ! extract_entitlements_to_file "$APP_PATH" "$entitlements_file"; then
    fail_preflight "sandbox-policy" "$APP_PATH" "sandbox preflight failed: entitlements could not be read"
  fi

  if ! plist_bool_is_true "$entitlements_file" "com.apple.security.app-sandbox"; then
    fail_preflight "sandbox-policy" "$APP_PATH" "sandbox preflight failed: app sandbox entitlement is missing or disabled"
  fi

  if plist_bool_is_true "$entitlements_file" "com.apple.security.device.screen-recording"; then
    fail_preflight "sandbox-policy" "$APP_PATH" "sandbox preflight failed: app-store profile cannot include screen recording entitlement"
  fi

  validate_nested_executable_sandbox() {
    local executable_path="$1"
    local nested_entitlements="$TEMP_DIR/nested-entitlements-$(basename "$executable_path").plist"

    if ! extract_entitlements_to_file "$executable_path" "$nested_entitlements"; then
      fail_preflight "sandbox-policy" "$executable_path" "sandbox preflight failed: missing readable entitlements on nested executable"
    fi

    if ! plist_bool_is_true "$nested_entitlements" "com.apple.security.app-sandbox"; then
      fail_preflight "sandbox-policy" "$executable_path" "sandbox preflight failed: nested executable missing app sandbox entitlement"
    fi
  }

  for candidate in \
    "$APP_PATH/Contents/Resources/ffmpeg" \
    "$APP_PATH/Contents/Resources/llama-mtmd-cli"; do
    if [ -f "$candidate" ]; then
      validate_nested_executable_sandbox "$candidate"
    fi
  done

  if [ -d "$APP_PATH/Contents/XPCServices" ]; then
    find "$APP_PATH/Contents/XPCServices" -type f -path "*/Contents/MacOS/*" -perm -111 -print0 | while IFS= read -r -d '' executable; do
      validate_nested_executable_sandbox "$executable"
    done
  fi

  local sparkle_framework="$APP_PATH/Contents/Frameworks/Sparkle.framework"
  if [ -d "$sparkle_framework" ]; then
    find "$sparkle_framework/Versions" -type f -name "Autoupdate" -print0 2>/dev/null | while IFS= read -r -d '' executable; do
      validate_nested_executable_sandbox "$executable"
    done
    find "$sparkle_framework/Versions" -type f -path "*/Contents/MacOS/*" -perm -111 -print0 2>/dev/null | while IFS= read -r -d '' executable; do
      validate_nested_executable_sandbox "$executable"
    done
  fi

  pass_check "sandbox-policy" "$APP_PATH" "sandbox entitlement preflight passed"
}

check_updater_policy_preflight() {
  local info_plist="$APP_PATH/Contents/Info.plist"

  if ! profile_is_app_store "$DIST_PROFILE"; then
    pass_check "updater-policy" "$APP_PATH" "updater policy check passed for direct profile"
    return
  fi

  local raw
  raw="$(/usr/libexec/PlistBuddy -c "Print :MINUTEEnableUpdater" "$info_plist" 2>/dev/null || true)"
  raw="$(echo "$raw" | tr '[:upper:]' '[:lower:]' | tr -d '[:space:]')"

  if [ "$raw" = "yes" ] || [ "$raw" = "true" ] || [ "$raw" = "1" ]; then
    fail_preflight "updater-policy" "$APP_PATH" "updater policy preflight failed: app-store profile must disable self-update behavior"
  fi

  pass_check "updater-policy" "$APP_PATH" "updater policy preflight passed"
}

check_artifact_policy_preflight() {
  if ! profile_is_app_store "$DIST_PROFILE"; then
    pass_check "artifact-policy" "$OUTPUT_DIR" "artifact policy check passed for direct profile"
    return
  fi

  if [ "$CREATE_DMG" != "0" ]; then
    fail_preflight "artifact-policy" "$OUTPUT_DIR" "artifact policy preflight failed: app-store profile cannot create DMG artifacts"
  fi

  if [ "$GENERATE_APPCAST" != "0" ]; then
    fail_preflight "artifact-policy" "$OUTPUT_DIR" "artifact policy preflight failed: app-store profile cannot generate appcast"
  fi

  pass_check "artifact-policy" "$OUTPUT_DIR" "artifact policy preflight passed"
}

check_profile_config
check_signature_preflight
check_sandbox_preflight
check_updater_policy_preflight
check_artifact_policy_preflight
summary_set_status "$SUMMARY_PATH" "preflight_passed"

codesign_details="$((/usr/bin/codesign -dv --verbose=4 "$APP_PATH" 2>&1) || true)"
SIGN_IDENTITY="$(printf "%s" "$codesign_details" | sed -n 's/^Authority=//p' | head -n 1)"
if [ -z "$SIGN_IDENTITY" ] && printf "%s" "$codesign_details" | grep -q "Signature=adhoc"; then
  SIGN_IDENTITY="-"
fi
if [ -z "$SIGN_IDENTITY" ]; then
  fail_preflight "signature" "$APP_PATH" "unable to determine signing identity for $APP_PATH"
fi

sign_path() {
  local path="$1"
  local fallback_entitlements="${2:-}"
  local extracted_entitlements

  if [ ! -e "$path" ]; then
    return 0
  fi

  extracted_entitlements="$TEMP_DIR/sign-entitlements-$(basename "$path").plist"
  if extract_entitlements_to_file "$path" "$extracted_entitlements" && grep -q "<key>" "$extracted_entitlements"; then
    /usr/bin/codesign --force --timestamp --options runtime --entitlements "$extracted_entitlements" --sign "$SIGN_IDENTITY" "$path"
    return 0
  fi

  if [ -n "$fallback_entitlements" ] && [ -f "$fallback_entitlements" ]; then
    /usr/bin/codesign --force --timestamp --options runtime --entitlements "$fallback_entitlements" --sign "$SIGN_IDENTITY" "$path"
    return 0
  fi

  /usr/bin/codesign --force --timestamp --options runtime --sign "$SIGN_IDENTITY" "$path"
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

sign_app_helpers() {
  local helper_fallback=""
  if profile_is_app_store "$DIST_PROFILE"; then
    helper_fallback="$HELPER_ENTITLEMENTS_PATH"
  fi

  for candidate in \
    "$APP_PATH/Contents/Resources/ffmpeg" \
    "$APP_PATH/Contents/Resources/llama-mtmd-cli"; do
    if [ -f "$candidate" ]; then
      sign_path "$candidate" "$helper_fallback"
    fi
  done

  for lib in "$APP_PATH/Contents/Resources"/lib*.dylib; do
    if [ -f "$lib" ]; then
      sign_path "$lib"
    fi
  done

  local xpc_dir="$APP_PATH/Contents/XPCServices"
  if [ -d "$xpc_dir" ]; then
    find "$xpc_dir" -type d -name "*.xpc" -print0 | while IFS= read -r -d '' xpc; do
      sign_path "$xpc" "$helper_fallback"
    done
  fi
}

sign_sparkle_helpers() {
  local sparkle_framework="$APP_PATH/Contents/Frameworks/Sparkle.framework"
  if [ ! -d "$sparkle_framework" ]; then
    return 0
  fi
  local helper_fallback=""
  if profile_is_app_store "$DIST_PROFILE"; then
    helper_fallback="$HELPER_ENTITLEMENTS_PATH"
  fi

  find "$sparkle_framework/Versions" -type d -name "Updater.app" -print0 2>/dev/null | while IFS= read -r -d '' updater_app; do
    sign_path "$updater_app" "$helper_fallback"
  done

  find "$sparkle_framework/Versions" -type d -path "*/XPCServices/*.xpc" -print0 2>/dev/null | while IFS= read -r -d '' xpc; do
    sign_path "$xpc" "$helper_fallback"
  done

  find "$sparkle_framework/Versions" -type f -name "Autoupdate" -print0 2>/dev/null | while IFS= read -r -d '' autoupdate; do
    sign_path "$autoupdate" "$helper_fallback"
  done
}

INFO_PLIST="$APP_PATH/Contents/Info.plist"
VERSION="$((/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$INFO_PLIST" 2>/dev/null) || true)"
if [ -z "$VERSION" ]; then
  VERSION="0.1a"
fi
FILE_VERSION="${VERSION// /-}"
ZIP_PATH="$OUTPUT_DIR/Minute-$FILE_VERSION.zip"
DMG_PATH="$OUTPUT_DIR/Minute-$FILE_VERSION.dmg"

summary_set_status "$SUMMARY_PATH" "packaging"

sign_sparkle_helpers
sign_app_helpers
sign_app_bundle

TEMP_ZIP="$TEMP_DIR/Minute-notary.zip"
ditto -c -k --keepParent "$APP_PATH" "$TEMP_ZIP"

submit_and_wait() {
  local file="$1"
  local label="$2"

  echo "Submitting $label for notarization via $file"
  local stdout_file stderr_file
  stdout_file="$(mktemp)"
  stderr_file="$(mktemp)"

  if ! xcrun notarytool submit "$file" --keychain-profile "$NOTARY_PROFILE" --wait --output-format json --no-progress \
    >"$stdout_file" 2>"$stderr_file"; then
    echo "Notarization command failed for $label." >&2
    cat "$stderr_file" >&2 || true
    rm -f "$stdout_file" "$stderr_file"
    summary_set_status "$SUMMARY_PATH" "failed"
    exit 1
  fi

  local parse_result parse_rc status id
  set +e
  parse_result="$(/usr/bin/python3 -c 'import json,sys; data=json.load(open(sys.argv[1])); print(data.get("status","")); print(data.get("id",""))' "$stdout_file")"
  parse_rc=$?
  set -e

  if [ "$parse_rc" -ne 0 ]; then
    echo "Notarization JSON parse failed for $label (rc=$parse_rc)." >&2
    cat "$stderr_file" >&2 || true
    rm -f "$stdout_file" "$stderr_file"
    summary_set_status "$SUMMARY_PATH" "failed"
    exit 1
  fi

  status="$(printf "%s" "$parse_result" | sed -n '1p')"
  id="$(printf "%s" "$parse_result" | sed -n '2p')"

  rm -f "$stdout_file" "$stderr_file"

  if [ "$status" != "Accepted" ]; then
    echo "Notarization failed for $label (status: $status, id: $id)" >&2
    if [ -n "$id" ]; then
      xcrun notarytool log "$id" --keychain-profile "$NOTARY_PROFILE" >&2 || true
    fi
    summary_set_status "$SUMMARY_PATH" "failed"
    exit 1
  fi
}

if profile_is_direct "$DIST_PROFILE" && [ "$ENABLE_NOTARIZATION" = "1" ]; then
  submit_and_wait "$TEMP_ZIP" "app"

  echo "Stapling app"
  xcrun stapler staple "$APP_PATH"
elif profile_is_direct "$DIST_PROFILE"; then
  echo "Skipping notarization for direct profile (ENABLE_NOTARIZATION=$ENABLE_NOTARIZATION)"
fi

if [ "$CREATE_DMG" = "1" ]; then
  echo "Building DMG"
  "$SCRIPT_DIR/build-release-dmg.sh" "$APP_PATH"

  if [ ! -f "$DMG_PATH" ]; then
    echo "DMG not found at: $DMG_PATH" >&2
    summary_set_status "$SUMMARY_PATH" "failed"
    exit 1
  fi

  if profile_is_direct "$DIST_PROFILE" && [ "$ENABLE_NOTARIZATION" = "1" ]; then
    submit_and_wait "$DMG_PATH" "DMG"

    echo "Stapling DMG"
    xcrun stapler staple "$DMG_PATH"
  elif profile_is_direct "$DIST_PROFILE"; then
    echo "Skipping DMG notarization for direct profile (ENABLE_NOTARIZATION=$ENABLE_NOTARIZATION)"
  fi

  summary_add_artifact "$SUMMARY_PATH" "dmg" "$DMG_PATH" "$DIST_PROFILE"
fi

if [ "$CREATE_ZIP" = "1" ]; then
  echo "Creating release ZIP"
  rm -f "$ZIP_PATH"
  ditto -c -k --keepParent "$APP_PATH" "$ZIP_PATH"
  summary_add_artifact "$SUMMARY_PATH" "zip" "$ZIP_PATH" "$DIST_PROFILE"
fi

if [ "$GENERATE_APPCAST" = "1" ]; then
  echo "Generating Sparkle appcast"
  if [ ! -f "$ZIP_PATH" ]; then
    echo "error: appcast generation requires ZIP at $ZIP_PATH" >&2
    summary_set_status "$SUMMARY_PATH" "failed"
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

  "$SCRIPT_DIR/generate-appcast.sh" "$APPCAST_TEMP_DIR" "$APPCAST_DOWNLOAD_URL_PREFIX"

  if [ -n "$APPCAST_DEST" ]; then
    mkdir -p "$(dirname "$APPCAST_DEST")"
    cp "$APPCAST_TEMP_DIR/appcast.xml" "$APPCAST_DEST"
    echo "Copied appcast to $APPCAST_DEST"
  fi

  summary_add_artifact "$SUMMARY_PATH" "appcast" "$APPCAST_DEST" "$DIST_PROFILE"
fi

summary_set_status "$SUMMARY_PATH" "completed"

echo "Release profile: $DIST_PROFILE"
echo "Release artifacts:"
if [ -f "$ZIP_PATH" ]; then
  echo "  ZIP: $ZIP_PATH"
fi
if [ -f "$DMG_PATH" ]; then
  echo "  DMG: $DMG_PATH"
fi
if [ -f "$APPCAST_DEST" ] && [ "$GENERATE_APPCAST" = "1" ]; then
  echo "  Appcast: $APPCAST_DEST"
fi
echo "Validation summary: $SUMMARY_PATH"
