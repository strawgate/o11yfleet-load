#!/usr/bin/env bash

set -euo pipefail

OUT_FILE="${OUT_FILE:-results/runner-samples.csv}"
INTERVAL="${SAMPLE_INTERVAL:-15}"

mkdir -p "$(dirname "$OUT_FILE")"
printf 'timestamp,collector_processes,rss_kb,load1,mem_available_kb\n' > "$OUT_FILE"

while true; do
  timestamp="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  collector_processes="$(pgrep -fc 'otelcol-contrib' || true)"
  rss_kb="$(ps -C otelcol-contrib -o rss= 2>/dev/null | awk '{sum += $1} END {print sum + 0}')"
  load1="$(awk '{print $1}' /proc/loadavg 2>/dev/null || printf '0')"
  mem_available_kb="$(awk '/MemAvailable:/ {print $2}' /proc/meminfo 2>/dev/null || printf '0')"
  printf '%s,%s,%s,%s,%s\n' "$timestamp" "$collector_processes" "$rss_kb" "$load1" "$mem_available_kb" >> "$OUT_FILE"
  sleep "$INTERVAL"
done

