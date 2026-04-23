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
PID_FILE="${TELEMETRY_DIR}/ecosystem_optimizer_daemon.pid"
LOCK_FILE="${TELEMETRY_DIR}/ecosystem_optimizer_daemon.lock"
LOG_FILE="${TELEMETRY_DIR}/ecosystem_optimizer_daemon.log"
SCRIPT_PATH="${SCRIPT_DIR}/$(basename "${BASH_SOURCE[0]}")"
PATTERN="${SCRIPT_PATH} run"
OPTIMIZER_SCRIPT="${SCRIPT_DIR}/ecosystem_optimizer.sh"
INTERVAL_SECONDS="${PHI_ECOSYSTEM_AUDIT_INTERVAL_SECONDS:-1800}"
APPLY_SAFE_ENABLED="${PHI_ECOSYSTEM_APPLY_SAFE_ENABLED:-1}"
APPLY_SAFE_EVERY_CYCLES="${PHI_ECOSYSTEM_APPLY_SAFE_EVERY_CYCLES:-12}"
APPLY_MODE="${PHI_ECOSYSTEM_APPLY_MODE:-apply-safe}"

mkdir -p "${TELEMETRY_DIR}"

is_alive() { [ -n "${1:-}" ] && kill -0 "$1" 2>/dev/null; }

current_pid() {
  local pid=""
  if [ -f "${PID_FILE}" ]; then
    pid="$(cat "${PID_FILE}" 2>/dev/null || true)"
  fi
  if is_alive "${pid}"; then
    printf '%s\n' "${pid}"
    return 0
  fi
  pid="$(
    ps -eo pid=,args= \
      | awk -v pat="${PATTERN}" -v self="$$" 'index($0, pat) > 0 && $1 != self { print $1; exit }'
  )"
  if is_alive "${pid}"; then
    echo "${pid}" > "${PID_FILE}"
    printf '%s\n' "${pid}"
  fi
}

start_daemon() {
  local pid
  if [ ! -x "${OPTIMIZER_SCRIPT}" ]; then
    echo "stopped"
    return 1
  fi

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
  if [ -n "${pid}" ]; then
    echo "running(pid=${pid})"
  else
    echo "stopped"
    return 1
  fi
}

stop_daemon() {
  local pid
  pid="$(current_pid || true)"
  if [ -n "${pid}" ]; then
    kill "${pid}" 2>/dev/null || true
    sleep 0.5
    if is_alive "${pid}"; then
      kill -9 "${pid}" 2>/dev/null || true
    fi
  fi
  rm -f "${PID_FILE}"
  echo "stopped"
}

status_daemon() {
  local pid
  pid="$(current_pid || true)"
  if [ -n "${pid}" ]; then
    echo "running(pid=${pid})"
  else
    echo "stopped"
  fi
}

run_loop() {
  local cycle=0
  exec 9>"${LOCK_FILE}"
  command -v flock >/dev/null 2>&1 && flock -n 9 || true

  echo $$ > "${PID_FILE}"
  trap 'rm -f "${PID_FILE}"' EXIT

  while true; do
    cycle=$((cycle + 1))
    printf '[%s] [INFO] cycle=%s audit start\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "${cycle}" >> "${LOG_FILE}"
    bash "${OPTIMIZER_SCRIPT}" audit >> "${LOG_FILE}" 2>&1 || true
    printf '[%s] [INFO] cycle=%s audit complete\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "${cycle}" >> "${LOG_FILE}"

    if [ "${APPLY_SAFE_ENABLED}" = "1" ] && [ "${APPLY_SAFE_EVERY_CYCLES}" -gt 0 ] && [ $((cycle % APPLY_SAFE_EVERY_CYCLES)) -eq 0 ]; then
      printf '[%s] [INFO] cycle=%s %s start\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "${cycle}" "${APPLY_MODE}" >> "${LOG_FILE}"
      bash "${OPTIMIZER_SCRIPT}" "${APPLY_MODE}" >> "${LOG_FILE}" 2>&1 || true
      printf '[%s] [INFO] cycle=%s %s complete\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "${cycle}" "${APPLY_MODE}" >> "${LOG_FILE}"
    fi

    sleep "${INTERVAL_SECONDS}"
  done
}

case "${1:-start}" in
  start) start_daemon ;;
  stop) stop_daemon ;;
  restart) stop_daemon >/dev/null 2>&1 || true; start_daemon ;;
  status) status_daemon ;;
  run) run_loop ;;
  *)
    echo "Usage: $0 {start|stop|restart|status|run}"
    exit 1
    ;;
esac
