#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(CDPATH="" cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

TESTS=()
while IFS= read -r test_script; do
  TESTS+=("$test_script")
done < <(find "$SCRIPT_DIR" -maxdepth 1 -type f -name '*-smoke.sh' | sort)

if [ "${#TESTS[@]}" -eq 0 ]; then
  echo "No release smoke tests found in $SCRIPT_DIR" >&2
  exit 1
fi

for test_script in "${TESTS[@]}"; do
  echo "==> Running $(basename "$test_script")"
  bash "$test_script"
done

echo "All release smoke tests passed."
