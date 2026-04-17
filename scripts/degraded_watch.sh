#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TELEMETRY_DIR="${SCRIPT_DIR}/telemetry"
LOG_FILE="${TELEMETRY_DIR}/degraded_watch.log"
STATE_FILE="${TELEMETRY_DIR}/degraded_watch.state"
LOCK_FILE="${TELEMETRY_DIR}/degraded_watch.lock"

WATCH_INTERVAL="${PHI_DEGRADED_WATCH_INTERVAL:-30}"

mkdir -p "${TELEMETRY_DIR}"

with_lock_or_exit() {
  exec 9>"${LOCK_FILE}"
  if command -v flock >/dev/null 2>&1; then
    if ! flock -n 9; then
      exit 0
    fi
  fi
}

service_http_ok() {
  local base_url="$1"
  local path code
  for path in /health /healthz /ready /; do
    code="$(curl -sS -o /dev/null -w '%{http_code}' --max-time 4 "${base_url}${path}" 2>/dev/null || echo 000)"
    case "${code}" in
      200|204) return 0 ;;
      *) ;;
    esac
  done
  return 1
}

monitor_stack_healthy() {
  local status
  status="$("${SCRIPT_DIR}/phi_monitor_supervisor.sh" status 2>/dev/null || true)"
  [[ "${status}" == *"supervisor=running("* ]] \
    && [[ "${status}" == *"continuous_monitor=running("* ]] \
    && [[ "${status}" == *"sovereign_monitor=running("* ]] \
    && [[ "${status}" == *"auto_audit=running("* ]]
}

emit_alert_if_new() {
  local message="$1"
  local signature
  signature="$(printf '%s' "${message}" | sha256sum | awk '{print $1}')"
  local previous=""
  if [ -f "${STATE_FILE}" ]; then
    previous="$(cat "${STATE_FILE}" 2>/dev/null || true)"
  fi
  if [ "${signature}" != "${previous}" ]; then
    printf '[%s] ALERT %s\n' "$(date -u +'%Y-%m-%dT%H:%M:%SZ')" "${message}" >> "${LOG_FILE}"
    echo "${signature}" > "${STATE_FILE}"
  fi
}

clear_alert_state() {
  rm -f "${STATE_FILE}"
}

main_loop() {
  local degraded=()
  local urls=(
    "http://localhost:5000|command-center"
    "http://localhost:5001|billing"
    "http://localhost:5002|command-core"
    "http://localhost:5003|sidecar"
    "http://localhost:5004|chatgpt-gateway"
    "http://localhost:8080|oauth"
    "http://localhost:8081|askphi-widget"
    "http://localhost:8090|java-live-ops"
  )

  while true; do
    degraded=()

    local entry url name
    for entry in "${urls[@]}"; do
      IFS='|' read -r url name <<< "${entry}"
      if ! service_http_ok "${url}"; then
        degraded+=("service:${name}")
      fi
    done

    if ! monitor_stack_healthy; then
      degraded+=("monitor-stack")
    fi

    if [ "${#degraded[@]}" -gt 0 ]; then
      emit_alert_if_new "$(IFS=,; echo "${degraded[*]}")"
    else
      clear_alert_state
    fi

    sleep "${WATCH_INTERVAL}"
  done
}

with_lock_or_exit
main_loop
