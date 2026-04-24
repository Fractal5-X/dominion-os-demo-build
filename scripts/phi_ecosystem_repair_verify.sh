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

TELEMETRY_DIR="${SCRIPT_DIR}/telemetry"
REPORT_DIR="${SCRIPT_DIR}/reports"
MODE="${1:-repair-and-verify}"
TS="$(date -u +%Y%m%d_%H%M%SZ)"
REPORT_FILE="${REPORT_DIR}/ecosystem_repair_verify_${TS}.md"
JSON_FILE="${TELEMETRY_DIR}/ecosystem_repair_verify_status.json"
GCLOUD_CATALOG_FILE="${TELEMETRY_DIR}/gcloud_service_catalog_${TS}.txt"
LOG_FILE="${REPORT_DIR}/ecosystem_repair_verify_${TS}.log"
GCP_REGION="${PHI_ECOSYSTEM_GCP_REGION:-us-central1}"
PROJECTS="${PHI_GCLOUD_DEPLOY_PROJECTS:-${PHI_PUBLIC_GCP_PROJECT:-dominion-core-prod}}"
CLOUD_GOVERNOR_SCRIPT="${SCRIPT_DIR}/phi_cloud_governor.sh"
CLOUD_GOVERNOR_STATUS_FILE="${TELEMETRY_DIR}/cloud_governor_status.json"

mkdir -p "${TELEMETRY_DIR}" "${REPORT_DIR}"

log() {
  local level="$1"
  shift
  printf '[%s] [%s] %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "${level}" "$*" | tee -a "${LOG_FILE}"
}

have() {
  command -v "$1" >/dev/null 2>&1
}

health_ok() {
  local port="$1"
  local code
  for path in /health /healthz /ready /; do
    code="$(curl -sS -o /dev/null -w '%{http_code}' --max-time 2 "http://127.0.0.1:${port}${path}" 2>/dev/null || true)"
    case "${code}" in
      200|204) return 0 ;;
    esac
  done
  return 1
}

heartbeat_age_seconds() {
  local file="$1"
  local now ts ts_epoch
  [ -f "${file}" ] || {
    printf '%s\n' "-1"
    return 0
  }
  ts="$(cat "${file}" 2>/dev/null || true)"
  if printf '%s' "${ts}" | grep -Eq '^[0-9]+$'; then
    ts_epoch="${ts}"
  else
    ts_epoch="$(date -u -d "${ts}" +%s 2>/dev/null || true)"
    if ! printf '%s' "${ts_epoch}" | grep -Eq '^[0-9]+$'; then
      printf '%s\n' "-1"
      return 0
    fi
  fi
  now="$(date +%s)"
  printf '%s\n' "$((now - ts_epoch))"
}

write_report_header() {
  cat > "${REPORT_FILE}" <<EOF
# Ecosystem Repair + Verification

- Timestamp (UTC): $(date -u +%Y-%m-%dT%H:%M:%SZ)
- Mode: ${MODE}
- Region: ${GCP_REGION}
- Projects: ${PROJECTS}

EOF
}

append_report() {
  printf '%s\n' "$*" >> "${REPORT_FILE}"
}

cloud_governor_project_scope() {
  if [ -n "${PHI_ECOSYSTEM_ALL_GCP_PROJECTS:-}" ]; then
    printf '%s\n' "${PHI_ECOSYSTEM_ALL_GCP_PROJECTS}"
  else
    printf '%s\n' "${PROJECTS}"
  fi
}

run_cloud_governor() {
  local mode="$1"
  local scope
  scope="$(cloud_governor_project_scope)"

  env \
    PHI_SYNC_ENV_FILE=/dev/null \
    PHI_PUBLIC_GCP_PROJECT="${PHI_PUBLIC_GCP_PROJECT:-dominion-core-prod}" \
    PHI_PUBLIC_GCP_REGION="${PHI_PUBLIC_GCP_REGION:-${GCP_REGION}}" \
    PHI_ECOSYSTEM_GCP_REGION="${GCP_REGION}" \
    PHI_ECOSYSTEM_ALL_GCP_PROJECTS="${scope}" \
    PHI_PUBLIC_CLOUD_RUN_ALLOWLIST="${PHI_PUBLIC_CLOUD_RUN_ALLOWLIST:-dominion-os-demo,phi-askphi-widget,phi-oauth-server,dominion-demo-service}" \
    PHI_CLOUD_GOVERNOR_ENFORCE_SINGLE_BILLING_PUBLIC_PROJECT="${PHI_CLOUD_GOVERNOR_ENFORCE_SINGLE_BILLING_PUBLIC_PROJECT:-1}" \
    PHI_CLOUD_GOVERNOR_ENFORCE_NONOFFICIAL_NO_PUBLIC="${PHI_CLOUD_GOVERNOR_ENFORCE_NONOFFICIAL_NO_PUBLIC:-1}" \
    PHI_CLOUD_GOVERNOR_ENSURE_ALLOWLIST_PUBLIC="${PHI_CLOUD_GOVERNOR_ENSURE_ALLOWLIST_PUBLIC:-1}" \
    PHI_BILLING_ACCOUNT_PRIMARY="${PHI_BILLING_ACCOUNT_PRIMARY:-}" \
    bash "${CLOUD_GOVERNOR_SCRIPT}" "${mode}"
}

