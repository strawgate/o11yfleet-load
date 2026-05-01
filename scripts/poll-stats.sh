#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=lib.sh
source "$SCRIPT_DIR/lib.sh"

require_env O11YFLEET_API_URL
require_env API_SECRET
require_env TENANT_ID

OUT_FILE="${OUT_FILE:-results/stats.jsonl}"
INTERVAL="${POLL_INTERVAL:-30}"
COUNT="${POLL_COUNT:-20}"

mkdir -p "$(dirname "$OUT_FILE")"

MAX_RETRIES="${MAX_RETRIES:-3}"

fetch_stats() {
  local config_id="$1"
  local attempt
  for ((attempt = 1; attempt <= MAX_RETRIES; attempt++)); do
    if stats="$(request_json GET "/api/v1/configurations/${config_id}/stats" 2>/dev/null)"; then
      printf '%s' "$stats"
      return 0
    fi
    printf 'stats fetch attempt %d/%d failed for %s, retrying in %ds...\n' \
      "$attempt" "$MAX_RETRIES" "$config_id" "$((attempt * 2))" >&2
    sleep "$((attempt * 2))"
  done
  printf 'stats fetch failed after %d attempts for %s\n' "$MAX_RETRIES" "$config_id" >&2
  return 1
}

for ((i = 0; i < COUNT; i++)); do
  timestamp="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  for config_var in MAIN_CONFIG_ID CANARY_CONFIG_ID; do
    config_id="${!config_var:-}"
    if [ -z "$config_id" ]; then
      continue
    fi
    if ! stats="$(fetch_stats "$config_id")"; then
      printf '%s %s FETCH_FAILED\n' "$timestamp" "$config_var"
      continue
    fi
    python3 - "$timestamp" "$config_var" "$config_id" "$stats" >> "$OUT_FILE" <<'PY'
import json
import sys
row = {
    "timestamp": sys.argv[1],
    "cohort": sys.argv[2].replace("_CONFIG_ID", "").lower(),
    "config_id": sys.argv[3],
    "stats": json.loads(sys.argv[4]),
}
print(json.dumps(row, separators=(",", ":")))
PY
    printf '%s %s %s\n' "$timestamp" "$config_var" "$stats"
  done
  if [ "$i" -lt "$((COUNT - 1))" ]; then
    sleep "$INTERVAL"
  fi
done

