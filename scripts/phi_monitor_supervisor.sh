#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TELEMETRY_DIR="${SCRIPT_DIR}/telemetry"
SUPERVISOR_PID_FILE="${TELEMETRY_DIR}/monitor_supervisor.pid"
SUPERVISOR_LOCK_FILE="${TELEMETRY_DIR}/monitor_supervisor.lock"
SUPERVISOR_LOG="${TELEMETRY_DIR}/monitor_supervisor.log"
CHECK_INTERVAL="${PHI_SUPERVISOR_INTERVAL:-20}"
DETACHED_EXEC_SCRIPT="${SCRIPT_DIR}/detached_exec.sh"

CONTINUOUS_SCRIPT="${TELEMETRY_DIR}/continuous_monitor.sh"
CONTINUOUS_PID_FILE="${TELEMETRY_DIR}/monitor.pid"
CONTINUOUS_PATTERN="${TELEMETRY_DIR}/continuous_monitor.sh"
SOVEREIGN_SCRIPT="${SCRIPT_DIR}/sovereign_monitor.sh"
SOVEREIGN_PID_FILE="${TELEMETRY_DIR}/sovereign_monitor_launcher.pid"
# Match both absolute and relative invocations (e.g., "./sovereign_monitor.sh")
SOVEREIGN_PATTERN="sovereign_monitor.sh"
AUTO_AUDIT_SCRIPT="/workspaces/dominion-command-center/scripts/live_ops_auto_audit_daemon.sh"
AUTO_AUDIT_PID_FILE="/workspaces/dominion-command-center/out/audits/auto/daemon.pid"
AUTO_AUDIT_PATTERN="${AUTO_AUDIT_SCRIPT} run"
SUPERVISOR_PATTERN="${SCRIPT_DIR}/phi_monitor_supervisor.sh run"

mkdir -p "${TELEMETRY_DIR}"

log() {
  printf '[%s] %s\n' "$(date -u +'%Y-%m-%dT%H:%M:%SZ')" "$1" | tee -a "${SUPERVISOR_LOG}"
}

is_pid_alive() {
  local pid="$1"
  [ -n "${pid}" ] && kill -0 "${pid}" 2>/dev/null
}

read_pid_file() {
  local pid_file="$1"
  if [ -f "${pid_file}" ]; then
    cat "${pid_file}" 2>/dev/null || true
  fi
}

write_pid_file() {
  local pid_file="$1"
  local pid="$2"
  if [ -n "${pid}" ]; then
    echo "${pid}" > "${pid_file}"
  fi
}

pid_matches_pattern() {
  local pid="$1"
  local pattern="$2"
  local cmd=""

  if ! is_pid_alive "${pid}"; then
    return 1
  fi

  cmd="$(ps -p "${pid}" -o args= 2>/dev/null || true)"
  [ -n "${cmd}" ] && [[ "${cmd}" == *"${pattern}"* ]]
}

first_pid_from_pattern() {
  local pattern="$1"
  ps -eo pid=,args= | awk -v pat="${pattern}" -v self="$$" -v ppid="${PPID:-}" '
    index($0, pat) > 0 {
      pid=$1
      if (pid != self && pid != ppid) {
        print pid
        exit
      }
    }'
}

resolve_pid() {
  local pid_file="$1"
  local pattern="$2"
  local pid=""

  pid="$(read_pid_file "${pid_file}")"
  if ! pid_matches_pattern "${pid}" "${pattern}"; then
    pid="$(first_pid_from_pattern "${pattern}" || true)"
  fi

  if pid_matches_pattern "${pid}" "${pattern}"; then
    write_pid_file "${pid_file}" "${pid}"
    echo "${pid}"
  else
    echo ""
  fi
}

kill_process_if_matching() {
  local pid="$1"
  local pattern="$2"

  if pid_matches_pattern "${pid}" "${pattern}"; then
    kill "${pid}" 2>/dev/null || true
    sleep 1
    if pid_matches_pattern "${pid}" "${pattern}"; then
      kill -9 "${pid}" 2>/dev/null || true
    fi
    return 0
  fi

  return 1
}

with_lock_or_exit() {
  exec 9>"${SUPERVISOR_LOCK_FILE}"
  if command -v flock >/dev/null 2>&1; then
    if ! flock -n 9; then
      log "Another supervisor instance is active; exiting"
      exit 0
    fi
  fi
}