run_repair_actions() {
  log INFO "Repair phase start"
  if [ -x "${SCRIPT_DIR}/docker_repair_optimal.sh" ]; then
    bash "${SCRIPT_DIR}/docker_repair_optimal.sh" >> "${LOG_FILE}" 2>&1 || true
  fi
  bash "${SCRIPT_DIR}/phi_monitor_supervisor.sh" start >> "${LOG_FILE}" 2>&1 || true
  bash "${SCRIPT_DIR}/phi_intelligent_sync_daemon.sh" start >> "${LOG_FILE}" 2>&1 || true
  bash "${SCRIPT_DIR}/phi_start_all_systems.sh" --ensure-services-only --skip-monitor-start --quiet >> "${LOG_FILE}" 2>&1 || true
  bash "${SCRIPT_DIR}/phi_intelligent_sync.sh" >> "${LOG_FILE}" 2>&1 || true
  bash "${SCRIPT_DIR}/ecosystem_optimizer.sh" apply-safe >> "${LOG_FILE}" 2>&1 || true
  bash "${SCRIPT_DIR}/ecosystem_optimizer.sh" apply-aggressive >> "${LOG_FILE}" 2>&1 || true
  if [ "${PHI_CLOUD_GOVERNOR_APPLY_ON_REPAIR:-1}" = "1" ] && [ -x "${CLOUD_GOVERNOR_SCRIPT}" ]; then
    run_cloud_governor apply >> "${LOG_FILE}" 2>&1 || true
  fi
  log INFO "Repair phase complete"
}

collect_gcloud_catalog() {
  : > "${GCLOUD_CATALOG_FILE}"
  if ! have gcloud; then
    return 1
  fi
  local project service
  for project in ${PROJECTS}; do
    while IFS= read -r service; do
      [ -n "${service}" ] || continue
      printf '%s/%s\n' "${project}" "${service}" >> "${GCLOUD_CATALOG_FILE}"
    done < <(gcloud run services list --project "${project}" --region "${GCP_REGION}" --format='value(metadata.name)' 2>/dev/null || true)
  done
  sort -u -o "${GCLOUD_CATALOG_FILE}" "${GCLOUD_CATALOG_FILE}"
  return 0
}

refresh_cloud_governor_status() {
  if [ ! -x "${CLOUD_GOVERNOR_SCRIPT}" ]; then
    return 0
  fi
  case "${MODE}" in
    verify|verify-only)
      run_cloud_governor audit >> "${LOG_FILE}" 2>&1 || true
      ;;
    repair|repair-and-verify)
      if [ ! -f "${CLOUD_GOVERNOR_STATUS_FILE}" ]; then
        run_cloud_governor audit >> "${LOG_FILE}" 2>&1 || true
      fi
      ;;
  esac
}

verify_budget_authority_lock() {
  local status="FAIL"
  local detail="budget guard script missing"
  if [ -x "${SCRIPT_DIR}/budget_authority_guard.sh" ]; then
    if bash "${SCRIPT_DIR}/budget_authority_guard.sh" assert-locked >/dev/null 2>&1; then
      status="PASS"
      detail="budget increase authority locked (Matthew approval required)"
    else
      status="FAIL"
      detail="budget increase approval is active"
    fi
  fi
  append_report "## Budget Authority"
  append_report "- Status: ${status}"
  append_report "- Detail: ${detail}"
  append_report ""
  printf '%s|%s\n' "${status}" "${detail}"
}

verify_public_surface_policy() {
  local status="FAIL"
  local detail="public surface guard missing"
  if [ -x "${SCRIPT_DIR}/public_surface_guard.sh" ]; then
    if bash "${SCRIPT_DIR}/public_surface_guard.sh" assert >/dev/null 2>&1; then
      status="PASS"
      detail="official public surface is dominion-os-demo-build only"
    else
      detail="public surface policy misconfigured"
    fi
  fi
  append_report "## Public Surface Policy"
  append_report "- Status: ${status}"
  append_report "- Detail: ${detail}"
  append_report ""
  printf '%s|%s\n' "${status}" "${detail}"
}

