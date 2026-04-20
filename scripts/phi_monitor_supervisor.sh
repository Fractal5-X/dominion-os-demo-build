#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TELEMETRY_DIR="${SCRIPT_DIR}/telemetry"
PID_FILE="${TELEMETRY_DIR}/monitor_supervisor.pid"
LOCK_FILE="${TELEMETRY_DIR}/monitor_supervisor.lock"
LOG_FILE="${TELEMETRY_DIR}/monitor_supervisor.log"
SCRIPT_PATH="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/$(basename "${BASH_SOURCE[0]}")"
PATTERN="${SCRIPT_PATH} run"
INTERVAL="${PHI_MONITOR_SUPERVISOR_INTERVAL:-15}"
CONTINUOUS_SCRIPT="${SCRIPT_DIR}/telemetry/continuous_monitor.sh"
SOVEREIGN_SCRIPT="${SCRIPT_DIR}/sovereign_monitor.sh"
AUTO_AUDIT_SCRIPT="/workspaces/dominion-command-center/scripts/live_ops_auto_audit_daemon.sh"

mkdir -p "${TELEMETRY_DIR}"

is_alive() { [ -n "${1:-}" ] && kill -0 "$1" 2>/dev/null; }
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
normalize_status() {
  local value="$1"
  case "${value}" in
    running\(pid=*) printf '%s\n' "${value}" ;;
    *) printf 'stopped\n' ;;
  esac
}
component_status() {
  local script="$1"
  if [ -x "${script}" ]; then
    normalize_status "$(bash "${script}" status 2>/dev/null || true)"
  else
    echo "stopped"
  fi
}
auto_audit_status() {
  if [ -x "${AUTO_AUDIT_SCRIPT}" ]; then
    normalize_status "$(bash "${AUTO_AUDIT_SCRIPT}" status 2>/dev/null || true)"
  else
    echo "stopped"
  fi
}
print_status() {
  local supervisor_status="stopped"
  local pid
  pid="$(current_pid || true)"
  [ -n "${pid}" ] && supervisor_status="running(pid=${pid})"
  printf 'supervisor=%s\n' "${supervisor_status}"
  printf 'continuous_monitor=%s\n' "$(component_status "${CONTINUOUS_SCRIPT}")"
  printf 'sovereign_monitor=%s\n' "$(component_status "${SOVEREIGN_SCRIPT}")"
  printf 'auto_audit=%s\n' "$(auto_audit_status)"
}
ensure_components() {
  [ -x "${CONTINUOUS_SCRIPT}" ] && bash "${CONTINUOUS_SCRIPT}" start >/dev/null 2>&1 || true
  [ -x "${SOVEREIGN_SCRIPT}" ] && bash "${SOVEREIGN_SCRIPT}" start >/dev/null 2>&1 || true
  [ -x "${AUTO_AUDIT_SCRIPT}" ] && bash "${AUTO_AUDIT_SCRIPT}" start >/dev/null 2>&1 || true
  bash "${SCRIPT_DIR}/phi_start_all_systems.sh" --ensure-services-only --skip-monitor-start --quiet >/dev/null 2>&1 || true
}
start_daemon() {
  local pid
  pid="$(current_pid || true)"
  ensure_components
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
  [ -n "${pid}" ] && echo "running(pid=${pid})" || { echo "stopped"; return 1; }
}
stop_daemon() {
  local pid
  pid="$(current_pid || true)"
  if [ -n "${pid}" ]; then
    kill "${pid}" 2>/dev/null || true
    sleep 0.5
    is_alive "${pid}" && kill -9 "${pid}" 2>/dev/null || true
  fi
  [ -x "${CONTINUOUS_SCRIPT}" ] && bash "${CONTINUOUS_SCRIPT}" stop >/dev/null 2>&1 || true
  [ -x "${SOVEREIGN_SCRIPT}" ] && bash "${SOVEREIGN_SCRIPT}" stop >/dev/null 2>&1 || true
  [ -x "${AUTO_AUDIT_SCRIPT}" ] && bash "${AUTO_AUDIT_SCRIPT}" stop >/dev/null 2>&1 || true
  rm -f "${PID_FILE}"
  echo "stopped"
}
run_loop() {
  exec 9>"${LOCK_FILE}"
  command -v flock >/dev/null 2>&1 && flock -n 9 || true
  echo $$ > "${PID_FILE}"
  trap 'rm -f "${PID_FILE}"' EXIT
  while true; do
    ensure_components
    printf '[%s] supervisor cycle complete\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" >> "${LOG_FILE}"
    sleep "${INTERVAL}"
  done
}
case "${1:-start}" in
  start) start_daemon ;;
  stop) stop_daemon ;;
  restart) stop_daemon >/dev/null 2>&1 || true; start_daemon ;;
  status) print_status ;;
  run) run_loop ;;
  *) echo "Usage: $0 {start|stop|restart|status|run}"; exit 1 ;;
esac