start_continuous_monitor() {
  if [ ! -x "${CONTINUOUS_SCRIPT}" ]; then
    log "continuous monitor script missing: ${CONTINUOUS_SCRIPT}"
    return 1
  fi

  nohup bash "${CONTINUOUS_SCRIPT}" >> "${TELEMETRY_DIR}/continuous_monitor.log" 2>&1 &
  local pid=$!
  sleep 1

  if ! pid_matches_pattern "${pid}" "${CONTINUOUS_PATTERN}"; then
    pid="$(first_pid_from_pattern "${CONTINUOUS_PATTERN}" || true)"
  fi

  if pid_matches_pattern "${pid}" "${CONTINUOUS_PATTERN}"; then
    write_pid_file "${CONTINUOUS_PID_FILE}" "${pid}"
    log "Started continuous monitor (PID ${pid})"
  else
    log "Continuous monitor start attempt did not remain active"
    return 1
  fi
}

start_sovereign_monitor() {
  nohup bash "${SOVEREIGN_SCRIPT}" >> "${TELEMETRY_DIR}/sovereign_monitor_boot.log" 2>&1 &
  local pid=$!
  sleep 1

  if ! pid_matches_pattern "${pid}" "${SOVEREIGN_PATTERN}"; then
    pid="$(first_pid_from_pattern "${SOVEREIGN_PATTERN}" || true)"
  fi

  if pid_matches_pattern "${pid}" "${SOVEREIGN_PATTERN}"; then
    write_pid_file "${SOVEREIGN_PID_FILE}" "${pid}"
    log "Started sovereign monitor (PID ${pid})"
  else
    log "Sovereign monitor start attempt did not remain active"
    return 1
  fi
}

start_auto_audit_daemon() {
  if [ ! -x "${AUTO_AUDIT_SCRIPT}" ]; then
    log "auto audit daemon script missing: ${AUTO_AUDIT_SCRIPT}"
    return 1
  fi

  bash "${AUTO_AUDIT_SCRIPT}" start >> "${TELEMETRY_DIR}/monitor_supervisor.log" 2>&1 || true
  mkdir -p "$(dirname "${AUTO_AUDIT_PID_FILE}")"
  local pid=""
  local _attempt
  for _attempt in $(seq 1 20); do
    pid="$(read_pid_file "${AUTO_AUDIT_PID_FILE}")"
    if pid_matches_pattern "${pid}" "${AUTO_AUDIT_PATTERN}"; then
      break
    fi
    sleep 0.1
  done

  if ! pid_matches_pattern "${pid}" "${AUTO_AUDIT_PATTERN}"; then
    pid="$(first_pid_from_pattern "${AUTO_AUDIT_PATTERN}" || true)"
  fi

  if pid_matches_pattern "${pid}" "${AUTO_AUDIT_PATTERN}"; then
    write_pid_file "${AUTO_AUDIT_PID_FILE}" "${pid}"
    log "Started auto audit daemon (PID ${pid})"
  else
    log "Auto audit daemon start attempt did not remain active"
    return 1
  fi
}

ensure_continuous_monitor() {
  local pid=""
  pid="$(resolve_pid "${CONTINUOUS_PID_FILE}" "${CONTINUOUS_PATTERN}")"
  if [ -n "${pid}" ]; then
    return 0
  fi

  start_continuous_monitor || true
}

ensure_sovereign_monitor() {
  local pid=""
  pid="$(resolve_pid "${SOVEREIGN_PID_FILE}" "${SOVEREIGN_PATTERN}")"
  if [ -n "${pid}" ]; then
    return 0
  fi

  start_sovereign_monitor || true
}

ensure_auto_audit_daemon() {
  local pid=""
  pid="$(resolve_pid "${AUTO_AUDIT_PID_FILE}" "${AUTO_AUDIT_PATTERN}")"
  if [ -n "${pid}" ]; then
    return 0
  fi

  start_auto_audit_daemon || true
}

run_supervisor() {
  with_lock_or_exit
  echo "$$" > "${SUPERVISOR_PID_FILE}"
  log "Monitor supervisor active (interval=${CHECK_INTERVAL}s)"

  trap 'if [ "$(read_pid_file "${SUPERVISOR_PID_FILE}")" = "$$" ]; then rm -f "${SUPERVISOR_PID_FILE}"; fi; log "Monitor supervisor stopped"; exit 0' INT TERM

  while true; do
    ensure_continuous_monitor
    ensure_sovereign_monitor
    ensure_auto_audit_daemon
    sleep "${CHECK_INTERVAL}"
  done
}

