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

REQUIRED_APPROVER="${PHI_BUDGET_APPROVER_REQUIRED:-Matthew Burbidge}"
APPROVAL_STATE="${PHI_BUDGET_INCREASE_APPROVAL:-}"
APPROVER="${PHI_BUDGET_INCREASE_APPROVER:-}"
APPROVAL_REF="${PHI_BUDGET_APPROVAL_REF:-}"
APPROVAL_AT="${PHI_BUDGET_APPROVAL_AT:-}"

is_approval_active() {
  case "${APPROVAL_STATE}" in
    1|YES|yes|APPROVED|approved|true|TRUE) ;;
    *) return 1 ;;
  esac
  [ "${APPROVER}" = "${REQUIRED_APPROVER}" ] || return 1
  [ -n "${APPROVAL_REF}" ] || return 1
  [ -n "${APPROVAL_AT}" ] || return 1
  return 0
}

print_status_json() {
  local lock_state="locked"
  if is_approval_active; then
    lock_state="approval_active"
  fi
  cat <<EOF
{
  "budget_increase_authority": "${lock_state}",
  "required_approver": "${REQUIRED_APPROVER}",
  "approval_state": "${APPROVAL_STATE}",
  "approver": "${APPROVER}",
  "approval_ref": "${APPROVAL_REF}",
  "approval_at": "${APPROVAL_AT}"
}
EOF
}

usage() {
  cat <<'EOF'
Usage: budget_authority_guard.sh [status|assert-locked|require-approval]

status            Print current budget authority status as JSON.
assert-locked     Exit 0 only when budget increase is locked.
require-approval  Exit 0 only when explicit Matthew approval is active.
EOF
}

case "${1:-status}" in
  status)
    print_status_json
    ;;
  assert-locked)
    if is_approval_active; then
      exit 1
    fi
    exit 0
    ;;
  require-approval)
    if is_approval_active; then
      exit 0
    fi
    exit 1
    ;;
  -h|--help|help)
    usage
    ;;
  *)
    usage
    exit 1
    ;;
esac
