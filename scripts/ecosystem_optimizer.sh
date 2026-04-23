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
ECOSYSTEM_ROOT="${DOMINION_ECOSYSTEM_ROOT:-/workspaces}"
GCP_REGION="${PHI_ECOSYSTEM_GCP_REGION:-us-central1}"
GCP_TIMEOUT_SECONDS="${PHI_ECOSYSTEM_GCP_TIMEOUT_SECONDS:-8}"
REPO_REMOTE_TIMEOUT_SECONDS="${PHI_ECOSYSTEM_REPO_REMOTE_TIMEOUT_SECONDS:-8}"
KEEP_WARM_SERVICES="${PHI_ECOSYSTEM_KEEP_WARM_SERVICES:-}"
BUDGET_GUARD_SCRIPT="${SCRIPT_DIR}/budget_authority_guard.sh"
PUBLIC_SURFACE_GUARD_SCRIPT="${SCRIPT_DIR}/public_surface_guard.sh"
GCP_PROJECT_SCOPE="${PHI_ECOSYSTEM_GCP_PROJECTS:-${PHI_GCLOUD_DEPLOY_PROJECTS:-}}"
MODE="${1:-audit}"
TS="$(date -u +%Y%m%d_%H%M%SZ)"
LOG_FILE="${REPORT_DIR}/ecosystem_optimizer_${TS}.log"
REPORT_FILE="${REPORT_DIR}/ecosystem_optimizer_${TS}.md"
STATUS_FILE="${TELEMETRY_DIR}/ecosystem_optimizer_status.json"
WORK_FILE="$(mktemp "${TMPDIR:-/tmp}/ecosystem-optimizer.XXXXXX")"

mkdir -p "${TELEMETRY_DIR}" "${REPORT_DIR}"

cleanup() {
  rm -f "${WORK_FILE}"
}
trap cleanup EXIT

log() {
  local level="$1"
  shift
  local line
  line="[$(date -u +%Y-%m-%dT%H:%M:%SZ)] [${level}] $*"
  printf '%s\n' "${line}" | tee -a "${LOG_FILE}" >&2
}

have() {
  command -v "$1" >/dev/null 2>&1
}

usage() {
  cat <<'EOF'
Usage: ecosystem_optimizer.sh [audit|apply-safe|apply-aggressive|status]

audit      Collect cross-repo + cross-project optimization inventory (default).
apply-safe Apply low-risk optimizations and collect a full report.
apply-aggressive Apply safe tuning plus bounded aggressive Cloud Run scaling trims.
status     Print the latest telemetry status json.
EOF
}

csv_has_match() {
  local needle="$1"
  local token
  for token in ${KEEP_WARM_SERVICES//,/ }; do
    [ -n "${token}" ] || continue
    if [ "${token}" = "${needle}" ]; then
      return 0
    fi
  done
  return 1
}

is_keep_warm_service() {
  local project_id="$1"
  local service_name="$2"
  local project_service="${project_id}/${service_name}"
  csv_has_match "${service_name}" || csv_has_match "${project_service}"
}

project_tier() {
  local project_id="$1"
  local lower
  lower="$(printf '%s' "${project_id}" | tr '[:upper:]' '[:lower:]')"
  if printf '%s' "${lower}" | grep -Eq '(^|[-_])(prod|production)([-_]|$)'; then
    echo "prod"
    return 0
  fi
  if printf '%s' "${lower}" | grep -Eq '(^|[-_])(dev|stage|staging|preprod|sandbox|test|sys|demo|lab|labs|research|internal|mpf)([-_]|$)'; then
    echo "nonprod"
    return 0
  fi
  echo "unknown"
}

safe_timeout() {
  local seconds="$1"
  shift
  timeout "${seconds}" "$@" < /dev/null 2>/dev/null
}

scale_to_int() {
  local value="${1:-}"
  if printf '%s' "${value}" | grep -Eq '^[0-9]+$'; then
    printf '%s\n' "${value}"
  else
    printf '%s\n' "-1"
  fi
}

project_billing_enabled() {
  local project_id="$1"
  local value
  value="$(
    safe_timeout "${GCP_TIMEOUT_SECONDS}" \
      gcloud billing projects describe "${project_id}" --format='value(billingEnabled)' \
      || true
  )"
  case "${value}" in
    True|true) echo "true" ;;
    False|false) echo "false" ;;
    *) echo "unknown" ;;
  esac
}