verify_at2_profile() {
  local status="PASS"
  local detail=""
  local profile="${PHI_LOCAL_MACHINE_PROFILE:-}"
  local perf_mode="${PHI_LOCAL_MACHINE_PERF_MODE:-}"
  local cost_mode="${PHI_LOCAL_MACHINE_COST_MODE:-}"
  local cpu_count
  cpu_count="$(getconf _NPROCESSORS_ONLN 2>/dev/null || echo 0)"

  if [ "${profile}" != "AT2_LIVE_OPS" ]; then
    status="FAIL"
    detail="PHI_LOCAL_MACHINE_PROFILE=${profile}"
  fi
  if [ "${perf_mode}" != "MAX_PERFORMANCE" ]; then
    status="FAIL"
    detail="${detail} PHI_LOCAL_MACHINE_PERF_MODE=${perf_mode}"
  fi
  if [ "${cost_mode}" != "LOWEST_COST" ]; then
    status="FAIL"
    detail="${detail} PHI_LOCAL_MACHINE_COST_MODE=${cost_mode}"
  fi
  if [ "${cpu_count}" -lt 4 ]; then
    status="FAIL"
    detail="${detail} cpu_count=${cpu_count}"
  fi
  if [ -z "${detail}" ]; then
    detail="AT2 local profile active (${profile}/${perf_mode}/${cost_mode}, cpu=${cpu_count})"
  fi

  append_report "## Local AT2 Profile"
  append_report "- Status: ${status}"
  append_report "- Detail: ${detail}"
  append_report ""
  printf '%s|%s\n' "${status}" "${detail}"
}

verify_sync_state() {
  local status="PASS"
  local detail="intelligent sync daemon healthy"
  local monitor_status sync_age gcs_age mirror_age
  monitor_status="$(bash "${SCRIPT_DIR}/phi_monitor_supervisor.sh" status 2>/dev/null || true)"
  sync_age="$(heartbeat_age_seconds "${TELEMETRY_DIR}/.last_intelligent_sync")"
  gcs_age="$(heartbeat_age_seconds "${TELEMETRY_DIR}/.last_gcs_sync")"
  mirror_age="$(heartbeat_age_seconds "${TELEMETRY_DIR}/.last_local_mirror_sync")"

  if ! printf '%s' "${monitor_status}" | grep -q 'intelligent_sync=running'; then
    status="FAIL"
    detail="intelligent sync daemon not running"
  elif [ "${sync_age}" -lt 0 ] || [ "${sync_age}" -gt 600 ]; then
    status="FAIL"
    detail="sync heartbeat stale age=${sync_age}s"
  fi

  append_report "## Intelligent Sync"
  append_report "- Status: ${status}"
  append_report "- Sync heartbeat age (s): ${sync_age}"
  append_report "- GCS heartbeat age (s): ${gcs_age}"
  append_report "- Mirror heartbeat age (s): ${mirror_age}"
  append_report "- Detail: ${detail}"
  append_report ""
  printf '%s|%s\n' "${status}" "${detail}"
}

verify_authority_state() {
  local status="PASS"
  local detail="authority 14/14 NHITL max active"
  local sovereignty_level mode active_state max_power
  sovereignty_level="$(jq -r '.sovereignty_level // "unknown"' "${TELEMETRY_DIR}/sovereign_status.json" 2>/dev/null || echo unknown)"
  mode="$(jq -r '.mode // "unknown"' "${TELEMETRY_DIR}/sovereign_status.json" 2>/dev/null || echo unknown)"
  active_state="$(jq -r '.status // "unknown"' "${TELEMETRY_DIR}/sovereign_status.json" 2>/dev/null || echo unknown)"
  max_power="$(jq -r '.max_power // "unknown"' "${TELEMETRY_DIR}/sovereign_status.json" 2>/dev/null || echo unknown)"

  if [ "${sovereignty_level}" != "14/14" ] || [ "${mode}" != "NHITL_AUTOPILOT" ] || [ "${active_state}" != "ACTIVE" ] || [ "${max_power}" != "ENABLED" ]; then
    status="FAIL"
    detail="sovereignty_level=${sovereignty_level} mode=${mode} status=${active_state} max_power=${max_power}"
  fi

  append_report "## Authority"
  append_report "- Status: ${status}"
  append_report "- Sovereignty: ${sovereignty_level}"
  append_report "- Mode: ${mode}"
  append_report "- Active: ${active_state}"
  append_report "- Max power: ${max_power}"
  append_report "- Detail: ${detail}"
  append_report ""
  printf '%s|%s\n' "${status}" "${detail}"
}

