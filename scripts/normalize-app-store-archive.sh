#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(CDPATH="" cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/release-profile.sh"

ARCHIVE_OR_APP_PATH="${1:-}"
if [ -z "$ARCHIVE_OR_APP_PATH" ]; then
  echo "Usage: scripts/normalize-app-store-archive.sh /path/to/Minute.xcarchive|Minute.app" >&2
  exit 1
fi

ARCHIVE_PATH=""
if [ -d "$ARCHIVE_OR_APP_PATH" ] && [[ "$ARCHIVE_OR_APP_PATH" == *.xcarchive ]]; then
  ARCHIVE_PATH="$ARCHIVE_OR_APP_PATH"
  APP_PATH="$ARCHIVE_OR_APP_PATH/Products/Applications/Minute.app"
else
  APP_PATH="$ARCHIVE_OR_APP_PATH"
fi

if [ ! -d "$APP_PATH" ]; then
  echo "error: app not found at $APP_PATH" >&2
  exit 1
fi

helper_entitlements_input="${MINUTE_HELPER_ENTITLEMENTS_FILE:-$(profile_default_helper_entitlements)}"
if [[ "$helper_entitlements_input" = /* ]]; then
  HELPER_ENTITLEMENTS_PATH="$helper_entitlements_input"
else
  HELPER_ENTITLEMENTS_PATH="$(release_profile_repo_root)/$helper_entitlements_input"
fi

if [ ! -f "$HELPER_ENTITLEMENTS_PATH" ]; then
  echo "error: helper entitlements file not found at $HELPER_ENTITLEMENTS_PATH" >&2
  exit 1
fi

codesign_details="$((/usr/bin/codesign -dv --verbose=4 "$APP_PATH" 2>&1) || true)"
SIGN_IDENTITY="$(printf "%s" "$codesign_details" | sed -n 's/^Authority=//p' | head -n 1)"
if [ -z "$SIGN_IDENTITY" ] && printf "%s" "$codesign_details" | grep -q "Signature=adhoc"; then
  SIGN_IDENTITY="-"
fi
if [ -z "$SIGN_IDENTITY" ]; then
  echo "error: unable to determine signing identity for $APP_PATH" >&2
  exit 1
fi

TEMP_DIR="$(mktemp -d)"
cleanup() {
  rm -rf "$TEMP_DIR"
}
trap cleanup EXIT

extract_entitlements_to_file() {
  local signed_path="$1"
  local output_file="$2"
  /usr/bin/codesign -d --entitlements :- "$signed_path" > "$output_file" 2>/dev/null && [ -s "$output_file" ]
}

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

for candidate in \
  "$APP_PATH/Contents/Resources/ffmpeg" \
  "$APP_PATH/Contents/Resources/llama-mtmd-cli"; do
  if [ -f "$candidate" ]; then
    sign_path "$candidate" "$HELPER_ENTITLEMENTS_PATH"
  fi
done

for lib in "$APP_PATH/Contents/Resources"/lib*.dylib; do
  if [ -f "$lib" ]; then
    sign_path "$lib"
  fi
done

if [ -d "$APP_PATH/Contents/XPCServices" ]; then
  find "$APP_PATH/Contents/XPCServices" -type d -name "*.xpc" -print0 | while IFS= read -r -d '' xpc; do
    sign_path "$xpc" "$HELPER_ENTITLEMENTS_PATH"
  done
fi

SPARKLE_FRAMEWORK="$APP_PATH/Contents/Frameworks/Sparkle.framework"
if [ -d "$SPARKLE_FRAMEWORK" ]; then
  find "$SPARKLE_FRAMEWORK/Versions" -type d -name "Updater.app" -print0 2>/dev/null | while IFS= read -r -d '' updater_app; do
    sign_path "$updater_app" "$HELPER_ENTITLEMENTS_PATH"
  done

  find "$SPARKLE_FRAMEWORK/Versions" -type d -path "*/XPCServices/*.xpc" -print0 2>/dev/null | while IFS= read -r -d '' xpc; do
    sign_path "$xpc" "$HELPER_ENTITLEMENTS_PATH"
  done

  find "$SPARKLE_FRAMEWORK/Versions" -type f -name "Autoupdate" -print0 2>/dev/null | while IFS= read -r -d '' autoupdate; do
    sign_path "$autoupdate" "$HELPER_ENTITLEMENTS_PATH"
  done
fi

app_entitlements="$TEMP_DIR/app-entitlements.plist"
if extract_entitlements_to_file "$APP_PATH" "$app_entitlements"; then
  /usr/bin/codesign --force --timestamp --options runtime --entitlements "$app_entitlements" --sign "$SIGN_IDENTITY" "$APP_PATH"
else
  /usr/bin/codesign --force --timestamp --options runtime --sign "$SIGN_IDENTITY" "$APP_PATH"
fi

/usr/bin/codesign --verify --deep --strict "$APP_PATH"

is_macho_binary() {
  local path="$1"
  /usr/bin/file -b "$path" 2>/dev/null | grep -q "Mach-O"
}

generate_dsym() {
  local binary_path="$1"
  local dsym_root="$2"
  local dsym_name_override="${3:-}"
  local binary_name dsym_name dsym_path dwarf_path

  if [ ! -f "$binary_path" ] || ! is_macho_binary "$binary_path"; then
    return 0
  fi

  binary_name="$(basename "$binary_path")"
  dsym_name="${dsym_name_override:-$binary_name.dSYM}"
  dsym_path="$dsym_root/$dsym_name"
  dwarf_path="$dsym_path/Contents/Resources/DWARF/$binary_name"

  rm -rf "$dsym_path"
  /usr/bin/dsymutil "$binary_path" -o "$dsym_path" >/dev/null 2>&1 || true

  if [ ! -f "$dwarf_path" ]; then
    rm -rf "$dsym_path"
  fi
}

if [ -n "$ARCHIVE_PATH" ]; then
  DSYM_DIR="$ARCHIVE_PATH/dSYMs"
  mkdir -p "$DSYM_DIR"

  for candidate in \
    "$APP_PATH/Contents/Resources/ffmpeg" \
    "$APP_PATH/Contents/Resources/llama-mtmd-cli"; do
    generate_dsym "$candidate" "$DSYM_DIR"
  done

  for lib in "$APP_PATH/Contents/Resources"/lib*.dylib; do
    generate_dsym "$lib" "$DSYM_DIR"
  done

  find "$APP_PATH" -type d -name "*.framework" -print0 | while IFS= read -r -d '' framework_dir; do
    framework_name="$(basename "$framework_dir")"
    framework_binary_name="${framework_name%.framework}"
    framework_binary_path="$framework_dir/Versions/Current/$framework_binary_name"
    if [ ! -f "$framework_binary_path" ]; then
      framework_binary_path="$framework_dir/$framework_binary_name"
    fi
    if [ -f "$framework_binary_path" ]; then
      generate_dsym "$framework_binary_path" "$DSYM_DIR" "$framework_name.dSYM"
    fi
  done
fi

echo "Normalized app-store archive at $APP_PATH"
