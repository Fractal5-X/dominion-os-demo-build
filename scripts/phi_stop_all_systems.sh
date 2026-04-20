#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
LOG_DIR="${SCRIPT_DIR}/logs"
TELEMETRY_DIR="${SCRIPT_DIR}/telemetry"
STOP_LOG="${LOG_DIR}/phi_shutdown_$(date -u +%Y%m%d_%H%M%S).log"
QUIET=0

[ "${1:-}" = "--quiet" ] && QUIET=1

mkdir -p "${LOG_DIR}" "${TELEMETRY_DIR}"

say() {
  if [ "${QUIET}" -eq 0 ]; then
    printf '%s\n' "$*"
  fi
  printf '%s\n' "$*" >> "${STOP_LOG}"
}

stop_pid_file() {
  local label="$1"
  local pid_file="$2"
  local pid=""

  if [ ! -f "${pid_file}" ]; then
    say "ℹ️  ${label} not running"
    return 0
  fi

  pid="$(cat "${pid_file}" 2>/dev/null || true)"
  if [ -z "${pid}" ]; then
    rm -f "${pid_file}"
    say "ℹ️  ${label} pid file was empty"
    return 0
  fi

  if kill -0 "${pid}" 2>/dev/null; then
    kill "${pid}" 2>/dev/null || true
    sleep 0.5
    if kill -0 "${pid}" 2>/dev/null; then
      kill -9 "${pid}" 2>/dev/null || true
    fi
    say "✅ ${label} stopped (PID: ${pid})"
  else
    say "ℹ️  ${label} already stopped"
  fi

  rm -f "${pid_file}"
}

say "[$(date -u +'%Y-%m-%d %H:%M:%S')] PHI System Shutdown initiated"

if [ -x "${SCRIPT_DIR}/phi_monitor_supervisor.sh" ]; then
  bash "${SCRIPT_DIR}/phi_monitor_supervisor.sh" stop >> "${STOP_LOG}" 2>&1 || true
  say "✅ Monitor supervisor stopped"
fi

stop_pid_file "Politics-Local-Legacy" "${LOG_DIR}/politics_legacy.pid"
stop_pid_file "ChatGPT-Gateway" "${LOG_DIR}/chatgpt_gateway.pid"
stop_pid_file "Sidecar-Service" "${LOG_DIR}/sidecar.pid"
stop_pid_file "Dominion-Java-LiveOps-Site" "${LOG_DIR}/java_live_ops.pid"
stop_pid_file "Dominion-Command-Core" "${LOG_DIR}/demo_app.pid"
stop_pid_file "Billing-Service" "${LOG_DIR}/billing_service.pid"
stop_pid_file "Dominion-Command-Center" "${LOG_DIR}/command_center.pid"
stop_pid_file "PHI-AskPHI-Widget" "${LOG_DIR}/widget_service.pid"
stop_pid_file "PHI-OAuth-Server" "${LOG_DIR}/oauth_server.pid"

cat > "${TELEMETRY_DIR}/system_status.json" <<JSON
{
  "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "active_services": 0,
  "generated_by": "phi_stop_all_systems.sh"
}
JSON

say "✅ PHI System Shutdown Complete!"
say "ℹ️  Shutdown log: ${STOP_LOG}"

exit 0
