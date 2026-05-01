#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
# shellcheck source=lib.sh
source "$SCRIPT_DIR/lib.sh"

require_env O11YFLEET_API_URL
require_env API_SECRET

RUN_ID="${RUN_ID:-${GITHUB_RUN_ID:-local}-$(date -u +%Y%m%dT%H%M%SZ)}"
TENANT_NAME="${TENANT_NAME:-o11yfleet-load-${RUN_ID}}"
PLAN="${PLAN:-enterprise}"
TOKEN_TTL_HOURS="${TOKEN_TTL_HOURS:-24}"
OUT_FILE="${OUT_FILE:-$REPO_ROOT/run.env}"

printf 'Provisioning o11yFleet load run %s\n' "$RUN_ID"

# Tenant creation requires OIDC auth (admin route).
# When running in GHA, use the OIDC token; locally fall back to API_SECRET.
if [ -n "${ACTIONS_ID_TOKEN_REQUEST_URL:-}" ]; then
  printf 'Using GitHub OIDC for tenant creation\n'
  tenant_json="$(request_json_oidc POST /api/admin/tenants "{\"name\":\"${TENANT_NAME}\",\"plan\":\"${PLAN}\"}")"
else
  printf 'No OIDC available, falling back to API_SECRET for tenant creation\n'
  tenant_json="$(request_json POST /api/admin/tenants "{\"name\":\"${TENANT_NAME}\",\"plan\":\"${PLAN}\"}")"
fi
TENANT_ID="$(printf '%s' "$tenant_json" | json_get id)"
export TENANT_ID

main_config_json="$(request_json POST /api/v1/configurations "{\"name\":\"load-main-${RUN_ID}\"}")"
MAIN_CONFIG_ID="$(printf '%s' "$main_config_json" | json_get id)"

canary_config_json="$(request_json POST /api/v1/configurations "{\"name\":\"load-canary-${RUN_ID}\"}")"
CANARY_CONFIG_ID="$(printf '%s' "$canary_config_json" | json_get id)"

request_yaml "/api/v1/configurations/${MAIN_CONFIG_ID}/versions" "$REPO_ROOT/configs/healthy-rollout.yaml" >/dev/null
request_yaml "/api/v1/configurations/${CANARY_CONFIG_ID}/versions" "$REPO_ROOT/configs/healthy-rollout.yaml" >/dev/null

main_token_json="$(
  request_json POST "/api/v1/configurations/${MAIN_CONFIG_ID}/enrollment-token" \
    "{\"label\":\"load-main-${RUN_ID}\",\"expires_in_hours\":${TOKEN_TTL_HOURS}}"
)"
MAIN_ENROLLMENT_TOKEN="$(printf '%s' "$main_token_json" | json_get token)"

canary_token_json="$(
  request_json POST "/api/v1/configurations/${CANARY_CONFIG_ID}/enrollment-token" \
    "{\"label\":\"load-canary-${RUN_ID}\",\"expires_in_hours\":${TOKEN_TTL_HOURS}}"
)"
CANARY_ENROLLMENT_TOKEN="$(printf '%s' "$canary_token_json" | json_get token)"

mkdir -p "$(dirname "$OUT_FILE")"
cat > "$OUT_FILE" <<EOF
RUN_ID=$RUN_ID
TENANT_ID=$TENANT_ID
MAIN_CONFIG_ID=$MAIN_CONFIG_ID
CANARY_CONFIG_ID=$CANARY_CONFIG_ID
MAIN_ENROLLMENT_TOKEN=$MAIN_ENROLLMENT_TOKEN
CANARY_ENROLLMENT_TOKEN=$CANARY_ENROLLMENT_TOKEN
EOF

printf 'tenant_id=%s\n' "$TENANT_ID"
printf 'main_config_id=%s\n' "$MAIN_CONFIG_ID"
printf 'canary_config_id=%s\n' "$CANARY_CONFIG_ID"
printf 'run_env=%s\n' "$OUT_FILE"

if [ -n "${GITHUB_OUTPUT:-}" ]; then
  {
    printf 'run_id=%s\n' "$RUN_ID"
    printf 'tenant_id=%s\n' "$TENANT_ID"
    printf 'main_config_id=%s\n' "$MAIN_CONFIG_ID"
    printf 'canary_config_id=%s\n' "$CANARY_CONFIG_ID"
    printf 'main_enrollment_token=%s\n' "$MAIN_ENROLLMENT_TOKEN"
    printf 'canary_enrollment_token=%s\n' "$CANARY_ENROLLMENT_TOKEN"
  } >> "$GITHUB_OUTPUT"
fi
