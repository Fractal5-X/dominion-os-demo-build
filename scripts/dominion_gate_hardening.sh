#!/usr/bin/env bash
set -uo pipefail

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
REPORT_FILE="${REPORT_DIR}/dominion_gate_hardening_${TS}.md"
STATUS_FILE="${TELEMETRY_DIR}/dominion_gate_hardening.json"
LOG_FILE="${REPORT_DIR}/dominion_gate_hardening_${TS}.log"
PROJECT="${PHI_PUBLIC_GCP_PROJECT:-dominion-core-prod}"
REGION="${PHI_PUBLIC_GCP_REGION:-us-central1}"

mkdir -p "${REPORT_DIR}" "${TELEMETRY_DIR}"

log() {
  printf '[%s] %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$*" | tee -a "${LOG_FILE}" >/dev/null
}

run_capture() {
  local name="$1"
  shift
  log "RUN ${name}: $*"
  "$@" >"${TELEMETRY_DIR}/gate_${name}.out" 2>&1
  local rc=$?
  log "DONE ${name}: rc=${rc}"
  return "${rc}"
}

status_of() {
  local rc="$1"
  if [ "${rc}" -eq 0 ]; then
    printf 'PASS\n'
  else
    printf 'FAIL\n'
  fi
}

json_string() {
  python3 -c 'import json,sys; print(json.dumps(sys.stdin.read()))'
}

required_apis=(
  run.googleapis.com
  artifactregistry.googleapis.com
  cloudbuild.googleapis.com
  secretmanager.googleapis.com
  storage.googleapis.com
  logging.googleapis.com
  monitoring.googleapis.com
  cloudresourcemanager.googleapis.com
  serviceusage.googleapis.com
  iam.googleapis.com
)

log "Dominion gate hardening started for ${PROJECT}/${REGION}."

run_capture bash_syntax bash -n \
  "${SCRIPT_DIR}/at2_host_max_mode_certify.sh" \
  "${SCRIPT_DIR}/at2_enable_all_systems.sh" \
  "${SCRIPT_DIR}/docker_repair_optimal.sh" \
  "${SCRIPT_DIR}/phi_intelligent_sync.sh" \
  "${SCRIPT_DIR}/dominion_gate_hardening.sh"
bash_syntax_rc=$?

run_capture live_ops bash /workspaces/dominion-command-center/scripts/live_ops_verify.sh
live_ops_rc=$?

run_capture docker_repair bash "${SCRIPT_DIR}/docker_repair_optimal.sh"
docker_repair_rc=$?

run_capture docker_scout docker scout version
docker_scout_rc=$?

run_capture docker_compose docker compose version
docker_compose_rc=$?

run_capture gcloud_token gcloud auth print-access-token --quiet
gcloud_token_rc=$?

if [ "${gcloud_token_rc}" -eq 0 ]; then
  run_capture gcp_labels gcloud alpha projects update "${PROJECT}" \
    --update-labels=environment=production,managed-by=dominion-live-ops \
    --format=json
  gcp_labels_rc=$?

  run_capture gcp_required_apis gcloud services enable "${required_apis[@]}" --project "${PROJECT}"
  gcp_required_apis_rc=$?

  run_capture gcp_project gcloud projects describe "${PROJECT}" --format=json
  gcp_project_rc=$?

  run_capture cloud_run_ready gcloud run services list --project "${PROJECT}" --region "${REGION}" --format=json
  cloud_run_rc=$?

  org_id="$(python3 - "${TELEMETRY_DIR}/gate_gcp_project.out" <<'PY'
import json, sys
try:
    data = json.load(open(sys.argv[1]))
    print(data.get("parent", {}).get("id", ""))
except Exception:
    print("")
PY
)"
  if [ -n "${org_id}" ]; then
    run_capture gcp_tag_keys gcloud resource-manager tags keys list --parent="organizations/${org_id}" --format=json
    gcp_tag_keys_rc=$?
    if [ "${gcp_tag_keys_rc}" -eq 0 ] && ! python3 - "${TELEMETRY_DIR}/gate_gcp_tag_keys.out" <<'PY'