start_daemon() {
  local active_pid=""
  active_pid="$(resolve_pid "${SUPERVISOR_PID_FILE}" "${SUPERVISOR_PATTERN}")"
  if [ -n "${active_pid}" ]; then
    log "Supervisor already running (PID ${active_pid})"
    return 0
  fi

  local pid=""
  if command -v setsid >/dev/null 2>&1; then
    setsid bash "$0" run >> "${SUPERVISOR_LOG}" 2>&1 < /dev/null &
    pid=$!
  else
    nohup bash "$0" run >> "${SUPERVISOR_LOG}" 2>&1 &
    pid=$!
  fi
  sleep 1

  active_pid="$(resolve_pid "${SUPERVISOR_PID_FILE}" "${SUPERVISOR_PATTERN}")"
  if [ -n "${active_pid}" ]; then
    if [ -n "${pid}" ] && [ "${pid}" != "${active_pid}" ]; then
      log "Supervisor daemon active (PID ${active_pid}; launcher PID ${pid})"
    else
      log "Supervisor daemon started (PID ${active_pid})"
    fi
  else
    log "Supervisor daemon start attempt did not remain active"
  fi
}

stop_all() {
  local pid=""

  pid="$(resolve_pid "${SUPERVISOR_PID_FILE}" "${SUPERVISOR_PATTERN}")"
  if [ -n "${pid}" ]; then
    kill_process_if_matching "${pid}" "${SUPERVISOR_PATTERN}" || true
    log "Supervisor daemon stop requested"
  fi
  rm -f "${SUPERVISOR_PID_FILE}"

  pid="$(resolve_pid "${CONTINUOUS_PID_FILE}" "${CONTINUOUS_PATTERN}")"
  if [ -n "${pid}" ]; then
    kill_process_if_matching "${pid}" "${CONTINUOUS_PATTERN}" || true
    log "Continuous monitor stop requested"
  fi
  rm -f "${CONTINUOUS_PID_FILE}"

  pid="$(resolve_pid "${SOVEREIGN_PID_FILE}" "${SOVEREIGN_PATTERN}")"
  if [ -n "${pid}" ]; then
    kill_process_if_matching "${pid}" "${SOVEREIGN_PATTERN}" || true
    log "Sovereign monitor stop requested"
  fi
  rm -f "${SOVEREIGN_PID_FILE}"

  if [ -x "${AUTO_AUDIT_SCRIPT}" ]; then
    bash "${AUTO_AUDIT_SCRIPT}" stop >> "${SUPERVISOR_LOG}" 2>&1 || true
  fi
  pid="$(resolve_pid "${AUTO_AUDIT_PID_FILE}" "${AUTO_AUDIT_PATTERN}")"
  if [ -n "${pid}" ]; then
    kill_process_if_matching "${pid}" "${AUTO_AUDIT_PATTERN}" || true
    log "Auto audit daemon stop requested"
  fi
  rm -f "${AUTO_AUDIT_PID_FILE}"
}

status_all() {
  local sup="stopped"
  local cm="stopped"
  local sm="stopped"
  local aa="stopped"
  local sup_pid=""
  local cm_pid=""
  local sm_pid=""
  local aa_pid=""

  sup_pid="$(resolve_pid "${SUPERVISOR_PID_FILE}" "${SUPERVISOR_PATTERN}")"
  if [ -n "${sup_pid}" ]; then
    sup="running(pid=${sup_pid})"
  fi

  cm_pid="$(resolve_pid "${CONTINUOUS_PID_FILE}" "${CONTINUOUS_PATTERN}")"
  if [ -n "${cm_pid}" ]; then
    cm="running(pid=${cm_pid})"
  fi

  sm_pid="$(resolve_pid "${SOVEREIGN_PID_FILE}" "${SOVEREIGN_PATTERN}")"
  if [ -n "${sm_pid}" ]; then
    sm="running(pid=${sm_pid})"
  fi

  aa_pid="$(resolve_pid "${AUTO_AUDIT_PID_FILE}" "${AUTO_AUDIT_PATTERN}")"
  if [ -n "${aa_pid}" ]; then
    aa="running(pid=${aa_pid})"
  fi

  printf 'supervisor=%s\ncontinuous_monitor=%s\nsovereign_monitor=%s\nauto_audit=%s\n' "${sup}" "${cm}" "${sm}" "${aa}"
}

case "${1:-start}" in
  start) start_daemon ;;
  run) run_supervisor ;;
  stop) stop_all ;;
  restart) stop_all; sleep 1; start_daemon ;;
  status) status_all ;;
  *)
    echo "Usage: $0 {start|run|stop|restart|status}"
    exit 1
    ;;
esac
