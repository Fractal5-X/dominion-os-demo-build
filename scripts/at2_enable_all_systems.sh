#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
SYNC_ENV_FILE="${PHI_SYNC_ENV_FILE:-${SCRIPT_DIR}/live_ops_sync.env}"
if [ -f "${SYNC_ENV_FILE}" ]; then
  set -a
  # shellcheck disable=SC1090
  . "${SYNC_ENV_FILE}"
  set +a
fi

REPORT_DIR="${SCRIPT_DIR}/reports"
TELEMETRY_DIR="${SCRIPT_DIR}/telemetry"
TS="$(date -u +%Y%m%d_%H%M%SZ)"
REPORT_FILE="${REPORT_DIR}/at2_solution_execution_${TS}.md"
STATUS_FILE="${TELEMETRY_DIR}/at2_solution_status.json"
LOG_FILE="${REPORT_DIR}/at2_solution_execution_${TS}.log"

INTERACTIVE=0
RUN_COMPOSE=1

mkdir -p "${REPORT_DIR}" "${TELEMETRY_DIR}"

usage() {
  cat <<'EOF'
Usage: at2_enable_all_systems.sh [options]

Options:
  --interactive     Run interactive auth flows when a TTY is available.
  --skip-compose    Do not attempt compose startup even when Docker runtime is healthy.
  --help            Show this help.

This script applies all non-interactive local repairs and records exact host/account
gates for the remaining AT2 enablement work: gcloud auth, Docker Hub auth,
nested-container runtime privileges, NVIDIA/CUDA exposure, Docker Scout, MCP compose,
and local live-ops verification.
EOF
}

for arg in "$@"; do
  case "${arg}" in
    --interactive) INTERACTIVE=1 ;;
    --skip-compose) RUN_COMPOSE=0 ;;
    --help|-h)
      usage
      exit 0
      ;;
    *)
      echo "Unknown option: ${arg}" >&2
      usage >&2
      exit 2
      ;;
  esac
done

log() {
  printf '[%s] %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$*" | tee -a "${LOG_FILE}"
}

have() {
  command -v "$1" >/dev/null 2>&1
}

is_tty() {
  [ -t 0 ] && [ -t 1 ]
}

json_escape() {
  python3 -c 'import json,sys; print(json.dumps(sys.stdin.read()))'
}

docker_auth_configured() {
  local cfg="${HOME}/.docker/config.json"
  [ -f "${cfg}" ] || return 1
  python3 - "${cfg}" <<'PY'
import json
import sys
from pathlib import Path
try:
    data = json.loads(Path(sys.argv[1]).read_text())
except Exception:
    sys.exit(1)
if data.get("credsStore") or data.get("credHelpers") or data.get("auths"):
    sys.exit(0)
sys.exit(1)
PY
}

docker_runtime_healthy() {
  unshare -m true >/dev/null 2>&1 || return 1
  docker create --name at2-runtime-check --entrypoint /nope dominion/empty:latest >/tmp/at2-docker-create.out 2>&1 || return 1
  docker rm -f at2-runtime-check >/dev/null 2>&1 || true
  return 0
}

install_docker_scout_if_needed() {
  if docker scout version >/dev/null 2>&1; then
    return 0
  fi
  log "Docker Scout missing; installing official CLI plugin."
  curl -fsSL https://raw.githubusercontent.com/docker/scout-cli/main/install.sh -o /tmp/install-scout.sh
  sh /tmp/install-scout.sh >> "${LOG_FILE}" 2>&1
}

write_header() {
  cat > "${REPORT_FILE}" <<EOF
# AT2 Full-System Solution Execution

- Timestamp (UTC): $(date -u +%Y-%m-%dT%H:%M:%SZ)
- Root: ${ROOT}
- Mode: $( [ "${INTERACTIVE}" -eq 1 ] && echo interactive || echo non-interactive )

EOF
}

append_report() {
  printf '%s\n' "$*" >> "${REPORT_FILE}"
}

live_ops_status="FAIL"
monitor_status="unknown"
live_ops_detail=""
verify_live_ops() {
  log "Verifying live local ops."
  local out rc
  out="$(bash /workspaces/dominion-command-center/scripts/live_ops_verify.sh 2>&1)" && rc=0 || rc=$?
  printf '%s\n' "${out}" >> "${LOG_FILE}"
  monitor_status="$(bash "${SCRIPT_DIR}/phi_monitor_supervisor.sh" status 2>/dev/null || true)"
  if [ "${rc}" -eq 0 ]; then
    live_ops_status="PASS"
    live_ops_detail="Command-center verification passed"
  else
    live_ops_detail="Command-center verification failed rc=${rc}"
  fi
}

