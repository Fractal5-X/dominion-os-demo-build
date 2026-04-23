#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SYNC_ENV_FILE="${PHI_SYNC_ENV_FILE:-${SCRIPT_DIR}/live_ops_sync.env}"
if [ -f "${SYNC_ENV_FILE}" ]; then
  set -a
  # shellcheck disable=SC1090
  . "${SYNC_ENV_FILE}"
  set +a
fi
TELEMETRY_DIR="${SCRIPT_DIR}/telemetry"
PID_FILE="${TELEMETRY_DIR}/intelligent_sync_daemon.pid"
LOCK_FILE="${TELEMETRY_DIR}/intelligent_sync_daemon.lock"
LOG_FILE="${TELEMETRY_DIR}/intelligent_sync_daemon.log"
SCRIPT_PATH="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/$(basename "${BASH_SOURCE[0]}")"
PATTERN="${SCRIPT_PATH} run"
SYNC_SCRIPT="${SCRIPT_DIR}/phi_intelligent_sync.sh"
INTERVAL="${PHI_INTELLIGENT_SYNC_INTERVAL:-120}"

mkdir -p "${TELEMETRY_DIR}"

is_alive() {
  [ -n "${1:-}" ] && kill -0 "$1" 2>/dev/null
}

current_pid() {
  local pid=""
  if [ -f "${PID_FILE}" ]; then
    pid="$(cat "${PID_FILE}" 2>/dev/null || true)"
  fi
  if is_alive "${pid}"; then
    echo "${pid}"
    return 0
  fi
  pid="$(ps -eo pid=,args= | awk -v pat="${PATTERN}" -v self="$$" 'index($0, pat) > 0 && $1 != self { print $1; exit }')"
  if is_alive "${pid}"; then
    echo "${pid}" > "${PID_FILE}"
    echo "${pid}"
  fi
}

start_daemon() {
  local pid
  pid="$(current_pid || true)"
  if [ -n "${pid}" ]; then
    echo "running(pid=${pid})"
    return 0
  fi
  if command -v setsid >/dev/null 2>&1; then
    setsid bash "${SCRIPT_PATH}" run >> "${LOG_FILE}" 2>&1 < /dev/null &
  else
    nohup bash "${SCRIPT_PATH}" run >> "${LOG_FILE}" 2>&1 &
  fi
  sleep 0.5
  pid="$(current_pid || true)"
  [ -n "${pid}" ] && echo "running(pid=${pid})" || {
    echo "stopped"
    return 1
  }
}

stop_daemon() {
  local pid
  pid="$(current_pid || true)"
  if [ -n "${pid}" ]; then
    kill "${pid}" 2>/dev/null || true
    sleep 0.5
    is_alive "${pid}" && kill -9 "${pid}" 2>/dev/null || true
  fi
  rm -f "${PID_FILE}"
  echo "stopped"
}

status_daemon() {
  local pid
  pid="$(current_pid || true)"
  [ -n "${pid}" ] && echo "running(pid=${pid})" || echo "stopped"
}

run_loop() {
  if [ ! -x "${SYNC_SCRIPT}" ]; then
    echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] missing sync script: ${SYNC_SCRIPT}" >> "${LOG_FILE}"
    exit 1
  fi

  exec 9>"${LOCK_FILE}"
  command -v flock >/dev/null 2>&1 && flock -n 9 || true
  echo $$ > "${PID_FILE}"
  trap 'rm -f "${PID_FILE}"' EXIT

  while true; do
    printf '[%s] intelligent sync sweep start\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" >> "${LOG_FILE}"
    if bash "${SYNC_SCRIPT}" >> "${LOG_FILE}" 2>&1; then
      printf '[%s] intelligent sync sweep complete\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" >> "${LOG_FILE}"
    else
      printf '[%s] intelligent sync sweep failed\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" >> "${LOG_FILE}"
    fi
    sleep "${INTERVAL}"
  done
}

case "${1:-start}" in
  start) start_daemon ;;
  stop) stop_daemon ;;
  restart) stop_daemon >/dev/null 2>&1 || true; start_daemon ;;
  status) status_daemon ;;
  run) run_loop ;;
  *) echo "Usage: $0 {start|stop|restart|status|run}"; exit 1 ;;
esac