verify_local_and_gcloud_services() {
  local local_running=0
  local local_total=0
  local gcloud_mapped=0
  local gcloud_total=0
  local status="PASS"
  local detail="all mapped services healthy"
  local entry label port pattern local_ok gcloud_ok
  local catalog_present=0

  append_report "## Service Matrix"
  append_report ""
  append_report "| Local Service | Port | Local Running | GCP Deployed | Mapping Pattern |"
  append_report "|---|---:|---|---|---|"

  if [ -s "${GCLOUD_CATALOG_FILE}" ]; then
    catalog_present=1
  fi

  while IFS= read -r entry; do
    [ -n "${entry}" ] || continue
    IFS='|' read -r label port pattern <<< "${entry}"
    local_total=$((local_total + 1))
    gcloud_total=$((gcloud_total + 1))

    local_ok="NO"
    gcloud_ok="NO"

    if health_ok "${port}"; then
      local_ok="YES"
      local_running=$((local_running + 1))
    fi
    if [ "${catalog_present}" -eq 1 ] && rg -i -q "${pattern}" "${GCLOUD_CATALOG_FILE}" 2>/dev/null; then
      gcloud_ok="YES"
      gcloud_mapped=$((gcloud_mapped + 1))
    fi

    append_report "| ${label} | ${port} | ${local_ok} | ${gcloud_ok} | ${pattern} |"
  done <<'EOF'
Dominion Command Center|5000|/(demo|dominion-demo|dominion-os-demo)$
Billing Service|5001|/(phi-expenditure-dashboard|dominion-api|api)$
Dominion Command Core|5002|/(dominion-api|api|pipeline|dp-workflow)$
Sidecar Service|5003|/(finalize-server|pipeline|dp-workflow)$
ChatGPT Gateway|5004|/chatgpt-gateway$
OAuth Server|8080|/phi-oauth-server$
AskPHI Widget Service|8081|/(phi-askphi-widget|dominion-phi-ui)$
Dominion Java Live Ops Site|8090|/(dominion-os-1-0-101|dominion-os|dominion-os-demo)$
Politics Local Legacy|5005|/(dominion-os-demo|dominion-demo|demo)$
EOF

  if [ "${local_running}" -ne "${local_total}" ] || [ "${gcloud_mapped}" -ne "${gcloud_total}" ]; then
    status="FAIL"
    detail="local ${local_running}/${local_total}, gcloud ${gcloud_mapped}/${gcloud_total}"
  fi

  append_report ""
  append_report "- Local services running: ${local_running}/${local_total}"
  append_report "- GCP mapped services deployed: ${gcloud_mapped}/${gcloud_total}"
  append_report "- Status: ${status}"
  append_report "- Detail: ${detail}"
  append_report ""
  printf '%s|%s|%s|%s\n' "${status}" "${detail}" "${local_running}/${local_total}" "${gcloud_mapped}/${gcloud_total}"
}

verify_cost_profile() {
  local status="PASS"
  local detail="cost controls active"
  local changed_only="${PHI_SYNC_GCS_CHANGED_ONLY:-0}"
  local delete_unmatched="${PHI_SYNC_GCS_DELETE_UNMATCHED:-1}"
  local gcs_interval="${PHI_SYNC_GCS_MIN_INTERVAL_SECONDS:-0}"
  local prod_aggressive="${PHI_ECOSYSTEM_AGGRESSIVE_ALLOW_PROD:-1}"

  if [ "${changed_only}" != "1" ] || [ "${delete_unmatched}" != "0" ] || [ "${gcs_interval}" -lt 300 ] || [ "${prod_aggressive}" != "0" ]; then
    status="FAIL"
    detail="changed_only=${changed_only} delete_unmatched=${delete_unmatched} gcs_interval=${gcs_interval} prod_aggressive=${prod_aggressive}"
  fi

  append_report "## Cost Posture"
  append_report "- Status: ${status}"
  append_report "- Detail: ${detail}"
  append_report ""
  printf '%s|%s\n' "${status}" "${detail}"
}