docker_api_status="FAIL"
docker_runtime_status="FAIL"
docker_auth_status="FAIL"
docker_scout_status="FAIL"
docker_detail=""
repair_docker() {
  log "Repairing and tuning Docker."
  docker context rm desktop >> "${LOG_FILE}" 2>&1 || true

  if docker info >/dev/null 2>&1; then
    docker_api_status="PASS"
  fi

  bash "${SCRIPT_DIR}/docker_repair_optimal.sh" >> "${LOG_FILE}" 2>&1 || true

  docker system prune -f >> "${LOG_FILE}" 2>&1 || true
  docker volume prune -f >> "${LOG_FILE}" 2>&1 || true
  docker builder prune -f >> "${LOG_FILE}" 2>&1 || true

  if docker_auth_configured; then
    docker_auth_status="PASS"
  elif [ "${INTERACTIVE}" -eq 1 ] && is_tty; then
    log "Docker Hub auth missing; launching docker login."
    docker login
    docker_auth_configured && docker_auth_status="PASS" || docker_auth_status="FAIL"
  fi

  install_docker_scout_if_needed || true
  if docker scout version >/dev/null 2>&1; then
    docker_scout_status="PASS"
  fi

  if docker_runtime_healthy; then
    docker_runtime_status="PASS"
  else
    docker_runtime_status="FAIL"
  fi

  docker_detail="$(docker version --format 'client={{.Client.Version}} server={{.Server.Version}}' 2>/dev/null || echo unavailable)"
}

compose_status="SKIPPED"
compose_detail=""
start_compose_if_possible() {
  if [ "${RUN_COMPOSE}" -ne 1 ]; then
    compose_status="SKIPPED"
    compose_detail="compose startup skipped by option"
    return 0
  fi
  if [ "${docker_runtime_status}" != "PASS" ]; then
    compose_status="BLOCKED"
    compose_detail="Docker runtime cannot create containers in this host"
    return 0
  fi

  log "Starting non-conflicting compose services."
  if docker compose -p dominion-core -f "${ROOT}/docker-compose.yml" up -d postgres redis >> "${LOG_FILE}" 2>&1; then
    compose_status="PASS"
    compose_detail="core postgres/redis compose services started"
  else
    compose_status="FAIL"
    compose_detail="core compose startup failed; see log"
  fi

  if docker compose -p dominion-mcp -f "${ROOT}/docker-compose-mcp.yml" up -d >> "${LOG_FILE}" 2>&1; then
    compose_detail="${compose_detail}; MCP compose attempted"
  else
    compose_detail="${compose_detail}; MCP compose failed or port-conflicted"
  fi
}

gcloud_status="FAIL"
gcloud_detail=""
repair_gcloud() {
  log "Checking gcloud auth."
  if gcloud auth print-access-token --quiet >/tmp/at2-gcloud-token.out 2>&1; then
    gcloud_status="PASS"
    gcloud_detail="token refresh passed"
    return 0
  fi

  gcloud_detail="$(sed -n '1,12p' /tmp/at2-gcloud-token.out | tr '\n' ' ')"
  if [ "${INTERACTIVE}" -eq 1 ] && is_tty; then
    log "gcloud token refresh failed; launching gcloud auth login."
    gcloud auth login
    if gcloud auth print-access-token --quiet >/tmp/at2-gcloud-token.out 2>&1; then
      gcloud_status="PASS"
      gcloud_detail="token refresh passed after interactive login"
    else
      gcloud_status="FAIL"
      gcloud_detail="$(sed -n '1,12p' /tmp/at2-gcloud-token.out | tr '\n' ' ')"
    fi
  fi
}

