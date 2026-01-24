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

sign_path() {
  path="$1"
  if [ -e "$path" ]; then
    /usr/bin/codesign --force --timestamp --options runtime --sign "$SIGN_IDENTITY" "$path"
  fi
}

for name in ffmpeg ffmpg llama-mtmd-cli whisper; do
  candidate="$APP_DIR/Contents/Resources/$name"
  if [ -f "$candidate" ]; then
    sign_path "$candidate"
  fi
done

for lib in "$APP_DIR/Contents/Resources"/lib*.dylib; do
  if [ -f "$lib" ]; then
    sign_path "$lib"
  fi
done

if [ -d "$APP_DIR/Contents/XPCServices" ]; then
  find "$APP_DIR/Contents/XPCServices" -type d -name "*.xpc" -print0 | while IFS= read -r -d '' xpc; do
    sign_path "$xpc"
  done
fi

SPARKLE_FRAMEWORK="$APP_DIR/Contents/Frameworks/Sparkle.framework"
if [ -d "$SPARKLE_FRAMEWORK" ]; then
  find "$SPARKLE_FRAMEWORK/Versions" -type d -name "Updater.app" -print0 2>/dev/null | while IFS= read -r -d '' updater_app; do
    sign_path "$updater_app"
  done

  find "$SPARKLE_FRAMEWORK/Versions" -type d -path "*/XPCServices/*.xpc" -print0 2>/dev/null | while IFS= read -r -d '' xpc; do
    sign_path "$xpc"
  done

  find "$SPARKLE_FRAMEWORK/Versions" -type f -name "Autoupdate" -print0 2>/dev/null | while IFS= read -r -d '' autoupdate; do
    sign_path "$autoupdate"
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
