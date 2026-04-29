#!/usr/bin/env bash

set -euo pipefail

if [ "$#" -lt 3 ]; then
  printf 'usage: %s <output.yaml> <enrollment-token> <instance-uuid>\n' "$0" >&2
  exit 2
fi

OUT_FILE="$1"
ENROLLMENT_TOKEN="$2"
INSTANCE_UID="$3"

O11YFLEET_API_URL="${O11YFLEET_API_URL:-http://localhost:8787}"
RUN_ID="${RUN_ID:-local}"
JOB_INDEX="${JOB_INDEX:-0}"
INSTANCE="${INSTANCE:-0}"
GLOBAL_INDEX="${GLOBAL_INDEX:-0}"
SERVICE_NAME="${SERVICE_NAME:-o11yfleet-load}"
COLLECTION_INTERVAL="${COLLECTION_INTERVAL:-60s}"

WS_URL="${O11YFLEET_API_URL%/}"
WS_URL="${WS_URL/#https:/wss:}"
WS_URL="${WS_URL/#http:/ws:}"
OPAMP_TLS_INSECURE="${OPAMP_TLS_INSECURE:-false}"
if [[ "$WS_URL" == ws://* ]]; then
  OPAMP_TLS_INSECURE="true"
fi

mkdir -p "$(dirname "$OUT_FILE")"

cat > "$OUT_FILE" <<EOF
extensions:
  opamp:
    server:
      ws:
        endpoint: ${WS_URL}/v1/opamp
        headers:
          Authorization: "Bearer ${ENROLLMENT_TOKEN}"
        tls:
          insecure: ${OPAMP_TLS_INSECURE}
    instance_uid: "${INSTANCE_UID}"
    capabilities:
      reports_effective_config: true
      reports_health: true

receivers:
  hostmetrics:
    collection_interval: ${COLLECTION_INTERVAL}
    scrapers:
      cpu:
      memory:
      load:
      filesystem:

processors:
  resource/load:
    attributes:
      - key: service.name
        value: ${SERVICE_NAME}
        action: upsert
      - key: o11yfleet.load.run_id
        value: ${RUN_ID}
        action: upsert
      - key: o11yfleet.load.job_index
        value: "${JOB_INDEX}"
        action: upsert
      - key: o11yfleet.load.instance
        value: "${INSTANCE}"
        action: upsert
      - key: o11yfleet.load.global_index
        value: "${GLOBAL_INDEX}"
        action: upsert
  batch:
    timeout: 5s

exporters:
EOF

if [ -n "${PROJECT_OTLP_ENDPOINT:-}" ]; then
  cat >> "$OUT_FILE" <<EOF
  otlp/project:
    endpoint: ${PROJECT_OTLP_ENDPOINT}
EOF
  if [ -n "${PROJECT_OTLP_API_KEY:-}" ]; then
    cat >> "$OUT_FILE" <<EOF
    headers:
      authorization: "ApiKey ${PROJECT_OTLP_API_KEY}"
EOF
  fi
  EXPORTERS="[otlp/project]"
else
  cat >> "$OUT_FILE" <<EOF
  debug:
    verbosity: basic
EOF
  EXPORTERS="[debug]"
fi

cat >> "$OUT_FILE" <<EOF

service:
  extensions: [opamp]
  pipelines:
    metrics:
      receivers: [hostmetrics]
      processors: [resource/load, batch]
      exporters: ${EXPORTERS}
  telemetry:
    logs:
      level: warn
    metrics:
      level: none
EOF