init_report() {
  cat > "${REPORT_FILE}" <<EOF
# Ecosystem Optimizer Report

- Timestamp (UTC): $(date -u +%Y-%m-%dT%H:%M:%SZ)
- Mode: ${MODE}
- Root: ${ECOSYSTEM_ROOT}
- Region: ${GCP_REGION}

## Docker Baseline
EOF
}

report_append() {
  printf '%s\n' "$*" >> "${REPORT_FILE}"
}

audit_budget_authority() {
  local budget_lock_state="unknown"
  local required_approver="${PHI_BUDGET_APPROVER_REQUIRED:-Matthew Burbidge}"
  local local_profile="${PHI_LOCAL_MACHINE_PROFILE:-AT2_LIVE_OPS}"
  local public_surface_state="unknown"
  local public_repo="${PHI_PUBLIC_SURFACE_REPO:-dominion-os-demo-build}"
  local public_project="${PHI_PUBLIC_GCP_PROJECT:-dominion-core-prod}"

  if [ -x "${BUDGET_GUARD_SCRIPT}" ]; then
    if bash "${BUDGET_GUARD_SCRIPT}" assert-locked >/dev/null 2>&1; then
      budget_lock_state="locked"
    elif bash "${BUDGET_GUARD_SCRIPT}" require-approval >/dev/null 2>&1; then
      budget_lock_state="approval_active"
    else
      budget_lock_state="unknown"
    fi
  fi
  if [ -x "${PUBLIC_SURFACE_GUARD_SCRIPT}" ]; then
    if bash "${PUBLIC_SURFACE_GUARD_SCRIPT}" assert >/dev/null 2>&1; then
      public_surface_state="valid"
    else
      public_surface_state="invalid"
    fi
  fi

  report_append "## Governance"
  report_append "- Budget increase authority: ${budget_lock_state}"
  report_append "- Required approver: ${required_approver}"
  report_append "- Public surface policy: ${public_surface_state}"
  report_append "- Official public surface repo: ${public_repo}"
  report_append "- Official public GCP project: ${public_project}"
  report_append "- Local machine profile: ${local_profile}"
  report_append ""
  printf '%s\n' "${budget_lock_state}"
}

audit_docker() {
  local docker_version="unavailable"
  local compose_version="unavailable"
  local docker_status="unavailable"

  if have docker; then
    docker_version="$(docker version --format 'client={{.Client.Version}} server={{.Server.Version}}' 2>/dev/null || echo unavailable)"
    if docker info >/dev/null 2>&1; then
      docker_status="ready"
    else
      docker_status="partial"
    fi
  fi

  if have docker; then
    compose_version="$(docker compose version 2>/dev/null || echo unavailable)"
  elif have docker-compose; then
    compose_version="$(docker-compose version --short 2>/dev/null || docker-compose version 2>/dev/null || echo unavailable)"
  fi

  report_append "- Docker status: ${docker_status}"
  report_append "- Docker version: ${docker_version}"
  report_append "- Compose version: ${compose_version}"
}

apply_git_tuning() {
  local repo="$1"
  git -C "${repo}" config fetch.prune true
  git -C "${repo}" config remote.origin.prune true || true
  git -C "${repo}" config push.autoSetupRemote true
  git -C "${repo}" config gc.auto 256
  git -C "${repo}" config maintenance.auto true || true
  git -C "${repo}" maintenance run --auto >/dev/null 2>&1 || true
  git -C "${repo}" gc --auto >/dev/null 2>&1 || true
}

