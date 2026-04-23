#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FULL_STACK_SCRIPT="${SCRIPT_DIR}/dominion_command_center_full_stack.sh"

resolve_existing_dir() {
  local candidate=""
  for candidate in "$@"; do
    [ -n "${candidate}" ] || continue
    if [ -d "${candidate}" ]; then
      printf '%s\n' "${candidate}"
      return 0
    fi
  done
  return 1
}

COMMAND_CENTER_ROOT="$(
  resolve_existing_dir \
    "${DOMINION_COMMAND_CENTER_DIR:-}" \
    "/workspaces/dominion-command-center" \
    "/mnt/d/workspaces/dominion-command-center" \
    "/mnt/c/workspaces/dominion-command-center" \
  || echo "/workspaces/dominion-command-center"
)"

LIVE_OPS_STOP="${COMMAND_CENTER_ROOT}/scripts/live_ops_stop.sh"
LIVE_OPS_VERIFY="${COMMAND_CENTER_ROOT}/scripts/live_ops_verify.sh"
PHI_STATUS="${SCRIPT_DIR}/phi_status.sh"
PHI_STOP="${SCRIPT_DIR}/phi_stop_all_systems.sh"

usage() {
  cat <<'USAGE'
Usage: dominion_safe_clean_startup.sh <command>

Commands:
  start          Strict safe-clean startup (full checks).
  start-headless Strict safe-clean startup, skip VS Code checks (for services/boot).
  verify         Verify live ops health.
  status         Print PHI runtime status snapshot.
  stop           Stop live ops stack.
  restart        Stop then start-headless.
  plan           Print full-stack startup plan.
USAGE
}

run_start() {
  local -a args=(--safe-clean)
  if [ "${DOMINION_SAFE_CLEAN_NO_LEARN:-0}" = "1" ]; then
    args+=(--no-learn)
  fi
  if [ "${DOMINION_SAFE_CLEAN_SKIP_VSCODE:-0}" = "1" ]; then
    args+=(--skip-vscode)
  fi
  bash "${FULL_STACK_SCRIPT}" "${args[@]}"
}

run_start_headless() {
  DOMINION_SAFE_CLEAN_SKIP_VSCODE=1 run_start
}

run_verify() {
  if [ -f "${LIVE_OPS_VERIFY}" ]; then
    bash "${LIVE_OPS_VERIFY}"
    return 0
  fi
  bash "${FULL_STACK_SCRIPT}" --verify-only --skip-vscode
}

run_status() {
  if [ -f "${PHI_STATUS}" ]; then
    bash "${PHI_STATUS}"
    return 0
  fi
  run_verify
}

run_stop() {
  if [ -f "${LIVE_OPS_STOP}" ]; then
    bash "${LIVE_OPS_STOP}"
    return 0
  fi
  if [ -f "${PHI_STOP}" ]; then
    bash "${PHI_STOP}"
    return 0
  fi
  echo "No stop script found." >&2
  return 1
}

case "${1:-start}" in
  start)
    run_start
    ;;
  start-headless)
    run_start_headless
    ;;
  verify)
    run_verify
    ;;
  status)
    run_status
    ;;
  stop)
    run_stop
    ;;
  restart)
    run_stop || true
    sleep 2
    run_start_headless
    ;;
  plan)
    bash "${FULL_STACK_SCRIPT}" --plan-only
    ;;
  *)
    usage >&2
    exit 2
    ;;
esac
