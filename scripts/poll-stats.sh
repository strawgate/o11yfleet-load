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

for ((i = 0; i < COUNT; i++)); do
  timestamp="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  for config_var in MAIN_CONFIG_ID CANARY_CONFIG_ID; do
    config_id="${!config_var:-}"
    if [ -z "$config_id" ]; then
      continue
    fi
    stats="$(request_json GET "/api/v1/configurations/${config_id}/stats")"
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

