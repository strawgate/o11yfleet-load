#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=lib.sh
source "$SCRIPT_DIR/lib.sh"

require_env O11YFLEET_API_URL
require_env API_SECRET
require_env TENANT_ID
require_env CONFIG_ID
require_env CONFIG_FILE

if [ ! -s "$CONFIG_FILE" ]; then
  printf 'config file not found or empty: %s\n' "$CONFIG_FILE" >&2
  exit 2
fi

printf 'Uploading %s to config %s\n' "$CONFIG_FILE" "$CONFIG_ID"
request_yaml "/api/v1/configurations/${CONFIG_ID}/versions" "$CONFIG_FILE" >/dev/null

printf 'Rolling out config %s\n' "$CONFIG_ID"
request_json POST "/api/v1/configurations/${CONFIG_ID}/rollout" '{}' | tee /dev/stderr

