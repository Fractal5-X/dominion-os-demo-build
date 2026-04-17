#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TELEMETRY_DIR="${SCRIPT_DIR}/telemetry"
LOG_FILE="${TELEMETRY_DIR}/degraded_watch_daemon.log"
WATCH_SCRIPT="${SCRIPT_DIR}/degraded_watch.sh"
RESTART_DELAY="${PHI_DEGRADED_WATCH_RESTART_DELAY:-2}"

mkdir -p "${TELEMETRY_DIR}"

log() {
  printf '[%s] %s\n' "$(date -u +'%Y-%m-%dT%H:%M:%SZ')" "$1" >> "${LOG_FILE}"
}

if [ ! -x "${WATCH_SCRIPT}" ]; then
  log "watch script missing or not executable: ${WATCH_SCRIPT}"
  exit 1
fi

log "degraded watch daemon started"

while true; do
  bash "${WATCH_SCRIPT}" >> "${TELEMETRY_DIR}/degraded_watch.log" 2>&1 || true
  log "watch worker exited; restarting in ${RESTART_DELAY}s"
  sleep "${RESTART_DELAY}"
done
