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

OFFICIAL_FLAG="${PHI_PUBLIC_SURFACE_OFFICIAL:-0}"
SURFACE_REPO="${PHI_PUBLIC_SURFACE_REPO:-}"
SURFACE_SCOPE="${PHI_PUBLIC_SURFACE_SCOPE:-}"
PUBLIC_PROJECT="${PHI_PUBLIC_GCP_PROJECT:-}"
PUBLIC_REGION="${PHI_PUBLIC_GCP_REGION:-us-central1}"
DEPLOY_PROJECTS="${PHI_GCLOUD_DEPLOY_PROJECTS:-}"

expected_repo="dominion-os-demo-build"
expected_scope="ONLY_PUBLIC_SURFACE"

is_policy_valid() {
  [ "${OFFICIAL_FLAG}" = "1" ] || return 1
  [ "${SURFACE_REPO}" = "${expected_repo}" ] || return 1
  [ "${SURFACE_SCOPE}" = "${expected_scope}" ] || return 1
  [ -n "${PUBLIC_PROJECT}" ] || return 1

  # Deploy scope must explicitly include only the public project.
  if [ -n "${DEPLOY_PROJECTS}" ]; then
    # shellcheck disable=SC2086
    set -- ${DEPLOY_PROJECTS}
    [ "$#" -eq 1 ] || return 1
    [ "$1" = "${PUBLIC_PROJECT}" ] || return 1
  fi
  return 0
}

status_json() {
  local state="invalid"
  if is_policy_valid; then
    state="valid"
  fi
  cat <<EOF
{
  "public_surface_policy": "${state}",
  "official_flag": "${OFFICIAL_FLAG}",
  "public_repo": "${SURFACE_REPO}",
  "public_scope": "${SURFACE_SCOPE}",
  "public_project": "${PUBLIC_PROJECT}",
  "public_region": "${PUBLIC_REGION}",
  "deploy_projects": "${DEPLOY_PROJECTS}"
}
EOF
}

usage() {
  cat <<'EOF'
Usage: public_surface_guard.sh [status|assert]

status  Print public-surface policy state JSON.
assert  Exit 0 when policy is valid.
EOF
}

case "${1:-status}" in
  status)
    status_json
    ;;
  assert)
    is_policy_valid
    ;;
  -h|--help|help)
    usage
    ;;
  *)
    usage
    exit 1
    ;;
esac
