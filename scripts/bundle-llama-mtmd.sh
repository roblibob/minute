#!/bin/sh
set -e

DEFAULT_SOURCE="$SRCROOT/../llama-b7489/llama-mtmd-cli"
SOURCE="${LLAMA_MTMD_SOURCE:-$DEFAULT_SOURCE}"
SOURCE_DIR="$(cd "$(dirname "$SOURCE")" && pwd)"
DEST_DIR="$TARGET_BUILD_DIR/$CONTENTS_FOLDER_PATH/Resources"
DESTINATION="$DEST_DIR/llama-mtmd-cli"

if [ ! -f "$SOURCE" ]; then
  echo "error: llama-mtmd-cli not found at $SOURCE"
  echo "       Set LLAMA_MTMD_SOURCE to override the path."
  exit 1
fi

mkdir -p "$DEST_DIR"
cp "$SOURCE" "$DESTINATION"
chmod +x "$DESTINATION"

found_libs=0
for lib in "$SOURCE_DIR"/lib*.0.dylib; do
  if [ -f "$lib" ]; then
    found_libs=1
    dest_lib="$DEST_DIR/$(basename "$lib")"
    cp -L "$lib" "$dest_lib"
    if [ ! -r "$dest_lib" ]; then
      echo "error: copied library $dest_lib is not readable"
      exit 1
    fi
    if ! file "$dest_lib" 2>/dev/null | grep -q "dynamically linked shared library"; then
      echo "error: copied file $dest_lib is not a valid dynamic library"
      exit 1
    fi
    chmod 755 "$dest_lib"
  fi
done

if [ "$found_libs" -eq 0 ]; then
  echo "error: no lib*.0.dylib files found next to llama-mtmd-cli in $SOURCE_DIR"
  exit 1
fi

if [ -f "$SOURCE_DIR/ggml-metal.metal" ]; then
  cp "$SOURCE_DIR/ggml-metal.metal" "$DEST_DIR/ggml-metal.metal"
fi

if [ "${CODE_SIGNING_ALLOWED:-NO}" = "YES" ] && [ -n "${EXPANDED_CODE_SIGN_IDENTITY:-}" ]; then
  /usr/bin/codesign --force --sign "$EXPANDED_CODE_SIGN_IDENTITY" "$DESTINATION"
  for lib in "$DEST_DIR"/lib*.0.dylib; do
    if [ -f "$lib" ]; then
      /usr/bin/codesign --force --sign "$EXPANDED_CODE_SIGN_IDENTITY" "$lib"
    fi
  done
fi
