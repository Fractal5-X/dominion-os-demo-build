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
REPORT_FILE="${REPORT_DIR}/at2_host_max_mode_certification_${TS}.md"
STATUS_FILE="${TELEMETRY_DIR}/at2_host_max_mode_certification.json"
LOG_FILE="${REPORT_DIR}/at2_host_max_mode_certification_${TS}.log"

mkdir -p "${REPORT_DIR}" "${TELEMETRY_DIR}"

log() {
  printf '[%s] %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$*" | tee -a "${LOG_FILE}" >/dev/null
}

have() {
  command -v "$1" >/dev/null 2>&1
}

json_string() {
  python3 -c 'import json,sys; print(json.dumps(sys.stdin.read()))'
}

to_unix_path() {
  local input="${1:-}"
  local drive rest
  if [[ "${input}" =~ ^([A-Za-z]):\\(.*)$ ]]; then
    drive="$(printf '%s' "${BASH_REMATCH[1]}" | tr '[:upper:]' '[:lower:]')"
    rest="${BASH_REMATCH[2]//\\//}"
    printf '/mnt/%s/%s\n' "${drive}" "${rest}"
    return 0
  fi
  printf '%s\n' "${input}"
}

status_of() {
  local pass="$1"
  if [ "${pass}" -eq 0 ]; then
    printf 'PASS\n'
  else
    printf 'FAIL\n'
  fi
}

docker_runtime_check() {
  docker rm -f at2-runtime-check >/dev/null 2>&1 || true
  unshare -m true >/tmp/at2-unshare.out 2>&1 || return 2
  docker create --name at2-runtime-check --entrypoint /nope dominion/empty:latest >/tmp/at2-docker-create.out 2>&1 || return 3
  docker rm -f at2-runtime-check >/dev/null 2>&1 || true
}

d_path="$(to_unix_path "${DOMINION_WORKSPACE_DIR:-D:\\workspaces\\dominion-os-demo-build}")"
cc_path="$(to_unix_path "${DOMINION_COMMAND_CENTER_DIR:-D:\\workspaces\\dominion-command-center}")"
mirror_path="$(to_unix_path "${PHI_SYNC_LOCAL_MIRROR_PATH:-D:\\workspaces\\dominion-os-demo-build-live}")"
mirror_fallback="$(to_unix_path "${PHI_SYNC_LOCAL_MIRROR_FALLBACK_PATH:-/workspaces/dominion-os-demo-build-live}")"

log "AT2 host max-mode certification started."

live_ops_out="$(bash /workspaces/dominion-command-center/scripts/live_ops_verify.sh 2>&1)" && live_ops_rc=0 || live_ops_rc=$?
docker_info_out="$(docker info --format 'server={{.ServerVersion}} containers={{.Containers}} running={{.ContainersRunning}} images={{.Images}}' 2>&1)" && docker_info_rc=0 || docker_info_rc=$?
docker_compose_out="$(docker compose version --short 2>&1)" && docker_compose_rc=0 || docker_compose_rc=$?
docker_scout_out="$(docker scout version 2>&1 | awk '/version:/ {print $2; exit}')" && docker_scout_rc=0 || docker_scout_rc=$?
docker_runtime_check && docker_runtime_rc=0 || docker_runtime_rc=$?
gcloud_out="$(gcloud auth print-access-token --quiet >/tmp/at2-gcloud-token.out 2>&1 && gcloud config get-value project 2>/dev/null)" && gcloud_rc=0 || gcloud_rc=$?
nvidia_smi_out="$(nvidia-smi --query-gpu=name,driver_version,memory.total --format=csv,noheader 2>&1)" && nvidia_smi_rc=0 || nvidia_smi_rc=$?
nvcc_out="$(nvcc --version 2>&1 | tail -n 1)" && nvcc_rc=0 || nvcc_rc=$?
cloud_run_ready_count="$(gcloud run services list --project "${PHI_PUBLIC_GCP_PROJECT:-dominion-core-prod}" --region "${PHI_PUBLIC_GCP_REGION:-us-central1}" --format=json 2>/dev/null | python3 -c 'import json,sys; data=json.load(sys.stdin); print(sum(1 for s in data if any(c.get("type")=="Ready" and c.get("status")=="True" for c in s.get("status",{}).get("conditions",[]))))' 2>/dev/null || echo 0)"
cloud_run_total_count="$(gcloud run services list --project "${PHI_PUBLIC_GCP_PROJECT:-dominion-core-prod}" --region "${PHI_PUBLIC_GCP_REGION:-us-central1}" --format='value(metadata.name)' 2>/dev/null | sed '/^$/d' | wc -l | tr -d ' ')"

