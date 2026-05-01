#!/usr/bin/env bash

set -euo pipefail

NUMPROCS="${NUMPROCS:-100}"
OUT_FILE="${OUT_FILE:-supervisord.ini}"

mkdir -p logs runtime

cat > "$OUT_FILE" <<CONF
[program:otelcol]
command=bash -c "export INSTANCE=%(process_num)d && exec ./scripts/run-collector.sh"
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
