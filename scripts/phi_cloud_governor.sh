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
MODE="${1:-audit}"
TS="$(date -u +%Y%m%d_%H%M%SZ)"
REPORT_FILE="${REPORT_DIR}/cloud_governor_${TS}.md"
LOG_FILE="${REPORT_DIR}/cloud_governor_${TS}.log"
STATUS_FILE="${TELEMETRY_DIR}/cloud_governor_status.json"
WORK_FILE="$(mktemp "${TMPDIR:-/tmp}/cloud-governor.XXXXXX")"

OFFICIAL_PUBLIC_PROJECT="${PHI_PUBLIC_GCP_PROJECT:-dominion-core-prod}"
REGION="${PHI_PUBLIC_GCP_REGION:-${PHI_ECOSYSTEM_GCP_REGION:-us-central1}}"
ALL_PROJECT_SCOPE="${PHI_ECOSYSTEM_ALL_GCP_PROJECTS:-}"
PUBLIC_ALLOWLIST="${PHI_PUBLIC_CLOUD_RUN_ALLOWLIST:-dominion-os-demo,phi-askphi-widget,phi-oauth-server,dominion-demo-service}"
ENFORCE_SINGLE_BILLING="${PHI_CLOUD_GOVERNOR_ENFORCE_SINGLE_BILLING_PUBLIC_PROJECT:-1}"
ENFORCE_PUBLIC_LOCKDOWN="${PHI_CLOUD_GOVERNOR_ENFORCE_NONOFFICIAL_NO_PUBLIC:-1}"
ENFORCE_ALLOWLIST_PUBLIC="${PHI_CLOUD_GOVERNOR_ENSURE_ALLOWLIST_PUBLIC:-1}"
PRIMARY_BILLING_ACCOUNT="${PHI_BILLING_ACCOUNT_PRIMARY:-}"
GCLOUD_TIMEOUT_SECONDS="${PHI_ECOSYSTEM_GCP_TIMEOUT_SECONDS:-10}"

mkdir -p "${TELEMETRY_DIR}" "${REPORT_DIR}"

cleanup() {
  rm -f "${WORK_FILE}"
}
trap cleanup EXIT

log() {
  local level="$1"
  shift
  printf '[%s] [%s] %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "${level}" "$*" | tee -a "${LOG_FILE}" >&2
}

have() {
  command -v "$1" >/dev/null 2>&1
}

safe_timeout() {
  local seconds="$1"
  shift
  timeout "${seconds}" "$@" < /dev/null 2>/dev/null
}

csv_has_match() {
  local csv="$1"
  local needle="$2"
  local token
  for token in ${csv//,/ }; do
    [ -n "${token}" ] || continue
    if [ "${token}" = "${needle}" ]; then
      return 0
    fi
  done
  return 1
}

usage() {
  cat <<'USAGE'
Usage: phi_cloud_governor.sh [audit|apply|status]

audit   Scan all reachable GCP projects for public-surface and billing-policy drift.
apply   Enforce single-public-surface policy (billing + Cloud Run public exposure).
status  Print latest status JSON.
USAGE
}

init_report() {
  cat > "${REPORT_FILE}" <<EOF2
# Cloud Governor Report

- Timestamp (UTC): $(date -u +%Y-%m-%dT%H:%M:%SZ)
- Mode: ${MODE}
- Official public project: ${OFFICIAL_PUBLIC_PROJECT}
- Region: ${REGION}
- Enforce single billing project: ${ENFORCE_SINGLE_BILLING}
- Enforce non-official no-public exposure: ${ENFORCE_PUBLIC_LOCKDOWN}
- Ensure official allowlist public: ${ENFORCE_ALLOWLIST_PUBLIC}

## Policy Summary

- Official public surface repo: ${PHI_PUBLIC_SURFACE_REPO:-dominion-os-demo-build}
- Official public scope: ${PHI_PUBLIC_SURFACE_SCOPE:-ONLY_PUBLIC_SURFACE}
- Allowed public Cloud Run services in official project: ${PUBLIC_ALLOWLIST}

## GCP Enforcement Results

| Project | Billing Enabled | Cloud Run Services | Publicly Invokable Services | Billing Action | Public Exposure Action |
|---|---|---:|---:|---|---|
EOF2
}

report_append() {
  printf '%s\n' "$*" >> "${REPORT_FILE}"
}

detect_primary_billing_account() {
  if [ -n "${PRIMARY_BILLING_ACCOUNT}" ]; then
    printf '%s\n' "${PRIMARY_BILLING_ACCOUNT}"
    return 0
  fi

  PRIMARY_BILLING_ACCOUNT="$(
    gcloud billing accounts list --filter='open=true' --format='value(ACCOUNT_ID)' 2>/dev/null | head -n 1
  )"
  printf '%s\n' "${PRIMARY_BILLING_ACCOUNT}"
}

