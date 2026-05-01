#!/usr/bin/env bash

set -euo pipefail

require_env() {
  local name="$1"
  if [ -z "${!name:-}" ]; then
    printf 'missing required env var: %s\n' "$name" >&2
    exit 2
  fi
}

json_get() {
  local expr="$1"
  python3 -c '
import json
import sys

expr = sys.argv[1]
data = json.load(sys.stdin)
cur = data
for part in expr.split("."):
    if isinstance(cur, dict):
        cur = cur.get(part)
    else:
        cur = None
        break
if cur is None:
    sys.exit(1)
print(cur)
' "$expr"
}

api_base() {
  printf '%s' "${O11YFLEET_API_URL%/}"
}

duration_to_seconds() {
  local value="$1"
  case "$value" in
    *s) printf '%s\n' "${value%s}" ;;
    *m) printf '%s\n' "$(( ${value%m} * 60 ))" ;;
    *h) printf '%s\n' "$(( ${value%h} * 3600 ))" ;;
    *d) printf '%s\n' "$(( ${value%d} * 86400 ))" ;;
    *) printf '%s\n' "$value" ;;
  esac
}

request_json() {
  local method="$1"
  local path="$2"
  local body="${3:-}"
  local curl_args=()
  local tmp
  local status

  tmp="$(mktemp)"
  if [ -n "${TENANT_ID:-}" ]; then
    curl_args+=(-H "X-Tenant-Id: ${TENANT_ID}")
  fi
  if [ -n "$body" ]; then
    curl_args+=(-H "Content-Type: application/json" --data "$body")
  fi

  status="$(
    curl -sS -o "$tmp" -w '%{http_code}' \
      -X "$method" "$(api_base)$path" \
      -H "Authorization: Bearer ${API_SECRET}" \
      "${curl_args[@]}"
  )"

  if [[ "$status" != 2* ]]; then
    printf 'API %s %s failed with HTTP %s\n' "$method" "$path" "$status" >&2
    cat "$tmp" >&2
    printf '\n' >&2
    rm -f "$tmp"
    exit 1
  fi

  cat "$tmp"
  rm -f "$tmp"
}

request_yaml() {
  local path="$1"
  local file="$2"
  local tmp
  local status

  tmp="$(mktemp)"
  status="$(
    curl -sS -o "$tmp" -w '%{http_code}' \
      -X POST "$(api_base)$path" \
      -H "Authorization: Bearer ${API_SECRET}" \
      -H "X-Tenant-Id: ${TENANT_ID}" \
      -H "Content-Type: text/yaml" \
      --data-binary @"$file"
  )"

  if [[ "$status" != 2* ]]; then
    printf 'API POST %s failed with HTTP %s\n' "$path" "$status" >&2
    cat "$tmp" >&2
    printf '\n' >&2
    rm -f "$tmp"
    exit 1
  fi

  cat "$tmp"
  rm -f "$tmp"
}

# Request a GitHub Actions OIDC token for the given audience.
# Returns the JWT on stdout. Requires ACTIONS_ID_TOKEN_REQUEST_URL and
# ACTIONS_ID_TOKEN_REQUEST_TOKEN to be set (automatic in GHA with id-token permission).
get_oidc_token() {
  local audience="${1:-o11yfleet}"
  if [ -z "${ACTIONS_ID_TOKEN_REQUEST_URL:-}" ]; then
    printf 'OIDC: ACTIONS_ID_TOKEN_REQUEST_URL not set (not running in GitHub Actions?)\n' >&2
    exit 2
  fi
  local url="${ACTIONS_ID_TOKEN_REQUEST_URL}&audience=${audience}"
  local response
  response="$(curl -sS -H "Authorization: bearer ${ACTIONS_ID_TOKEN_REQUEST_TOKEN}" "$url")"
  printf '%s' "$response" | json_get value
}

# Like request_json but authenticates with a GitHub OIDC token instead of API_SECRET.
# Used for admin routes that require OIDC (e.g., POST /api/admin/tenants).
request_json_oidc() {
  local method="$1"
  local path="$2"
  local body="${3:-}"
  local oidc_token
  local curl_args=()
  local tmp
  local status

  oidc_token="$(get_oidc_token "${OIDC_AUDIENCE:-o11yfleet}")"

  tmp="$(mktemp)"
  if [ -n "${TENANT_ID:-}" ]; then
    curl_args+=(-H "X-Tenant-Id: ${TENANT_ID}")
  fi
  if [ -n "$body" ]; then
    curl_args+=(-H "Content-Type: application/json" --data "$body")
  fi

  status="$(
    curl -sS -o "$tmp" -w '%{http_code}' \
      -X "$method" "$(api_base)$path" \
      -H "Authorization: Bearer ${oidc_token}" \
      "${curl_args[@]}"
  )"

  if [[ "$status" != 2* ]]; then
    printf 'API (OIDC) %s %s failed with HTTP %s\n' "$method" "$path" "$status" >&2
    cat "$tmp" >&2
    printf '\n' >&2
    rm -f "$tmp"
    exit 1
  fi

  cat "$tmp"
  rm -f "$tmp"
}
