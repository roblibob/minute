#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
UPDATES_DIR="${1:-$ROOT_DIR/updates}"
DOWNLOAD_URL_PREFIX="${2:-}"
EXTRA_ARGS=()

if [ "${1:-}" = "-h" ] || [ "${1:-}" = "--help" ]; then
  cat <<EOF
Usage: scripts/generate-appcast.sh [updates_dir] [download_url_prefix]

Examples:
  scripts/generate-appcast.sh
  scripts/generate-appcast.sh "$ROOT_DIR/updates" "https://github.com/roblibob/Minute/releases/download/v0.7.1/"

Set SPARKLE_BIN to Sparkle's bin directory or the generate_appcast path.
Set SPARKLE_APPCAST_ARGS to pass extra flags to generate_appcast.
EOF
  exit 0
fi

if [ ! -d "$UPDATES_DIR" ]; then
  echo "Updates directory not found: $UPDATES_DIR" >&2
  exit 1
fi

resolve_generate_appcast() {
  local tool=""

  if [ -n "${SPARKLE_BIN:-}" ]; then
    if [ -x "$SPARKLE_BIN/generate_appcast" ]; then
      tool="$SPARKLE_BIN/generate_appcast"
    elif [ -x "$SPARKLE_BIN" ]; then
      tool="$SPARKLE_BIN"
    else
      echo "SPARKLE_BIN does not point to generate_appcast or its directory." >&2
      exit 1
    fi
  else
    tool="$(find "$HOME/Library/Developer/Xcode/DerivedData" -path "*Sparkle/bin/generate_appcast" -print -quit 2>/dev/null || true)"
    if [ -z "$tool" ]; then
      echo "generate_appcast not found. Set SPARKLE_BIN to Sparkle's bin directory or tool path." >&2
      exit 1
    fi
  fi

  printf "%s" "$tool"
}

if [ -n "${SPARKLE_APPCAST_ARGS:-}" ]; then
  # shellcheck disable=SC2206
  EXTRA_ARGS+=(${SPARKLE_APPCAST_ARGS})
fi

GENERATE_APPCAST="$(resolve_generate_appcast)"
ARGS=()

if [ -n "$DOWNLOAD_URL_PREFIX" ]; then
  ARGS+=(--download-url-prefix "$DOWNLOAD_URL_PREFIX")
fi

"$GENERATE_APPCAST" "${ARGS[@]}" "${EXTRA_ARGS[@]}" "$UPDATES_DIR"
echo "Generated appcast at $UPDATES_DIR/appcast.xml"