list_projects() {
  if [ -n "${ALL_PROJECT_SCOPE}" ]; then
    # shellcheck disable=SC2086
    for p in ${ALL_PROJECT_SCOPE}; do
      [ -n "${p}" ] && printf '%s\n' "${p}"
    done
  else
    gcloud projects list --format='value(projectId)' 2>/dev/null | sed '/^$/d'
  fi
}

project_billing_enabled() {
  local project_id="$1"
  local value
  value="$(
    safe_timeout "${GCLOUD_TIMEOUT_SECONDS}" \
      gcloud billing projects describe "${project_id}" --format='value(billingEnabled)' \
      || true
  )"
  case "${value}" in
    True|true) echo "true" ;;
    False|false) echo "false" ;;
    *) echo "unknown" ;;
  esac
}

service_public_member_count() {
  local project_id="$1"
  local service_name="$2"
  safe_timeout "${GCLOUD_TIMEOUT_SECONDS}" \
    gcloud run services get-iam-policy "${service_name}" \
      --project "${project_id}" \
      --region "${REGION}" \
      --format=json \
    | jq -r '[.bindings[]? | select(.role=="roles/run.invoker") | .members[]? | select(.=="allUsers" or .=="allAuthenticatedUsers")] | length' \
    2>/dev/null || echo "0"
}

remove_public_invoker_bindings() {
  local project_id="$1"
  local service_name="$2"
  local changed=0

  if safe_timeout "${GCLOUD_TIMEOUT_SECONDS}" \
    gcloud run services remove-iam-policy-binding "${service_name}" \
      --project "${project_id}" \
      --region "${REGION}" \
      --member='allUsers' \
      --role='roles/run.invoker' \
      --quiet >/dev/null; then
    changed=1
  fi

  if safe_timeout "${GCLOUD_TIMEOUT_SECONDS}" \
    gcloud run services remove-iam-policy-binding "${service_name}" \
      --project "${project_id}" \
      --region "${REGION}" \
      --member='allAuthenticatedUsers' \
      --role='roles/run.invoker' \
      --quiet >/dev/null; then
    changed=1
  fi

  printf '%s\n' "${changed}"
}

ensure_public_invoker_binding() {
  local project_id="$1"
  local service_name="$2"
  if safe_timeout "${GCLOUD_TIMEOUT_SECONDS}" \
    gcloud run services add-iam-policy-binding "${service_name}" \
      --project "${project_id}" \
      --region "${REGION}" \
      --member='allUsers' \
      --role='roles/run.invoker' \
      --quiet >/dev/null; then
    return 0
  fi
  return 1
}