audit_repositories() {
  local repo_count=0
  local dirty_count=0
  local remote_warn_count=0
  local apply_count=0
  local repo

  report_append ""
  report_append "## Source Repositories"
  report_append ""
  report_append "| Repository | Branch | Dirty Files | Remotes | Remote Health |"
  report_append "|---|---:|---:|---:|---|"

  find "${ECOSYSTEM_ROOT}" -mindepth 1 -maxdepth 2 -type d -name .git 2>/dev/null \
    | sed 's#/.git$##' \
    | sort > "${WORK_FILE}"

  while IFS= read -r repo; do
    [ -n "${repo}" ] || continue
    repo_count=$((repo_count + 1))

    local branch="unknown"
    local dirty="0"
    local remotes="0"
    local remote_health="n/a"
    local origin_url=""

    branch="$(git -C "${repo}" rev-parse --abbrev-ref HEAD 2>/dev/null || echo detached)"
    dirty="$(git -C "${repo}" status --porcelain 2>/dev/null | sed '/^$/d' | wc -l | tr -d ' ')"
    remotes="$(git -C "${repo}" remote 2>/dev/null | sed '/^$/d' | wc -l | tr -d ' ')"
    origin_url="$(git -C "${repo}" remote get-url origin 2>/dev/null || true)"

    if [ "${dirty}" -gt 0 ]; then
      dirty_count=$((dirty_count + 1))
    fi

    if [ -n "${origin_url}" ]; then
      if safe_timeout "${REPO_REMOTE_TIMEOUT_SECONDS}" git -C "${repo}" ls-remote --heads origin >/dev/null; then
        remote_health="ok"
      else
        remote_health="warn"
        remote_warn_count=$((remote_warn_count + 1))
      fi
    fi

    if [ "${MODE}" = "apply-safe" ] || [ "${MODE}" = "apply-aggressive" ]; then
      apply_git_tuning "${repo}"
      apply_count=$((apply_count + 1))
    fi

    report_append "| ${repo} | ${branch} | ${dirty} | ${remotes} | ${remote_health} |"
  done < "${WORK_FILE}"

  report_append ""
  report_append "- Repository count: ${repo_count}"
  report_append "- Dirty repositories: ${dirty_count}"
  report_append "- Remote health warnings: ${remote_warn_count}"
  if [ "${MODE}" = "apply-safe" ] || [ "${MODE}" = "apply-aggressive" ]; then
    report_append "- Git tuning applied to: ${apply_count} repositories"
  fi

  printf '%s;%s;%s\n' "${repo_count}" "${dirty_count}" "${remote_warn_count}"
}

audit_ai_systems() {
  local ai_file_count=0
  local ai_container_count=0
  local ai_process_count=0

  report_append ""
  report_append "## AI Runtime Inventory"

  if have rg; then
    ai_file_count="$(
      rg -i -l \
        --glob 'docker-compose*.yml' \
        --glob 'docker-compose*.yaml' \
        --glob '*.env' \
        --glob '*.json' \
        --glob '*.yaml' \
        --glob '*.yml' \
        '(openai|ollama|vllm|llama|anthropic|gemini|litellm|inference|model|phi[-_ ]agent|mcp)' \
        "${ECOSYSTEM_ROOT}" 2>/dev/null \
        | sed '/^$/d' \
        | wc -l \
        | tr -d ' '
    )"
  else
    ai_file_count="$(
      find "${ECOSYSTEM_ROOT}" -type f \( \
        -name 'docker-compose*.yml' -o -name 'docker-compose*.yaml' -o -name '*.env' -o -name '*.json' -o -name '*.yaml' -o -name '*.yml' \
      \) -print0 2>/dev/null \
        | xargs -0 grep -Eil '(openai|ollama|vllm|llama|anthropic|gemini|litellm|inference|model|phi[-_ ]agent|mcp)' 2>/dev/null \
        | sed '/^$/d' \
        | wc -l \
        | tr -d ' '
    )"
  fi

  if have docker; then
    if have rg; then
      ai_container_count="$(
        docker ps --format '{{.Names}} {{.Image}}' 2>/dev/null \
          | rg -i '(ollama|open-webui|litellm|vllm|llama|mcp|phi)' \
          | sed '/^$/d' \
          | wc -l \
          | tr -d ' ' \
          || true
      )"
    else
      ai_container_count="$(
        docker ps --format '{{.Names}} {{.Image}}' 2>/dev/null \
          | grep -Ei '(ollama|open-webui|litellm|vllm|llama|mcp|phi)' \
          | sed '/^$/d' \
          | wc -l \
          | tr -d ' ' \
          || true
      )"
    fi
    ai_container_count="${ai_container_count:-0}"
  fi

  if have rg; then
    ai_process_count="$(
      ps -eo args 2>/dev/null \
        | rg -i '(ollama|vllm|llama|litellm|openai|anthropic|vertex|mcp|phi)' \
        | sed '/^$/d' \
        | wc -l \
        | tr -d ' ' \
        || true
    )"
  else
    ai_process_count="$(
      ps -eo args 2>/dev/null \
        | grep -Ei '(ollama|vllm|llama|litellm|openai|anthropic|vertex|mcp|phi)' \
        | sed '/^$/d' \
        | wc -l \
        | tr -d ' ' \
        || true
    )"
  fi
  ai_process_count="${ai_process_count:-0}"

  report_append "- AI-related config files: ${ai_file_count}"
  report_append "- AI-related containers running: ${ai_container_count}"
  report_append "- AI-related processes running: ${ai_process_count}"
  printf '%s;%s;%s\n' "${ai_file_count}" "${ai_container_count}" "${ai_process_count}"
}

