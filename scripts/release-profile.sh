#!/usr/bin/env bash
set -euo pipefail

DIST_PROFILE_APP_STORE="app-store"
DIST_PROFILE_DIRECT="direct"
DIST_PROFILE_DIRECT_DEFAULT_FEED_URL="https://roblibob.github.io/appcast.xml"
DIST_PROFILE_DIRECT_APP_ENTITLEMENTS="Minute/Sources/App/Minute.entitlements"
DIST_PROFILE_APP_STORE_APP_ENTITLEMENTS="Minute/Sources/App/MinuteAppStore.entitlements"
DIST_PROFILE_HELPER_ENTITLEMENTS="Minute/Sources/App/MinuteHelper.entitlements"
DIST_PROFILE_WHISPER_SERVICE_ENTITLEMENTS="MinuteWhisperService/MinuteWhisperService.entitlements"

release_profile_repo_root() {
  local script_dir
  script_dir="$(CDPATH="" cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  (cd "$script_dir/.." && pwd)
}

is_valid_dist_profile() {
  local profile="${1:-}"
  [[ "$profile" == "$DIST_PROFILE_APP_STORE" || "$profile" == "$DIST_PROFILE_DIRECT" ]]
}

require_dist_profile() {
  local profile="${1:-}"
  if [ -z "$profile" ]; then
    echo "error: DIST_PROFILE is required. Use '$DIST_PROFILE_APP_STORE' or '$DIST_PROFILE_DIRECT'." >&2
    return 1
  fi
  if ! is_valid_dist_profile "$profile"; then
    echo "error: invalid DIST_PROFILE '$profile'. Use '$DIST_PROFILE_APP_STORE' or '$DIST_PROFILE_DIRECT'." >&2
    return 1
  fi
}

profile_is_app_store() {
  [[ "${1:-}" == "$DIST_PROFILE_APP_STORE" ]]
}

profile_is_direct() {
  [[ "${1:-}" == "$DIST_PROFILE_DIRECT" ]]
}

profile_default_updater_enabled() {
  if profile_is_app_store "${1:-}"; then
    echo "NO"
    return
  fi
  echo "YES"
}

profile_default_su_feed_url() {
  if profile_is_app_store "${1:-}"; then
    echo ""
    return
  fi
  echo "$DIST_PROFILE_DIRECT_DEFAULT_FEED_URL"
}

profile_default_swift_distribution_flag() {
  if profile_is_app_store "${1:-}"; then
    echo "-DMINUTE_DISTRIBUTION_APP_STORE"
    return
  fi
  echo "-DMINUTE_DISTRIBUTION_DIRECT"
}

profile_default_app_entitlements() {
  if profile_is_app_store "${1:-}"; then
    echo "$DIST_PROFILE_APP_STORE_APP_ENTITLEMENTS"
    return
  fi
  echo "$DIST_PROFILE_DIRECT_APP_ENTITLEMENTS"
}

profile_default_helper_entitlements() {
  echo "$DIST_PROFILE_HELPER_ENTITLEMENTS"
}

profile_default_whisper_service_entitlements() {
  echo "$DIST_PROFILE_WHISPER_SERVICE_ENTITLEMENTS"
}

summary_default_path() {
  local output_dir="${1:-updates}"
  echo "$output_dir/release-validation-summary.json"
}

summary_init() {
  local summary_file="$1"
  local profile="$2"
  local run_id="$3"
  mkdir -p "$(dirname "$summary_file")"

  SUMMARY_FILE="$summary_file" PROFILE="$profile" RUN_ID="$run_id" python3 <<'PY'
import json
import os
from datetime import datetime, timezone

summary_file = os.environ["SUMMARY_FILE"]
profile = os.environ["PROFILE"]
run_id = os.environ["RUN_ID"]

payload = {
    "runId": run_id,
    "profile": profile,
    "status": "created",
    "checks": [],
    "artifacts": [],
    "startedAt": datetime.now(timezone.utc).isoformat(),
    "generatedAt": None,
}

with open(summary_file, "w", encoding="utf-8") as handle:
    json.dump(payload, handle, indent=2)
    handle.write("\n")
PY
}

summary_set_status() {
  local summary_file="$1"
  local status="$2"

  SUMMARY_FILE="$summary_file" STATUS="$status" python3 <<'PY'
import json
import os
from datetime import datetime, timezone

summary_file = os.environ["SUMMARY_FILE"]
status = os.environ["STATUS"]

with open(summary_file, encoding="utf-8") as handle:
    payload = json.load(handle)

payload["status"] = status
payload["generatedAt"] = datetime.now(timezone.utc).isoformat()

with open(summary_file, "w", encoding="utf-8") as handle:
    json.dump(payload, handle, indent=2)
    handle.write("\n")
PY
}

summary_add_check() {
  local summary_file="$1"
  local check_type="$2"
  local target="$3"
  local status="$4"
  local message="$5"
  local details="${6:-}"

  SUMMARY_FILE="$summary_file" CHECK_TYPE="$check_type" TARGET="$target" CHECK_STATUS="$status" MESSAGE="$message" DETAILS="$details" python3 <<'PY'
import json
import os

summary_file = os.environ["SUMMARY_FILE"]
check_type = os.environ["CHECK_TYPE"]
target = os.environ["TARGET"]
check_status = os.environ["CHECK_STATUS"]
message = os.environ["MESSAGE"]
details = os.environ.get("DETAILS", "")

with open(summary_file, encoding="utf-8") as handle:
    payload = json.load(handle)

entry = {
    "checkType": check_type,
    "target": target,
    "status": check_status,
    "message": message,
}
if details:
    entry["details"] = details

payload.setdefault("checks", []).append(entry)

with open(summary_file, "w", encoding="utf-8") as handle:
    json.dump(payload, handle, indent=2)
    handle.write("\n")
PY
}

summary_add_artifact() {
  local summary_file="$1"
  local artifact_type="$2"
  local path="$3"
  local profile="$4"

  SUMMARY_FILE="$summary_file" ARTIFACT_TYPE="$artifact_type" ARTIFACT_PATH="$path" PROFILE="$profile" python3 <<'PY'
import json
import os
from datetime import datetime, timezone

summary_file = os.environ["SUMMARY_FILE"]
artifact_type = os.environ["ARTIFACT_TYPE"]
artifact_path = os.environ["ARTIFACT_PATH"]
profile = os.environ["PROFILE"]

with open(summary_file, encoding="utf-8") as handle:
    payload = json.load(handle)

payload.setdefault("artifacts", []).append({
    "artifactType": artifact_type,
    "path": artifact_path,
    "profile": profile,
    "generatedAt": datetime.now(timezone.utc).isoformat(),
})

with open(summary_file, "w", encoding="utf-8") as handle:
    json.dump(payload, handle, indent=2)
    handle.write("\n")
PY
}