d_mount_rc=1
[ -d "/mnt/d" ] && d_mount_rc=0
workspace_rc=1
[ -d "${d_path}" ] && workspace_rc=0
command_center_rc=1
[ -d "${cc_path}" ] && command_center_rc=0
mirror_rc=1
if [ -d "${mirror_path}" ] || [ -d "${mirror_fallback}" ]; then
  mirror_rc=0
fi
nvidia_devices_rc=1
find /dev -maxdepth 1 -name 'nvidia*' -print -quit 2>/dev/null | rg -q . && nvidia_devices_rc=0

overall="PASS"
for rc in "${live_ops_rc}" "${docker_info_rc}" "${docker_compose_rc}" "${docker_scout_rc}" "${docker_runtime_rc}" "${gcloud_rc}" "${nvidia_smi_rc}" "${nvidia_devices_rc}" "${d_mount_rc}"; do
  if [ "${rc}" -ne 0 ]; then
    overall="HOST_GATED"
  fi
done

cat > "${REPORT_FILE}" <<EOF
# AT2 Host Max-Mode Certification

Generated: $(date -u +%Y-%m-%dT%H:%M:%SZ)
Root: ${ROOT}
Verdict: ${overall}

## Required Max-Mode Checks

- Live ops verification: $(status_of "${live_ops_rc}")
- Docker API: $(status_of "${docker_info_rc}") (${docker_info_out})
- Docker Compose: $(status_of "${docker_compose_rc}") (${docker_compose_out})
- Docker Scout: $(status_of "${docker_scout_rc}") (${docker_scout_out})
- Docker nested runtime: $(status_of "${docker_runtime_rc}") (rc=${docker_runtime_rc})
- GCloud auth/project: $(status_of "${gcloud_rc}") (${gcloud_out})
- Cloud Run ready services: ${cloud_run_ready_count}/${cloud_run_total_count}
- D: mount exposed as /mnt/d: $(status_of "${d_mount_rc}")
- D workspace path: $(status_of "${workspace_rc}") (${d_path})
- D command-center path: $(status_of "${command_center_rc}") (${cc_path})
- Local mirror path: $(status_of "${mirror_rc}") (${mirror_path}; fallback ${mirror_fallback})
- NVIDIA SMI: $(status_of "${nvidia_smi_rc}") (${nvidia_smi_out})
- NVIDIA devices: $(status_of "${nvidia_devices_rc}")
- NVCC CUDA compiler: $(status_of "${nvcc_rc}") (${nvcc_out})

## Live Ops Output

\`\`\`
${live_ops_out}
\`\`\`

## If Verdict Is HOST_GATED

- Run this script on AT2/WSL with D: mounted at /mnt/d.
- Start Docker from the AT2 host or expose a working host Docker socket.
- If running inside a container, launch it with mount namespace privileges or use the host Docker daemon.
- Install and expose NVIDIA drivers, CUDA, and NVIDIA Container Toolkit before rerunning.
EOF

live_ops_json="$(printf '%s' "${live_ops_out}" | json_string)"
docker_info_json="$(printf '%s' "${docker_info_out}" | json_string)"
nvidia_json="$(printf '%s' "${nvidia_smi_out}" | json_string)"

cat > "${STATUS_FILE}" <<EOF
{
  "generated_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "verdict": "${overall}",
  "report_path": "${REPORT_FILE}",
  "log_path": "${LOG_FILE}",
  "checks": {
    "live_ops": "$(status_of "${live_ops_rc}")",
    "docker_api": "$(status_of "${docker_info_rc}")",
    "docker_compose": "$(status_of "${docker_compose_rc}")",
    "docker_scout": "$(status_of "${docker_scout_rc}")",
    "docker_nested_runtime": "$(status_of "${docker_runtime_rc}")",
    "gcloud_auth": "$(status_of "${gcloud_rc}")",
    "cloud_run_ready": "${cloud_run_ready_count}/${cloud_run_total_count}",
    "d_mount": "$(status_of "${d_mount_rc}")",
    "d_workspace": "$(status_of "${workspace_rc}")",
    "d_command_center": "$(status_of "${command_center_rc}")",
    "local_mirror": "$(status_of "${mirror_rc}")",
    "nvidia_smi": "$(status_of "${nvidia_smi_rc}")",
    "nvidia_devices": "$(status_of "${nvidia_devices_rc}")",
    "nvcc": "$(status_of "${nvcc_rc}")"
  },
  "details": {
    "live_ops": ${live_ops_json},
    "docker": ${docker_info_json},
    "nvidia": ${nvidia_json}
  }
}
EOF

log "AT2 host max-mode certification complete: ${REPORT_FILE}"
printf '%s\n' "${REPORT_FILE}"