audit_gcp() {
  local project_count=0
  local nonprod_count=0
  local prod_count=0
  local run_services_total=0
  local safe_tuning_applied=0
  local safe_tuning_failed=0
  local safe_tuning_blocked=0
  local aggressive_tuning_applied=0
  local aggressive_tuning_failed=0
  local aggressive_tuning_blocked=0
  local aggressive_max_instances_nonprod="${PHI_ECOSYSTEM_AGGRESSIVE_MAX_INSTANCES_NONPROD:-10}"
  local aggressive_allow_prod="${PHI_ECOSYSTEM_AGGRESSIVE_ALLOW_PROD:-0}"
  local aggressive_max_instances_prod="${PHI_ECOSYSTEM_AGGRESSIVE_MAX_INSTANCES_PROD:-30}"

  report_append ""
  report_append "## GCP Projects"
  report_append ""
  report_append "| Project | Tier | Billing | Cloud Run Services | Safe Tune | Aggressive Tune |"
  report_append "|---|---|---|---:|---:|---:|"

  if ! have gcloud; then
    report_append "| gcloud unavailable | n/a | n/a | 0 | 0 | 0 |"
    printf '%s;%s;%s;%s;%s;%s;%s;%s\n' "0" "0" "0" "0" "0" "0" "0" "0"
    return
  fi

  if [ -n "${GCP_PROJECT_SCOPE}" ]; then
    # shellcheck disable=SC2086
    for project_id in ${GCP_PROJECT_SCOPE}; do
      printf '%s\n' "${project_id}"
    done | sed '/^$/d' > "${WORK_FILE}"
  else
    gcloud projects list --format='value(projectId)' 2>/dev/null | sed '/^$/d' > "${WORK_FILE}"
  fi
  while IFS= read -r project_id; do
    [ -n "${project_id}" ] || continue
    project_count=$((project_count + 1))

    local tier
    local run_count="na"
    local safe_applied_this_project=0
    local aggressive_applied_this_project=0
    local billing_state="n/a"
    local service_names=""
    local service=""

    tier="$(project_tier "${project_id}")"
    case "${tier}" in
      prod) prod_count=$((prod_count + 1)) ;;
      nonprod) nonprod_count=$((nonprod_count + 1)) ;;
    esac

    service_names="$(
      safe_timeout "${GCP_TIMEOUT_SECONDS}" \
        gcloud run services list \
          --project "${project_id}" \
          --region "${GCP_REGION}" \
          --format='value(metadata.name)' \
        | sed '/^$/d' \
        || true
    )"

    if [ -n "${service_names}" ]; then
      run_count="$(printf '%s\n' "${service_names}" | wc -l | tr -d ' ')"
      run_services_total=$((run_services_total + run_count))
    fi

    if [ "${MODE}" = "apply-safe" ] || [ "${MODE}" = "apply-aggressive" ]; then
      billing_state="$(project_billing_enabled "${project_id}")"
    fi

    if { [ "${MODE}" = "apply-safe" ] || [ "${MODE}" = "apply-aggressive" ]; } && [ -n "${service_names}" ]; then
      while IFS= read -r service; do
        [ -n "${service}" ] || continue
        local scales min_scale_raw max_scale_raw min_scale max_scale
        local tune_min=0
        local tune_max=0
        local target_max=-1
        local update_args=()

        scales="$(
          safe_timeout "${GCP_TIMEOUT_SECONDS}" \
            gcloud run services describe "${service}" \
              --project "${project_id}" \
              --region "${GCP_REGION}" \
              --format='value(spec.template.metadata.annotations."autoscaling.knative.dev/minScale",spec.template.metadata.annotations."autoscaling.knative.dev/maxScale")' \
            || true
        )"
        min_scale_raw="$(printf '%s' "${scales}" | awk '{print $1}')"
        max_scale_raw="$(printf '%s' "${scales}" | awk '{print $2}')"
        min_scale="$(scale_to_int "${min_scale_raw}")"
        max_scale="$(scale_to_int "${max_scale_raw}")"

        if [ "${MODE}" = "apply-safe" ] || [ "${MODE}" = "apply-aggressive" ]; then
          if [ "${tier}" = "nonprod" ] && [ "${min_scale}" -gt 0 ]; then
            tune_min=1
          fi
        fi

        if [ "${MODE}" = "apply-aggressive" ]; then
          if [ "${tier}" = "nonprod" ]; then
            target_max="${aggressive_max_instances_nonprod}"
          elif [ "${tier}" = "prod" ] && [ "${aggressive_allow_prod}" = "1" ]; then
            target_max="${aggressive_max_instances_prod}"
          fi

          if [ "${target_max}" -ge 0 ] && [ "${max_scale}" -gt "${target_max}" ]; then
            tune_max=1
          fi
        fi

        if [ "${tune_min}" -eq 1 ] || [ "${tune_max}" -eq 1 ]; then
          if [ "${billing_state}" != "true" ]; then
            if [ "${tune_min}" -eq 1 ]; then
              safe_tuning_blocked=$((safe_tuning_blocked + 1))
            fi
            if [ "${tune_max}" -eq 1 ]; then
              aggressive_tuning_blocked=$((aggressive_tuning_blocked + 1))
            fi
            log "WARN" "Skipping tune due billing=${billing_state}: ${project_id}/${service}"
            continue
          fi

          if is_keep_warm_service "${project_id}" "${service}"; then
            log "INFO" "Skipping keep-warm service ${project_id}/${service} (minScale=${min_scale} maxScale=${max_scale})"
            continue
          fi

          if [ "${tune_min}" -eq 1 ]; then
            update_args+=(--min-instances=0)
          fi
          if [ "${tune_max}" -eq 1 ]; then
            update_args+=(--max-instances="${target_max}")
          fi

          if safe_timeout "${GCP_TIMEOUT_SECONDS}" \
            gcloud run services update "${service}" \
              --project "${project_id}" \
              --region "${GCP_REGION}" \
              "${update_args[@]}" \
              --quiet >/dev/null; then
            if [ "${tune_min}" -eq 1 ]; then
              safe_tuning_applied=$((safe_tuning_applied + 1))
              safe_applied_this_project=$((safe_applied_this_project + 1))
            fi
            if [ "${tune_max}" -eq 1 ]; then
              aggressive_tuning_applied=$((aggressive_tuning_applied + 1))
              aggressive_applied_this_project=$((aggressive_applied_this_project + 1))
            fi
            log "INFO" "Applied tune ${project_id}/${service}: min->0=${tune_min} max->${target_max}=${tune_max}"
          else
            if [ "${tune_min}" -eq 1 ]; then
              safe_tuning_failed=$((safe_tuning_failed + 1))
            fi
            if [ "${tune_max}" -eq 1 ]; then
              aggressive_tuning_failed=$((aggressive_tuning_failed + 1))
            fi
            log "WARN" "Failed tune ${project_id}/${service}: min->0=${tune_min} max->${target_max}=${tune_max}"
          fi
        fi
      done <<< "${service_names}"
    fi

    report_append "| ${project_id} | ${tier} | ${billing_state} | ${run_count} | ${safe_applied_this_project} | ${aggressive_applied_this_project} |"
  done < "${WORK_FILE}"

  report_append ""
  report_append "- GCP project count: ${project_count}"
  report_append "- Prod projects: ${prod_count}"
  report_append "- Nonprod projects: ${nonprod_count}"
  report_append "- Cloud Run services discovered: ${run_services_total}"
  if [ "${MODE}" = "apply-safe" ] || [ "${MODE}" = "apply-aggressive" ]; then
    report_append "- Safe tuning applied (min-instances=0, nonprod): ${safe_tuning_applied}"
    report_append "- Safe tuning failed: ${safe_tuning_failed}"
    report_append "- Safe tuning blocked (billing/guardrails): ${safe_tuning_blocked}"
  fi
  if [ "${MODE}" = "apply-aggressive" ]; then
    report_append "- Aggressive tuning applied (max-instances trims): ${aggressive_tuning_applied}"
    report_append "- Aggressive tuning failed: ${aggressive_tuning_failed}"
    report_append "- Aggressive tuning blocked (billing/guardrails): ${aggressive_tuning_blocked}"
  fi

  printf '%s;%s;%s;%s;%s;%s;%s;%s\n' \
    "${project_count}" \
    "${prod_count}" \
    "${nonprod_count}" \
    "${run_services_total}" \
    "${safe_tuning_applied}" \
    "${safe_tuning_failed}" \
    "${aggressive_tuning_applied}" \
    "${aggressive_tuning_failed}"
}