import json, sys
data = json.load(open(sys.argv[1]))
raise SystemExit(0 if any(k.get("shortName") == "environment" or k.get("namespacedName", "").endswith("/environment") for k in data) else 1)
PY
    then
      run_capture gcp_tag_key_create gcloud resource-manager tags keys create environment \
        --parent="organizations/${org_id}" \
        --description="Project environment classification" \
        --format=json
      gcp_tag_key_create_rc=$?
    else
      gcp_tag_key_create_rc=0
    fi
  else
    gcp_tag_keys_rc=1
    gcp_tag_key_create_rc=1
  fi
else
  gcp_labels_rc=1
  gcp_required_apis_rc=1
  gcp_project_rc=1
  cloud_run_rc=1
  gcp_tag_keys_rc=1
  gcp_tag_key_create_rc=1
fi

run_capture at2_certify bash "${SCRIPT_DIR}/at2_host_max_mode_certify.sh"
at2_certify_rc=$?

PHI_SYNC_ENV_FILE=/dev/null \
PHI_SYNC_LOCAL_MIRROR_ENABLED=1 \
PHI_SYNC_LOCAL_MIRROR_PATH=/workspaces/dominion-os-demo-build-live \
PHI_SYNC_LOCAL_MIRROR_PATHS='scripts/telemetry scripts/reports dist/command_core reports' \
PHI_SYNC_LOCAL_MIRROR_EXCLUDES='.git/ logs/ scripts/logs/ .venv/ node_modules/' \
PHI_SYNC_LOCAL_MIRROR_MIN_INTERVAL_SECONDS=0 \
PHI_SYNC_GCS_ENABLED=1 \
PHI_SYNC_GCS_BUCKET="${PHI_SYNC_GCS_BUCKET:-dominion-core-prod-drydock-state}" \
PHI_SYNC_GCS_PREFIX="${PHI_SYNC_GCS_PREFIX:-dominion-live-ops/primary}" \
PHI_SYNC_GCS_INCLUDE_PATHS='scripts/telemetry scripts/reports dist/command_core reports' \
PHI_SYNC_GCS_MIN_INTERVAL_SECONDS=0 \
run_capture intelligent_sync bash "${SCRIPT_DIR}/phi_intelligent_sync.sh"
intelligent_sync_rc=$?

cloud_run_counts="$(
  python3 - "${TELEMETRY_DIR}/gate_cloud_run_ready.out" <<'PY'
import json, sys
try:
    data = json.load(open(sys.argv[1]))
except Exception:
    print("0/0")
    raise SystemExit
ready = sum(1 for service in data if any(c.get("type") == "Ready" and c.get("status") == "True" for c in service.get("status", {}).get("conditions", [])))
print(f"{ready}/{len(data)}")
PY
)"

source_zero_diff_rc=0
git -C "${ROOT}" diff --quiet || source_zero_diff_rc=1
git -C "${ROOT}" diff --cached --quiet || source_zero_diff_rc=1
dirty_count="$(git -C "${ROOT}" status --short | wc -l | tr -d ' ')"

host_gated=0
if [ -f "${TELEMETRY_DIR}/at2_host_max_mode_certification.json" ]; then
  host_gated="$(python3 - "${TELEMETRY_DIR}/at2_host_max_mode_certification.json" <<'PY'
import json, sys
data = json.load(open(sys.argv[1]))
checks = data.get("checks", {})
gates = ["docker_nested_runtime", "d_mount", "d_workspace", "d_command_center", "nvidia_smi", "nvidia_devices", "nvcc"]
print(sum(1 for gate in gates if checks.get(gate) != "PASS"))
PY
)"
fi

overall="PERFECT_OPS_HARDENED_WITH_EXTERNAL_GATES"
if [ "${host_gated}" = "0" ] && [ "${source_zero_diff_rc}" -eq 0 ] && [ "${gcp_tag_key_create_rc}" -eq 0 ]; then
  overall="PERFECT_OPS_ALL_GATES_PASS"
fi

cat > "${REPORT_FILE}" <<EOF
# Dominion Gate Hardening Receipt

Generated: $(date -u +%Y-%m-%dT%H:%M:%SZ)
Root: ${ROOT}
Project: ${PROJECT}
Region: ${REGION}
Verdict: ${overall}

## Repairs And Hardening Applied

