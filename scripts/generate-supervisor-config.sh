#!/usr/bin/env bash

set -euo pipefail

NUMPROCS="${NUMPROCS:-100}"
OUT_FILE="${OUT_FILE:-supervisord.ini}"

mkdir -p logs runtime

cat > "$OUT_FILE" <<EOF
[program:otelcol]
command=./scripts/run-collector.sh
environment=INSTANCE=%(process_num)d
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
EOF

printf '%s\n' "$OUT_FILE"
