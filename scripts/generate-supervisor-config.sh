#!/usr/bin/env bash

set -euo pipefail

NUMPROCS="${NUMPROCS:-100}"
OUT_FILE="${OUT_FILE:-supervisord.ini}"

mkdir -p logs runtime

# Build environment line with all required vars for run-collector.sh.
# supervisord's %(ENV_X)s syntax references the supervisord process's own
# environment — this ensures child processes receive all GHA job-level vars.
ENV_LINE="INSTANCE=%(process_num)d"
for var in O11YFLEET_API_URL MAIN_ENROLLMENT_TOKEN CANARY_ENROLLMENT_TOKEN \
           RUN_ID JOB_INDEX COLLECTORS_PER_RUNNER DURATION DELAY_START \
           FAILURE_PERCENT COLLECTION_INTERVAL OPAMP_CLIENT; do
  if [ -n "${!var:-}" ]; then
    ENV_LINE="${ENV_LINE},${var}=\"%(ENV_${var})s\""
  fi
done

cat > "$OUT_FILE" <<CONF
[program:otelcol]
command=./scripts/run-collector.sh
environment=${ENV_LINE}
numprocs=${NUMPROCS}
process_name=%(program_name)s-%(process_num)d
startsecs=0
autorestart=false
exitcodes=0,124,143
stopwaitsecs=20
stdout_logfile=%(here)s/logs/%(program_name)s-%(process_num)d.log
stderr_logfile=%(here)s/logs/%(program_name)s-%(process_num)d.err.log

[supervisord]
loglevel=info
nodaemon=true
CONF

printf '%s\n' "$OUT_FILE"