nvidia_status="FAIL"
nvidia_detail=""
check_nvidia() {
  log "Checking NVIDIA/CUDA exposure."
  local parts=()
  if nvidia-smi >/tmp/at2-nvidia-smi.out 2>&1; then
    parts+=("nvidia-smi=PASS")
  else
    parts+=("nvidia-smi=missing")
  fi
  if nvcc --version >/tmp/at2-nvcc.out 2>&1; then
    parts+=("nvcc=PASS")
  else
    parts+=("nvcc=missing")
  fi
  if ls /dev/nvidia* >/tmp/at2-nvidia-devices.out 2>&1; then
    parts+=("devices=PASS")
  else
    parts+=("devices=missing")
  fi
  nvidia_detail="${parts[*]}"
  if printf '%s' "${nvidia_detail}" | grep -q 'nvidia-smi=PASS' && printf '%s' "${nvidia_detail}" | grep -q 'devices=PASS'; then
    nvidia_status="PASS"
  fi
}

write_outputs() {
  append_report "## Results"
  append_report "- Live ops: ${live_ops_status} (${live_ops_detail})"
  append_report "- Monitor stack:"
  append_report '```'
  append_report "${monitor_status}"
  append_report '```'
  append_report "- Docker API: ${docker_api_status}"
  append_report "- Docker runtime: ${docker_runtime_status}"
  append_report "- Docker auth: ${docker_auth_status}"
  append_report "- Docker Scout: ${docker_scout_status}"
  append_report "- Docker detail: ${docker_detail}"
  append_report "- Compose/MCP containers: ${compose_status} (${compose_detail})"
  append_report "- gcloud auth: ${gcloud_status} (${gcloud_detail})"
  append_report "- NVIDIA/CUDA: ${nvidia_status} (${nvidia_detail})"
  append_report ""
  append_report "## Host Actions Still Required"
  if [ "${docker_runtime_status}" != "PASS" ]; then
    append_report "- Enable nested container execution: run this workspace with privileged Docker support, or mount a working host Docker socket that can create containers."
  fi
  if [ "${docker_auth_status}" != "PASS" ]; then
    append_report "- Run \`docker login\` from an interactive terminal to remove Docker Hub pull limits and enable Docker Scout CVE/policy scans."
  fi
  if [ "${gcloud_status}" != "PASS" ]; then
    append_report "- Run \`gcloud auth login\` from an interactive terminal, then rerun this script."
  fi
  if [ "${nvidia_status}" != "PASS" ]; then
    append_report "- Expose AT2 NVIDIA devices to this runtime and install NVIDIA Container Toolkit/CUDA on the host path used for Docker workloads."
  fi
  append_report ""
  append_report "## Verification Commands"
  append_report "- \`bash /workspaces/dominion-command-center/scripts/live_ops_verify.sh\`"
  append_report "- \`bash ${SCRIPT_DIR}/docker_repair_optimal.sh\`"
  append_report "- \`gcloud auth print-access-token --quiet\`"
  append_report "- \`nvidia-smi\`"

  local live_json monitor_json docker_detail_json compose_detail_json gcloud_detail_json nvidia_detail_json
  live_json="$(printf '%s' "${live_ops_detail}" | json_escape)"
  monitor_json="$(printf '%s' "${monitor_status}" | json_escape)"
  docker_detail_json="$(printf '%s' "${docker_detail}" | json_escape)"
  compose_detail_json="$(printf '%s' "${compose_detail}" | json_escape)"
  gcloud_detail_json="$(printf '%s' "${gcloud_detail}" | json_escape)"
  nvidia_detail_json="$(printf '%s' "${nvidia_detail}" | json_escape)"

  cat > "${STATUS_FILE}" <<EOF
{
  "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "report_path": "${REPORT_FILE}",
  "log_path": "${LOG_FILE}",
  "checks": {
    "live_ops": "${live_ops_status}",
    "docker_api": "${docker_api_status}",
    "docker_runtime": "${docker_runtime_status}",
    "docker_auth": "${docker_auth_status}",
    "docker_scout": "${docker_scout_status}",
    "compose_mcp": "${compose_status}",
    "gcloud_auth": "${gcloud_status}",
    "nvidia_cuda": "${nvidia_status}"
  },
  "details": {
    "live_ops": ${live_json},
    "monitor_status": ${monitor_json},
    "docker": ${docker_detail_json},
    "compose": ${compose_detail_json},
    "gcloud": ${gcloud_detail_json},
    "nvidia": ${nvidia_detail_json}
  }
}
EOF
}

main() {
  write_header
  verify_live_ops
  repair_docker
  start_compose_if_possible
  repair_gcloud
  check_nvidia
  write_outputs
  log "AT2 solution execution complete: ${REPORT_FILE}"
  printf '%s\n' "${REPORT_FILE}"
}

main "$@"