verify_cloud_governor() {
  local status="FAIL"
  local detail="cloud governor status unavailable"
  local overall billing_check exposure_check

  if [ -f "${CLOUD_GOVERNOR_STATUS_FILE}" ]; then
    overall="$(jq -r '.overall_status // "unknown"' "${CLOUD_GOVERNOR_STATUS_FILE}" 2>/dev/null || echo unknown)"
    billing_check="$(jq -r '.checks.single_public_billing_project // "FAIL"' "${CLOUD_GOVERNOR_STATUS_FILE}" 2>/dev/null || echo FAIL)"
    exposure_check="$(jq -r '.checks.nonofficial_public_exposure_locked // "FAIL"' "${CLOUD_GOVERNOR_STATUS_FILE}" 2>/dev/null || echo FAIL)"
    if [ "${overall}" = "PASS" ] && [ "${billing_check}" = "PASS" ] && [ "${exposure_check}" = "PASS" ]; then
      status="PASS"
      detail="cloud governor policy checks pass"
    else
      detail="overall=${overall} billing=${billing_check} exposure=${exposure_check}"
    fi
  fi

  append_report "## Cloud Governor"
  append_report "- Status: ${status}"
  append_report "- Detail: ${detail}"
  append_report "- Status file: ${CLOUD_GOVERNOR_STATUS_FILE}"
  append_report ""
  printf '%s|%s\n' "${status}" "${detail}"
}

write_status_json() {
  local budget_status="$1"
  local public_surface_status="$2"
  local at2_status="$3"
  local sync_status="$4"
  local authority_status="$5"
  local service_status="$6"
  local cost_status="$7"
  local cloud_governor_status="$8"
  local overall="PASS"

  for s in "${budget_status}" "${public_surface_status}" "${at2_status}" "${sync_status}" "${authority_status}" "${service_status}" "${cost_status}" "${cloud_governor_status}"; do
    if [ "${s}" != "PASS" ]; then
      overall="FAIL"
    fi
  done

  cat > "${JSON_FILE}" <<EOF
{
  "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "mode": "${MODE}",
  "overall_status": "${overall}",
  "report_path": "${REPORT_FILE}",
  "log_path": "${LOG_FILE}",
  "gcloud_catalog_path": "${GCLOUD_CATALOG_FILE}",
  "checks": {
    "budget_authority_lock": "${budget_status}",
    "public_surface_policy": "${public_surface_status}",
    "local_at2_profile": "${at2_status}",
    "intelligent_sync": "${sync_status}",
    "authority_14_14_nhitl_max": "${authority_status}",
    "service_local_and_gcloud": "${service_status}",
    "lowest_cost_profile": "${cost_status}",
    "cloud_governor_policy": "${cloud_governor_status}"
  }
}
EOF
}

main() {
  local budget_line public_surface_line at2_line sync_line authority_line service_line cost_line cloud_governor_line
  local budget_status public_surface_status at2_status sync_status authority_status service_status cost_status cloud_governor_status

  case "${MODE}" in
    repair|repair-and-verify) run_repair_actions ;;
    verify|verify-only) ;;
    *)
      echo "Usage: $0 [repair|repair-and-verify|verify|verify-only]"
      exit 1
      ;;
  esac

  write_report_header
  collect_gcloud_catalog || true
  refresh_cloud_governor_status

  budget_line="$(verify_budget_authority_lock)"
  public_surface_line="$(verify_public_surface_policy)"
  at2_line="$(verify_at2_profile)"
  sync_line="$(verify_sync_state)"
  authority_line="$(verify_authority_state)"
  service_line="$(verify_local_and_gcloud_services)"
  cost_line="$(verify_cost_profile)"
  cloud_governor_line="$(verify_cloud_governor)"

  budget_status="$(printf '%s' "${budget_line}" | cut -d'|' -f1)"
  public_surface_status="$(printf '%s' "${public_surface_line}" | cut -d'|' -f1)"
  at2_status="$(printf '%s' "${at2_line}" | cut -d'|' -f1)"
  sync_status="$(printf '%s' "${sync_line}" | cut -d'|' -f1)"
  authority_status="$(printf '%s' "${authority_line}" | cut -d'|' -f1)"
  service_status="$(printf '%s' "${service_line}" | cut -d'|' -f1)"
  cost_status="$(printf '%s' "${cost_line}" | cut -d'|' -f1)"
  cloud_governor_status="$(printf '%s' "${cloud_governor_line}" | cut -d'|' -f1)"

  write_status_json \
    "${budget_status}" \
    "${public_surface_status}" \
    "${at2_status}" \
    "${sync_status}" \
    "${authority_status}" \
    "${service_status}" \
    "${cost_status}" \
    "${cloud_governor_status}"

  log INFO "Repair+verify complete report=${REPORT_FILE}"
  printf '%s\n' "${REPORT_FILE}"
}

main