write_status_json() {
  local repo_count="$1"
  local dirty_count="$2"
  local remote_warn_count="$3"
  local ai_file_count="$4"
  local ai_container_count="$5"
  local ai_process_count="$6"
  local project_count="$7"
  local prod_count="$8"
  local nonprod_count="$9"
  local run_services_total="${10}"
  local safe_tuning_applied="${11}"
  local safe_tuning_failed="${12}"
  local aggressive_tuning_applied="${13}"
  local aggressive_tuning_failed="${14}"
  local budget_lock_state="${15}"

  cat > "${STATUS_FILE}" <<EOF
{
  "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "mode": "${MODE}",
  "region": "${GCP_REGION}",
  "ecosystem_root": "${ECOSYSTEM_ROOT}",
  "report_path": "${REPORT_FILE}",
  "log_path": "${LOG_FILE}",
  "governance": {
    "budget_increase_authority": "${budget_lock_state}",
    "required_approver": "${PHI_BUDGET_APPROVER_REQUIRED:-Matthew Burbidge}"
  },
  "repositories": {
    "count": ${repo_count},
    "dirty": ${dirty_count},
    "remote_warnings": ${remote_warn_count}
  },
  "ai_systems": {
    "config_files": ${ai_file_count},
    "containers_running": ${ai_container_count},
    "processes_running": ${ai_process_count}
  },
  "gcp": {
    "projects": ${project_count},
    "prod_projects": ${prod_count},
    "nonprod_projects": ${nonprod_count},
    "cloud_run_services": ${run_services_total},
    "safe_tuning_applied": ${safe_tuning_applied},
    "safe_tuning_failed": ${safe_tuning_failed},
    "aggressive_tuning_applied": ${aggressive_tuning_applied},
    "aggressive_tuning_failed": ${aggressive_tuning_failed}
  }
}
EOF
}

