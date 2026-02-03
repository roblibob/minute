#!/usr/bin/env bash
set -euo pipefail

xcresult_path=""
machine_output=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --xcresult)
      xcresult_path="$2"
      shift 2
      ;;
    --machine)
      if [[ $# -ge 2 && "$2" != --* ]]; then
        machine_output="$2"
        shift 2
      else
        machine_output="coverage-report.json"
        shift
      fi
      ;;
    *)
      xcresult_path="$1"
      shift
      ;;
  esac
done

if [[ -z "$xcresult_path" ]]; then
  echo "Usage: generate-coverage-summary.sh --xcresult <path> [--machine [output.json]]" >&2
  exit 2
fi

if [[ ! -d "$xcresult_path" && ! -f "$xcresult_path" ]]; then
  echo "XCResult not found: $xcresult_path" >&2
  exit 2
fi

xcrun xccov view --report "$xcresult_path"

if [[ -n "$machine_output" ]]; then
  xcrun xccov view --report --json "$xcresult_path" > "$machine_output"
fi
