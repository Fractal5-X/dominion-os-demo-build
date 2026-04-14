#!/usr/bin/env bash
set -euo pipefail

if [[ "$#" -ne 3 ]]; then
  echo "usage: $(basename "$0") <pid-file> <log-file> <command-string>" >&2
  exit 1
fi

PID_FILE="$1"
LOG_FILE="$2"
COMMAND_STRING="$3"

mkdir -p "$(dirname "$PID_FILE")" "$(dirname "$LOG_FILE")"
rm -f "$PID_FILE"

if command -v setsid >/dev/null 2>&1; then
  DETACHED_PID_FILE="$PID_FILE" \
  DETACHED_LOG_FILE="$LOG_FILE" \
  DETACHED_COMMAND="$COMMAND_STRING" \
    setsid bash -lc 'echo $$ > "$DETACHED_PID_FILE"; exec bash -lc "$DETACHED_COMMAND" >> "$DETACHED_LOG_FILE" 2>&1 < /dev/null' >/dev/null 2>&1 &
else
  DETACHED_PID_FILE="$PID_FILE" \
  DETACHED_LOG_FILE="$LOG_FILE" \
  DETACHED_COMMAND="$COMMAND_STRING" \
    bash -lc 'echo $$ > "$DETACHED_PID_FILE"; exec bash -lc "$DETACHED_COMMAND" >> "$DETACHED_LOG_FILE" 2>&1 < /dev/null' &
fi

for _ in $(seq 1 50); do
  [[ -s "$PID_FILE" ]] && break
  sleep 0.1
done

if [[ -f "$PID_FILE" ]]; then
  cat "$PID_FILE"
fi
