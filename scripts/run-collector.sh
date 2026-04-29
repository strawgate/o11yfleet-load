#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
# shellcheck source=lib.sh
source "$SCRIPT_DIR/lib.sh"

DURATION="${DURATION:-30m}"
DELAY_START="${DELAY_START:-120}"
INSTANCE="${INSTANCE:-0}"
JOB_INDEX="${JOB_INDEX:-0}"
COLLECTORS_PER_RUNNER="${COLLECTORS_PER_RUNNER:-100}"
FAILURE_PERCENT="${FAILURE_PERCENT:-0}"
OTELCOL_BIN="${OTELCOL_BIN:-/usr/bin/otelcol-contrib}"
RUN_ID="${RUN_ID:-local}"

require_env O11YFLEET_API_URL
require_env MAIN_ENROLLMENT_TOKEN
require_env CANARY_ENROLLMENT_TOKEN

GLOBAL_INDEX="$(( JOB_INDEX * COLLECTORS_PER_RUNNER + INSTANCE ))"
COHORT="main"
TOKEN="$MAIN_ENROLLMENT_TOKEN"
if [ "$FAILURE_PERCENT" -gt 0 ] && [ "$(( GLOBAL_INDEX % 100 ))" -lt "$FAILURE_PERCENT" ]; then
  COHORT="canary"
  TOKEN="$CANARY_ENROLLMENT_TOKEN"
fi

INSTANCE_UID="$(
  python3 - "$RUN_ID" "$GLOBAL_INDEX" <<'PY'
import sys
import uuid
print(uuid.uuid5(uuid.NAMESPACE_URL, f"o11yfleet-load:{sys.argv[1]}:{sys.argv[2]}"))
PY
)"

if [ "$DELAY_START" -gt 0 ]; then
  sleep "$(( RANDOM % DELAY_START ))"
fi

mkdir -p "$REPO_ROOT/runtime" "$REPO_ROOT/logs"
CONFIG_FILE="$REPO_ROOT/runtime/collector-${GLOBAL_INDEX}.yaml"
export RUN_ID JOB_INDEX INSTANCE GLOBAL_INDEX
"$SCRIPT_DIR/generate-collector-config.sh" "$CONFIG_FILE" "$TOKEN" "$INSTANCE_UID"

printf 'collector global_index=%s instance=%s cohort=%s uid=%s config=%s\n' \
  "$GLOBAL_INDEX" "$INSTANCE" "$COHORT" "$INSTANCE_UID" "$CONFIG_FILE"

exec timeout --preserve-status "$DURATION" "$OTELCOL_BIN" --config "$CONFIG_FILE"