- Bash syntax check: $(status_of "${bash_syntax_rc}")
- Live ops verification: $(status_of "${live_ops_rc}")
- Docker repair/diagnostic: $(status_of "${docker_repair_rc}")
- Docker Compose availability: $(status_of "${docker_compose_rc}")
- Docker Scout availability: $(status_of "${docker_scout_rc}")
- GCloud token refresh: $(status_of "${gcloud_token_rc}")
- GCP project labels hardening: $(status_of "${gcp_labels_rc}")
- Required GCP APIs enabled/confirmed: $(status_of "${gcp_required_apis_rc}")
- Cloud Run readiness: $(status_of "${cloud_run_rc}") (${cloud_run_counts})
- GCP Resource Manager environment tag hardening: $(status_of "${gcp_tag_key_create_rc}")
- AT2 max-mode certification: $(status_of "${at2_certify_rc}")
- Intelligent sync receipt replication: $(status_of "${intelligent_sync_rc}")

## Current Remaining Gates

- Host-gated AT2 checks remaining: ${host_gated}
- Source worktree dirty entries: ${dirty_count}
- Source zero-diff: $(status_of "${source_zero_diff_rc}")

## Notes

- A nonzero Docker repair exit can still be an expected host gate when nested mount namespaces are blocked.
- Resource Manager tag creation requires org-level tag admin authority when no existing environment tag key exists.
- D: mount and NVIDIA/CUDA exposure can only pass on the physical AT2 host or a runtime with those devices mounted.

## Latest AT2 Certification

\`\`\`json
$(sed -n '1,220p' "${TELEMETRY_DIR}/at2_host_max_mode_certification.json" 2>/dev/null)
\`\`\`
EOF

report_json="$(printf '%s' "${REPORT_FILE}" | json_string)"
overall_json="$(printf '%s' "${overall}" | json_string)"
cloud_run_json="$(printf '%s' "${cloud_run_counts}" | json_string)"

cat > "${STATUS_FILE}" <<EOF
{
  "generated_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "verdict": ${overall_json},
  "report_path": ${report_json},
  "project": "${PROJECT}",
  "region": "${REGION}",
  "checks": {
    "bash_syntax": "$(status_of "${bash_syntax_rc}")",
    "live_ops": "$(status_of "${live_ops_rc}")",
    "docker_repair": "$(status_of "${docker_repair_rc}")",
    "docker_compose": "$(status_of "${docker_compose_rc}")",
    "docker_scout": "$(status_of "${docker_scout_rc}")",
    "gcloud_token": "$(status_of "${gcloud_token_rc}")",
    "gcp_labels": "$(status_of "${gcp_labels_rc}")",
    "gcp_required_apis": "$(status_of "${gcp_required_apis_rc}")",
    "cloud_run": ${cloud_run_json},
    "gcp_environment_tag": "$(status_of "${gcp_tag_key_create_rc}")",
    "at2_certify": "$(status_of "${at2_certify_rc}")",
    "intelligent_sync": "$(status_of "${intelligent_sync_rc}")",
    "source_zero_diff": "$(status_of "${source_zero_diff_rc}")"
  },
  "remaining": {
    "host_gated_at2_checks": ${host_gated},
    "dirty_worktree_entries": ${dirty_count}
  }
}
EOF

mirror_target="${PHI_SYNC_LOCAL_MIRROR_FALLBACK_PATH:-/workspaces/dominion-os-demo-build-live}"
mkdir -p "${mirror_target}/scripts/reports" "${mirror_target}/scripts/telemetry" 2>/dev/null || true
cp "${REPORT_FILE}" "${mirror_target}/scripts/reports/$(basename "${REPORT_FILE}")" 2>/dev/null || true
cp "${STATUS_FILE}" "${mirror_target}/scripts/telemetry/$(basename "${STATUS_FILE}")" 2>/dev/null || true

if command -v gsutil >/dev/null 2>&1 && [ -n "${PHI_SYNC_GCS_BUCKET:-dominion-core-prod-drydock-state}" ]; then
  gcs_base="gs://${PHI_SYNC_GCS_BUCKET:-dominion-core-prod-drydock-state}/${PHI_SYNC_GCS_PREFIX:-dominion-live-ops/primary}"
  gsutil cp "${REPORT_FILE}" "${gcs_base}/scripts/reports/$(basename "${REPORT_FILE}")" >> "${LOG_FILE}" 2>&1 || true
  gsutil cp "${STATUS_FILE}" "${gcs_base}/scripts/telemetry/$(basename "${STATUS_FILE}")" >> "${LOG_FILE}" 2>&1 || true
fi

log "Dominion gate hardening complete: ${REPORT_FILE}"
printf '%s\n' "${REPORT_FILE}"
