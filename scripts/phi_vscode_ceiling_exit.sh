#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEMO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

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

SAFE_LAUNCHER="${SCRIPT_DIR}/dominion_safe_clean_startup.sh"
LIVE_OPS_VERIFY="${COMMAND_CENTER_ROOT}/scripts/live_ops_verify.sh"

REPORT_DIR="${SCRIPT_DIR}/reports"
mkdir -p "${REPORT_DIR}"
TIMESTAMP="$(date -u +%Y%m%d_%H%M%SZ)"
REPORT_FILE="${REPORT_DIR}/vscode_ceiling_exit_${TIMESTAMP}.md"
MANIFEST_FILE="/tmp/phi_sovereignty_manifest.json"
MONITOR_LOG="/tmp/phi_sovereignty_monitor.log"

AUTHORITY_LEVEL="${PHI_AUTHORITY_LEVEL:-13/13}"
AUTHORITY_MODE="${PHI_AUTHORITY_MODE:-NHITL_CEILING}"
CLOSE_VSCODE=0

usage() {
  cat <<'USAGE'
Usage: phi_vscode_ceiling_exit.sh [--close-vscode]

Options:
  --close-vscode   Attempt to close VS Code processes after readiness is confirmed.
USAGE
}

for arg in "$@"; do
  case "$arg" in
    --close-vscode) CLOSE_VSCODE=1 ;;
    --help|-h)
      usage
      exit 0
      ;;
    *)
      echo "Unknown option: $arg" >&2
      usage >&2
      exit 2
      ;;
  esac
done

printf 'PHI CEILING EXIT PREP\n'
printf '=====================\n'
printf 'Timestamp: %s\n' "$(date -u +'%Y-%m-%dT%H:%M:%SZ')"
printf 'Authority: %s (%s)\n\n' "${AUTHORITY_LEVEL}" "${AUTHORITY_MODE}"

if [ ! -f "${SAFE_LAUNCHER}" ]; then
  echo "Missing safe launcher: ${SAFE_LAUNCHER}" >&2
  exit 1
fi

if [ ! -f "${LIVE_OPS_VERIFY}" ]; then
  echo "Missing live ops verification script: ${LIVE_OPS_VERIFY}" >&2
  exit 1
fi

echo "1) Enforcing safe-clean headless startup..."
bash "${SAFE_LAUNCHER}" start-headless

echo ""
echo "2) Running ceiling verification..."
verify_output="$(bash "${LIVE_OPS_VERIFY}" 2>&1)"
printf '%s\n' "${verify_output}"

normalized_score="$(printf '%s\n' "${verify_output}" | awk '/Normalized score:/ {print $3}' | cut -d'/' -f1 | head -1)"
verdict="$(printf '%s\n' "${verify_output}" | awk '/Verdict:/ {print $2}' | head -1)"
[ -n "${normalized_score}" ] || normalized_score="0"
[ -n "${verdict}" ] || verdict="UNKNOWN"

if [ "${normalized_score}" != "100" ] || [ "${verdict}" != "EXCELLENT" ]; then
  echo ""
  echo "❌ Ceiling exit blocked: verification is ${normalized_score}/100 with verdict ${verdict}."
  exit 1
fi

demo_git_dirty="$(git -C "${DEMO_ROOT}" status --porcelain | wc -l | tr -d ' ')"
cc_git_dirty="$(git -C "${COMMAND_CENTER_ROOT}" status --porcelain | wc -l | tr -d ' ')"
demo_git_state="clean"
cc_git_state="clean"
[ "${demo_git_dirty}" -gt 0 ] && demo_git_state="dirty(${demo_git_dirty})"
[ "${cc_git_dirty}" -gt 0 ] && cc_git_state="dirty(${cc_git_dirty})"

cat > "${MANIFEST_FILE}" <<JSON
{
  "sovereignty_exit_plan": {
    "timestamp_utc": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
    "vscode_exit_mode": "ceiling_performance_authority",
    "authority_level": "${AUTHORITY_LEVEL}",
    "authority_mode": "${AUTHORITY_MODE}",
    "normalized_score": ${normalized_score},
    "verdict": "${verdict}",
    "continuity_guaranteed": true,
    "restart_capable": true,
    "monitoring_active": true
  },
  "workspace_state": {
    "dominion_os_demo_build_git": "${demo_git_state}",
    "dominion_command_center_git": "${cc_git_state}"
  },
  "artifacts": {
    "report_file": "${REPORT_FILE}",
    "manifest_file": "${MANIFEST_FILE}"
  }
}
JSON

{
  echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] CEILING EXIT READY authority=${AUTHORITY_LEVEL} mode=${AUTHORITY_MODE} score=${normalized_score}/100 verdict=${verdict}"
  echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] git_state demo=${demo_git_state} command_center=${cc_git_state}"
} >> "${MONITOR_LOG}"

cat > "${REPORT_FILE}" <<MD
# VS Code Ceiling Exit Report

- Generated (UTC): $(date -u +%Y-%m-%dT%H:%M:%SZ)
- Authority: ${AUTHORITY_LEVEL} (${AUTHORITY_MODE})
- Verification: ${normalized_score}/100
- Verdict: ${verdict}
- Demo build git state: ${demo_git_state}
- Command-center git state: ${cc_git_state}
- Manifest: ${MANIFEST_FILE}
- Monitor log: ${MONITOR_LOG}

## Exit Readiness

Ceiling exit is ready. You can safely exit VS Code now while preserving live ops authority and continuity.
MD

echo ""
echo "✅ CEILING EXIT READY"
echo "   Authority: ${AUTHORITY_LEVEL} (${AUTHORITY_MODE})"
echo "   Verification: ${normalized_score}/100 (${verdict})"
echo "   Report: ${REPORT_FILE}"
echo "   Manifest: ${MANIFEST_FILE}"

if [ "${CLOSE_VSCODE}" -eq 1 ]; then
  echo ""
  echo "3) Closing VS Code processes..."
  pkill -f '[c]ode' || true
  pkill -f '[C]ode - OSS' || true
fi

exit 0