run_main() {
  local repo_data
  local ai_data
  local gcp_data
  local budget_lock_state
  local repo_count dirty_count remote_warn_count
  local ai_file_count ai_container_count ai_process_count
  local project_count prod_count nonprod_count run_services_total safe_tuning_applied safe_tuning_failed aggressive_tuning_applied aggressive_tuning_failed

  case "${MODE}" in
    audit|apply-safe|apply-aggressive) ;;
    status)
      if [ -f "${STATUS_FILE}" ]; then
        cat "${STATUS_FILE}"
        exit 0
      fi
      echo "{}"
      exit 0
      ;;
    -h|--help|help)
      usage
      exit 0
      ;;
    *)
      usage
      exit 1
      ;;
  esac

  init_report
  log "INFO" "Starting ecosystem optimizer mode=${MODE} root=${ECOSYSTEM_ROOT}"
  budget_lock_state="$(audit_budget_authority)"
  audit_docker

  repo_data="$(audit_repositories)"
  IFS=';' read -r repo_count dirty_count remote_warn_count <<< "${repo_data}"

  ai_data="$(audit_ai_systems)"
  IFS=';' read -r ai_file_count ai_container_count ai_process_count <<< "${ai_data}"

  gcp_data="$(audit_gcp)"
  IFS=';' read -r project_count prod_count nonprod_count run_services_total safe_tuning_applied safe_tuning_failed aggressive_tuning_applied aggressive_tuning_failed <<< "${gcp_data}"

  write_status_json \
    "${repo_count}" \
    "${dirty_count}" \
    "${remote_warn_count}" \
    "${ai_file_count}" \
    "${ai_container_count}" \
    "${ai_process_count}" \
    "${project_count}" \
    "${prod_count}" \
    "${nonprod_count}" \
    "${run_services_total}" \
    "${safe_tuning_applied}" \
    "${safe_tuning_failed}" \
    "${aggressive_tuning_applied}" \
    "${aggressive_tuning_failed}" \
    "${budget_lock_state}"

  report_append ""
  report_append "## Outputs"
  report_append "- Status json: ${STATUS_FILE}"
  report_append "- Log file: ${LOG_FILE}"

  log "INFO" "Optimizer completed; report=${REPORT_FILE}"
  printf '%s\n' "${REPORT_FILE}"
}

run_main
