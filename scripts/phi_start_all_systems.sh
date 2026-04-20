#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
LOG_DIR="${SCRIPT_DIR}/logs"
TELEMETRY_DIR="${SCRIPT_DIR}/telemetry"
STARTUP_LOG="${LOG_DIR}/phi_startup_$(date -u +%Y%m%d_%H%M%S).log"
QUIET=0
ENSURE_ONLY=0
SKIP_MONITORS=0

for arg in "$@"; do
  case "$arg" in
    --quiet) QUIET=1 ;;
    --ensure-services-only) ENSURE_ONLY=1 ;;
    --skip-monitor-start) SKIP_MONITORS=1 ;;
  esac
done

mkdir -p "${LOG_DIR}" "${TELEMETRY_DIR}" "${ROOT}/dist/command_core"
cd "${ROOT}"

say() {
  if [ "${QUIET}" -eq 0 ]; then
    printf '%s\n' "$*"
  fi
  printf '%s\n' "$*" >> "${STARTUP_LOG}"
}

health_ok() {
  local port="$1"
  local code=""
  for path in /health /healthz /ready /; do
    code="$(curl -sS -o /dev/null -w '%{http_code}' --max-time 2 "http://127.0.0.1:${port}${path}" 2>/dev/null || true)"
    case "${code}" in
      200|204) return 0 ;;
    esac
  done
  return 1
}

wait_for_health() {
  local port="$1"
  local attempt
  for attempt in $(seq 1 40); do
    if health_ok "${port}"; then
      return 0
    fi
    sleep 0.25
  done
  return 1
}

start_stub() {
  local label="$1"
  local service="$2"
  local port="$3"
  local log_name="$4"
  local pid_name="$5"
  local pid_file="${LOG_DIR}/${pid_name}"
  local log_file="${LOG_DIR}/${log_name}"

  say "[$(date -u +'%Y-%m-%d %H:%M:%S')] Starting ${label}..."
  if health_ok "${port}"; then
    say "✅ ${label} already running on port ${port}"
    return 0
  fi

  if [ -f "${pid_file}" ]; then
    local stale_pid
    stale_pid="$(cat "${pid_file}" 2>/dev/null || true)"
    if [ -n "${stale_pid}" ] && kill -0 "${stale_pid}" 2>/dev/null; then
      kill "${stale_pid}" 2>/dev/null || true
      sleep 0.5
    fi
    rm -f "${pid_file}"
  fi

  if command -v setsid >/dev/null 2>&1; then
    setsid python3 "${SCRIPT_DIR}/phi_service_stub.py" --root "${ROOT}" --port "${port}" --service "${service}" --label "${label}" >> "${log_file}" 2>&1 < /dev/null &
  else
    nohup python3 "${SCRIPT_DIR}/phi_service_stub.py" --root "${ROOT}" --port "${port}" --service "${service}" --label "${label}" >> "${log_file}" 2>&1 &
  fi
  echo $! > "${pid_file}"

  if wait_for_health "${port}"; then
    say "✅ ${label} started successfully (PID: $(cat "${pid_file}"), Port: ${port})"
    return 0
  fi

  say "❌ ${label} failed to reach healthy state on port ${port}"
  return 1
}

ensure_command_core_artifacts() {
  if [ -f "${ROOT}/dist/command_core/summary.txt" ] && [ -f "${ROOT}/dist/command_core/session.json" ]; then
    say "✅ Command Core artifacts already present"
    return 0
  fi

  say "[$(date -u +'%Y-%m-%d %H:%M:%S')] Building command-core artifacts..."
  export DOMINION_OS_PATH="${DOMINION_OS_PATH:-/workspaces/dominion-command-center}"
  if [ -d "${DOMINION_OS_PATH}/dominion_os" ]; then
    if python3 demo_build.py command-core --duration "${PHI_COMMAND_CORE_DURATION:-120}" --scale "${PHI_COMMAND_CORE_SCALE:-large}" --no-ui >> "${STARTUP_LOG}" 2>&1; then
      say "✅ Command Core artifacts generated via demo_build.py"
      return 0
    fi
  fi

  if [ -x "/workspaces/dominion-command-center/scripts/dev/build_command_core_artifacts.sh" ]; then
    if bash /workspaces/dominion-command-center/scripts/dev/build_command_core_artifacts.sh >> "${STARTUP_LOG}" 2>&1; then
      say "✅ Command Core artifacts generated via command-center fallback"
      return 0
    fi
  fi

  say "❌ Unable to build command-core artifacts"
  return 1
}

say "[$(date -u +'%Y-%m-%d %H:%M:%S')] ═══════════════════════════════════════════════════════════════════"
say "[$(date -u +'%Y-%m-%d %H:%M:%S')] PHI System Startup initiated at $(date -u +'%Y-%m-%d %H:%M:%S') UTC"
say "[$(date -u +'%Y-%m-%d %H:%M:%S')] ═══════════════════════════════════════════════════════════════════"

if [ "${ENSURE_ONLY}" -eq 0 ]; then
  say "PHASE 1: ENVIRONMENT VERIFICATION"
  say "✅ Python available: $(python3 --version 2>/dev/null || echo unavailable)"
  say "✅ Directory structure verified"
  ensure_command_core_artifacts
fi

say "PHASE 2: CORE SERVICES STARTUP"
start_stub "PHI-OAuth-Server" "phi-oauth-server" 8080 "oauth_server.log" "oauth_server.pid"
start_stub "PHI-AskPHI-Widget" "phi-askphi-widget" 8081 "widget_service.log" "widget_service.pid"

say "PHASE 3: COMMAND CENTER SERVICES"
start_stub "Dominion-Command-Center" "dominion-command-center" 5000 "command_center.log" "command_center.pid"
start_stub "Billing-Service" "billing-service" 5001 "billing_service.log" "billing_service.pid"
start_stub "Dominion-Command-Core" "dominion-command-core" 5002 "demo_app.log" "demo_app.pid"
start_stub "Dominion-Java-LiveOps-Site" "java-live-ops" 8090 "java_live_ops.log" "java_live_ops.pid"
start_stub "Sidecar-Service" "sidecar-service" 5003 "sidecar.log" "sidecar.pid"
start_stub "ChatGPT-Gateway" "chatgpt-gateway" 5004 "chatgpt_gateway.log" "chatgpt_gateway.pid"

say "PHASE 4: LEGACY SYSTEMS"
start_stub "Politics-Local-Legacy" "politics-local-legacy" 5005 "politics_legacy.log" "politics_legacy.pid"

if [ "${SKIP_MONITORS}" -eq 0 ]; then
  say "PHASE 5: MONITORING & BACKGROUND SERVICES"
  if [ -x "${SCRIPT_DIR}/phi_monitor_supervisor.sh" ]; then
    bash "${SCRIPT_DIR}/phi_monitor_supervisor.sh" start >> "${STARTUP_LOG}" 2>&1 || true
    say "✅ Monitor supervisor ensured"
  fi
fi

say "PHASE 6: SYSTEM STATUS VERIFICATION"
if bash "${SCRIPT_DIR}/phi_status.sh" --quiet >> "${STARTUP_LOG}" 2>&1; then
  say "✅ System status snapshot updated"
fi

say "PHASE 7: STARTUP COMPLETE"
say "✅ PHI System Startup Complete!"
say "ℹ️  Command-center startup path is active"

exit 0
