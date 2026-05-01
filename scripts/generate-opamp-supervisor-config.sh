#!/usr/bin/env bash

set -euo pipefail

if [ "$#" -lt 2 ]; then
  printf 'usage: %s <output.yaml> <enrollment-token>\n' "$0" >&2
  exit 2
fi

OUT_FILE="$1"
ENROLLMENT_TOKEN="$2"

O11YFLEET_API_URL="${O11YFLEET_API_URL:-http://localhost:8787}"
GLOBAL_INDEX="${GLOBAL_INDEX:-0}"
OTELCOL_BIN="${OTELCOL_BIN:-/usr/bin/otelcol-contrib}"
SUPERVISOR_STORAGE_ROOT="${SUPERVISOR_STORAGE_ROOT:-runtime/supervisor-data}"

WS_URL="${O11YFLEET_API_URL%/}"
WS_URL="${WS_URL/#https:/wss:}"
WS_URL="${WS_URL/#http:/ws:}"

mkdir -p "$(dirname "$OUT_FILE")" "${SUPERVISOR_STORAGE_ROOT}-${GLOBAL_INDEX}"

cat > "$OUT_FILE" <<EOF
server:
  endpoint: ${WS_URL}/v1/opamp
  headers:
    Authorization:
      - "Bearer ${ENROLLMENT_TOKEN}"

capabilities:
  reports_effective_config: true
  reports_own_metrics: true
  reports_own_logs: true
  reports_own_traces: true
  reports_health: true
  accepts_remote_config: true
  reports_remote_config: true
  reports_available_components: true

agent:
  executable: ${OTELCOL_BIN}
  args:
    # Disable internal Prometheus metrics endpoint (default :8888)
    # to avoid port conflicts with multiple collectors on same host
    - --set=service.telemetry.metrics.level=none

storage:
  directory: ${SUPERVISOR_STORAGE_ROOT}-${GLOBAL_INDEX}
EOF