audit_or_apply() {
  local project_count=0
  local run_service_total=0
  local public_total=0
  local billing_drift_before=0
  local billing_drift_after=0
  local public_drift_before=0
  local public_drift_after=0
  local billing_changes=0
  local public_changes=0
  local allowlist_total=0
  local allowlist_found=0
  local allowlist_public_before=0
  local allowlist_public_after=0
  local allowlist_public_granted=0
  local allowlist_missing_services=0
  local allowlist_public_missing_before=0
  local allowlist_public_missing_after=0

  local billing_action_text="none"
  local exposure_action_text="none"
  local token=""

  for token in ${PUBLIC_ALLOWLIST//,/ }; do
    [ -n "${token}" ] || continue
    allowlist_total=$((allowlist_total + 1))
  done

  local primary_account
  primary_account="$(detect_primary_billing_account)"
  if [ -z "${primary_account}" ]; then
    log WARN "No open billing account detected; billing enforcement will be skipped"
  fi

  list_projects > "${WORK_FILE}"

  while IFS= read -r project_id; do
    [ -n "${project_id}" ] || continue
    project_count=$((project_count + 1))

    local billing_enabled
    local service_count=0
    local public_count=0
    local service_name
    local official_service_names=""

    billing_enabled="$(project_billing_enabled "${project_id}")"
    billing_action_text="none"
    exposure_action_text="none"

    while IFS= read -r service_name; do
      [ -n "${service_name}" ] || continue
      service_count=$((service_count + 1))
      run_service_total=$((run_service_total + 1))
      if [ "${project_id}" = "${OFFICIAL_PUBLIC_PROJECT}" ]; then
        official_service_names="${official_service_names}"$'\n'"${service_name}"
      fi

      local members_count
      members_count="$(service_public_member_count "${project_id}" "${service_name}")"
      local should_be_public=0
      if [ "${project_id}" = "${OFFICIAL_PUBLIC_PROJECT}" ] && csv_has_match "${PUBLIC_ALLOWLIST}" "${service_name}"; then
        should_be_public=1
        allowlist_found=$((allowlist_found + 1))
        if [ "${members_count}" -gt 0 ]; then
          allowlist_public_before=$((allowlist_public_before + 1))
          allowlist_public_after=$((allowlist_public_after + 1))
        else
          allowlist_public_missing_before=$((allowlist_public_missing_before + 1))
          if [ "${MODE}" = "apply" ] && [ "${ENFORCE_ALLOWLIST_PUBLIC}" = "1" ]; then
            if ensure_public_invoker_binding "${project_id}" "${service_name}"; then
              allowlist_public_granted=$((allowlist_public_granted + 1))
              allowlist_public_after=$((allowlist_public_after + 1))
              log INFO "Ensured allowlisted service is public: ${project_id}/${service_name}"
            else
              allowlist_public_missing_after=$((allowlist_public_missing_after + 1))
              log WARN "Failed to ensure allowlisted service is public: ${project_id}/${service_name}"
            fi
          else
            allowlist_public_missing_after=$((allowlist_public_missing_after + 1))
          fi
        fi
      fi

      if [ "${members_count}" -gt 0 ]; then
        public_count=$((public_count + 1))
        public_total=$((public_total + 1))

        if [ "${should_be_public}" -eq 0 ]; then
          public_drift_before=$((public_drift_before + 1))
          if [ "${MODE}" = "apply" ] && [ "${ENFORCE_PUBLIC_LOCKDOWN}" = "1" ]; then
            if [ "$(remove_public_invoker_bindings "${project_id}" "${service_name}")" = "1" ]; then
              public_changes=$((public_changes + 1))
              exposure_action_text="locked_down"
              log INFO "Removed public invoker bindings: ${project_id}/${service_name}"
            else
              exposure_action_text="lockdown_failed"
              public_drift_after=$((public_drift_after + 1))
              log WARN "Failed to remove public invoker bindings: ${project_id}/${service_name}"
            fi
          else
            exposure_action_text="drift_detected"
            public_drift_after=$((public_drift_after + 1))
          fi
        fi
      fi
    done < <(
      safe_timeout "${GCLOUD_TIMEOUT_SECONDS}" \
        gcloud run services list --project "${project_id}" --region "${REGION}" --format='value(metadata.name)' \
        | sed '/^$/d' \
        || true
    )

    if [ "${project_id}" = "${OFFICIAL_PUBLIC_PROJECT}" ]; then
      for token in ${PUBLIC_ALLOWLIST//,/ }; do
        [ -n "${token}" ] || continue
        if ! printf '%s\n' "${official_service_names}" | grep -qx "${token}"; then
          allowlist_missing_services=$((allowlist_missing_services + 1))
          allowlist_public_missing_after=$((allowlist_public_missing_after + 1))
          log WARN "Allowlisted service not found in official project: ${project_id}/${token}"
        fi
      done
    fi

    if [ "${project_id}" != "${OFFICIAL_PUBLIC_PROJECT}" ] && [ "${billing_enabled}" = "true" ]; then
      billing_drift_before=$((billing_drift_before + 1))
      if [ "${MODE}" = "apply" ] && [ "${ENFORCE_SINGLE_BILLING}" = "1" ]; then
        if gcloud billing projects unlink "${project_id}" --quiet >/dev/null 2>&1; then
          billing_changes=$((billing_changes + 1))
          billing_action_text="unlinked"
          log INFO "Unlinked billing from non-official project: ${project_id}"
        else
          billing_action_text="unlink_failed"
          billing_drift_after=$((billing_drift_after + 1))
          log WARN "Failed to unlink billing from non-official project: ${project_id}"
        fi
      else
        billing_action_text="drift_detected"
        billing_drift_after=$((billing_drift_after + 1))
      fi
    fi

    report_append "| ${project_id} | ${billing_enabled} | ${service_count} | ${public_count} | ${billing_action_text} | ${exposure_action_text} |"
  done < "${WORK_FILE}"

  if [ "${MODE}" = "apply" ]; then
    # Final drift re-check in apply mode so status reflects post-enforcement state.
    billing_drift_after=0
    while IFS= read -r project_id; do
      [ -n "${project_id}" ] || continue
      if [ "${project_id}" != "${OFFICIAL_PUBLIC_PROJECT}" ] && [ "$(project_billing_enabled "${project_id}")" = "true" ]; then
        billing_drift_after=$((billing_drift_after + 1))
      fi
    done < "${WORK_FILE}"

    public_drift_after=0
    while IFS= read -r project_id; do
      [ -n "${project_id}" ] || continue
      while IFS= read -r service_name; do
        [ -n "${service_name}" ] || continue
        local members_count
        members_count="$(service_public_member_count "${project_id}" "${service_name}")"
        if [ "${members_count}" -gt 0 ]; then
          local should_be_public=0
          if [ "${project_id}" = "${OFFICIAL_PUBLIC_PROJECT}" ] && csv_has_match "${PUBLIC_ALLOWLIST}" "${service_name}"; then
            should_be_public=1
          fi
          if [ "${should_be_public}" -eq 0 ]; then
            public_drift_after=$((public_drift_after + 1))
          fi
        fi
      done < <(
        safe_timeout "${GCLOUD_TIMEOUT_SECONDS}" \
          gcloud run services list --project "${project_id}" --region "${REGION}" --format='value(metadata.name)' \
          | sed '/^$/d' \
          || true
      )
    done < "${WORK_FILE}"
  fi

  report_append ""
  report_append "## Summary"
  report_append "- Projects scanned: ${project_count}"
  report_append "- Cloud Run services scanned: ${run_service_total}"
  report_append "- Publicly invokable services found: ${public_total}"
  report_append "- Billing drift before: ${billing_drift_before}"
  report_append "- Billing drift after: ${billing_drift_after}"
  report_append "- Billing changes applied: ${billing_changes}"
  report_append "- Public exposure drift before: ${public_drift_before}"
  report_append "- Public exposure drift after: ${public_drift_after}"
  report_append "- Public exposure changes applied: ${public_changes}"
  report_append "- Official allowlist total: ${allowlist_total}"
  report_append "- Official allowlist found: ${allowlist_found}"
  report_append "- Official allowlist public before: ${allowlist_public_before}"
  report_append "- Official allowlist public after: ${allowlist_public_after}"
  report_append "- Official allowlist public grants applied: ${allowlist_public_granted}"
  report_append "- Official allowlist missing services: ${allowlist_missing_services}"
  report_append "- Official allowlist missing public before: ${allowlist_public_missing_before}"
  report_append "- Official allowlist missing public after: ${allowlist_public_missing_after}"

  local overall="PASS"
  if [ "${billing_drift_after}" -gt 0 ] || [ "${public_drift_after}" -gt 0 ] || [ "${allowlist_public_missing_after}" -gt 0 ]; then
    overall="FAIL"
  fi

  cat > "${STATUS_FILE}" <<EOF2
{
  "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "mode": "${MODE}",
  "official_public_project": "${OFFICIAL_PUBLIC_PROJECT}",
  "region": "${REGION}",
  "report_path": "${REPORT_FILE}",
  "log_path": "${LOG_FILE}",
  "overall_status": "${overall}",
  "checks": {
    "single_public_billing_project": "$( [ "${billing_drift_after}" -eq 0 ] && echo PASS || echo FAIL )",
    "nonofficial_public_exposure_locked": "$( [ "${public_drift_after}" -eq 0 ] && echo PASS || echo FAIL )",
    "official_allowlist_public_ready": "$( [ "${allowlist_public_missing_after}" -eq 0 ] && echo PASS || echo FAIL )"
  },
  "metrics": {
    "projects_scanned": ${project_count},
    "cloud_run_services_scanned": ${run_service_total},
    "public_services_found": ${public_total},
    "billing_drift_before": ${billing_drift_before},
    "billing_drift_after": ${billing_drift_after},
    "billing_changes_applied": ${billing_changes},
    "public_drift_before": ${public_drift_before},
    "public_drift_after": ${public_drift_after},
    "public_changes_applied": ${public_changes},
    "allowlist_total": ${allowlist_total},
    "allowlist_found": ${allowlist_found},
    "allowlist_public_before": ${allowlist_public_before},
    "allowlist_public_after": ${allowlist_public_after},
    "allowlist_public_grants_applied": ${allowlist_public_granted},
    "allowlist_missing_services": ${allowlist_missing_services},
    "allowlist_public_missing_before": ${allowlist_public_missing_before},
    "allowlist_public_missing_after": ${allowlist_public_missing_after}
  }
}
EOF2

  log INFO "Cloud governor complete overall=${overall} report=${REPORT_FILE}"
  printf '%s\n' "${REPORT_FILE}"
}

main() {
  case "${MODE}" in
    audit|apply)
      if ! have gcloud || ! have jq; then
        echo "gcloud and jq are required" >&2
        exit 1
      fi
      init_report
      audit_or_apply
      ;;
    status)
      if [ -f "${STATUS_FILE}" ]; then
        cat "${STATUS_FILE}"
      else
        echo '{}'
      fi
      ;;
    -h|--help|help)
      usage
      ;;
    *)
      usage
      exit 1
      ;;
  esac
}

main
