#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(CDPATH="" cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
HELPERS="$ROOT_DIR/scripts/release-profile.sh"
SCRIPT="$ROOT_DIR/scripts/release-notarize.sh"

source "$HELPERS"

if ! require_dist_profile "direct"; then
  echo "expected direct profile to be valid" >&2
  exit 1
fi

if require_dist_profile ""; then
  echo "expected empty profile to fail" >&2
  exit 1
fi

if require_dist_profile "invalid-profile"; then
  echo "expected invalid profile to fail" >&2
  exit 1
fi

missing_profile_output="$({ DIST_PROFILE="" "$SCRIPT" "/tmp/does-not-exist"; } 2>&1 || true)"
if [[ "$missing_profile_output" != *"DIST_PROFILE is required"* ]]; then
  echo "expected missing DIST_PROFILE validation error" >&2
  echo "$missing_profile_output" >&2
  exit 1
fi

invalid_profile_output="$({ DIST_PROFILE="bad" "$SCRIPT" "/tmp/does-not-exist"; } 2>&1 || true)"
if [[ "$invalid_profile_output" != *"invalid DIST_PROFILE"* ]]; then
  echo "expected invalid DIST_PROFILE validation error" >&2
  echo "$invalid_profile_output" >&2
  exit 1
fi

valid_profile_output="$({ DIST_PROFILE="direct" "$SCRIPT" "/tmp/does-not-exist"; } 2>&1 || true)"
if [[ "$valid_profile_output" != *"Release app not found"* ]]; then
  echo "expected script to continue past profile validation for valid profile" >&2
  echo "$valid_profile_output" >&2
  exit 1
fi

echo "release profile argument smoke checks passed"
