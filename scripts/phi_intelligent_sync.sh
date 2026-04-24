#!/usr/bin/env bash
set -euo pipefail

# PHI Intelligent Sync
# Local-first sync with branch-aware push, lock protection, and retry logic.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
SYNC_ENV_FILE="${PHI_SYNC_ENV_FILE:-${SCRIPT_DIR}/live_ops_sync.env}"
if [ -f "${SYNC_ENV_FILE}" ]; then
  set -a
  # shellcheck disable=SC1090
  . "${SYNC_ENV_FILE}"
  set +a
fi
TELEMETRY_DIR="${SCRIPT_DIR}/telemetry"
LOG="${TELEMETRY_DIR}/intelligent_sync.log"
LOCK_FILE="${TELEMETRY_DIR}/intelligent_sync.lock"
HEARTBEAT_FILE="${TELEMETRY_DIR}/.last_intelligent_sync"

SYNC_REMOTE="${PHI_SYNC_REMOTE:-}"
SYNC_BRANCH="${PHI_SYNC_BRANCH:-}"
SYNC_MAX_RETRIES="${PHI_SYNC_MAX_RETRIES:-3}"
SYNC_RETRY_SECONDS="${PHI_SYNC_RETRY_SECONDS:-2}"
SYNC_ALLOW_AUTOCOMMIT="${PHI_SYNC_ALLOW_AUTOCOMMIT:-0}"
SYNC_PUSH_ENABLED="${PHI_SYNC_PUSH_ENABLED:-1}"
SYNC_ENFORCE_CONTROLLED_TARGET="${PHI_SYNC_ENFORCE_CONTROLLED_TARGET:-1}"
SYNC_CONTROLLED_REMOTE="${PHI_SYNC_CONTROLLED_REMOTE:-fork}"
SYNC_CONTROLLED_BRANCH="${PHI_SYNC_CONTROLLED_BRANCH:-live-ops-sync}"
SYNC_REBASE_ON_REMOTE_AHEAD="${PHI_SYNC_REBASE_ON_REMOTE_AHEAD:-1}"
SYNC_WORKFLOW_SCOPE_FALLBACK_ENABLED="${PHI_SYNC_WORKFLOW_SCOPE_FALLBACK_ENABLED:-1}"
SYNC_WORKFLOW_FALLBACK_BRANCH="${PHI_SYNC_WORKFLOW_FALLBACK_BRANCH:-live-ops-sync-safe}"
SYNC_WORKFLOW_FALLBACK_BASE_BRANCH="${PHI_SYNC_WORKFLOW_FALLBACK_BASE_BRANCH:-main}"
SYNC_REPLICATION_ONLY_ON_PUSH="${PHI_SYNC_REPLICATION_ONLY_ON_PUSH:-0}"

SYNC_LOCAL_MIRROR_ENABLED="${PHI_SYNC_LOCAL_MIRROR_ENABLED:-1}"
SYNC_LOCAL_MIRROR_MODE="${PHI_SYNC_LOCAL_MIRROR_MODE:-targeted}"
SYNC_LOCAL_SOURCE_ROOT_RAW="${PHI_SYNC_LOCAL_SOURCE_ROOT:-${REPO_DIR}}"
SYNC_LOCAL_MIRROR_PATH_RAW="${PHI_SYNC_LOCAL_MIRROR_PATH:-D:\\workspaces\\dominion-os-demo-build-live}"
SYNC_LOCAL_MIRROR_FALLBACK_PATH_RAW="${PHI_SYNC_LOCAL_MIRROR_FALLBACK_PATH:-/workspaces/dominion-os-demo-build-live}"
SYNC_LOCAL_MIRROR_PATHS="${PHI_SYNC_LOCAL_MIRROR_PATHS:-scripts/telemetry dist/command_core reports}"
SYNC_LOCAL_MIRROR_EXCLUDES="${PHI_SYNC_LOCAL_MIRROR_EXCLUDES:-.git/ logs/ scripts/logs/ .venv/ node_modules/}"
SYNC_LOCAL_MIRROR_MIN_INTERVAL_SECONDS="${PHI_SYNC_LOCAL_MIRROR_MIN_INTERVAL_SECONDS:-30}"
SYNC_LOCAL_MIRROR_HEARTBEAT_FILE="${TELEMETRY_DIR}/.last_local_mirror_sync"

SYNC_GCS_ENABLED="${PHI_SYNC_GCS_ENABLED:-1}"
SYNC_GCS_BUCKET="${PHI_SYNC_GCS_BUCKET:-}"
SYNC_GCS_PREFIX="${PHI_SYNC_GCS_PREFIX:-dominion-live-ops}"
SYNC_GCS_SOURCE_ROOT_RAW="${PHI_SYNC_GCS_SOURCE_ROOT:-${SYNC_LOCAL_SOURCE_ROOT_RAW}}"
SYNC_GCS_INCLUDE_PATHS="${PHI_SYNC_GCS_INCLUDE_PATHS:-scripts/telemetry dist/command_core reports}"
SYNC_GCS_EXCLUDE_REGEX="${PHI_SYNC_GCS_EXCLUDE_REGEX:-(^|/)(\\.git/|logs/|scripts/logs/)|\\.(tmp|swp|pid)$}"
SYNC_GCS_DELETE_UNMATCHED="${PHI_SYNC_GCS_DELETE_UNMATCHED:-0}"
SYNC_GCS_PARALLEL="${PHI_SYNC_GCS_PARALLEL:-1}"
SYNC_GCS_CHANGED_ONLY="${PHI_SYNC_GCS_CHANGED_ONLY:-1}"
SYNC_GCS_MIN_INTERVAL_SECONDS="${PHI_SYNC_GCS_MIN_INTERVAL_SECONDS:-300}"
SYNC_GCS_MAX_FILES="${PHI_SYNC_GCS_MAX_FILES:-20000}"
SYNC_GCS_MANIFEST_FILE="${TELEMETRY_DIR}/.last_gcs_manifest"
SYNC_GCS_HEARTBEAT_FILE="${TELEMETRY_DIR}/.last_gcs_sync"
SYNC_GCS_HARD_FAIL="${PHI_SYNC_GCS_HARD_FAIL:-0}"

mkdir -p "${TELEMETRY_DIR}"

log() {
  printf '[%s] %s\n' "$(date -u +'%Y-%m-%dT%H:%M:%SZ')" "$1" >> "${LOG}"
}

mark_sync_heartbeat() {
  date -u +'%Y-%m-%dT%H:%M:%SZ' > "${HEARTBEAT_FILE}"
}

with_lock_or_exit() {
  exec 9>"${LOCK_FILE}"
  if command -v flock >/dev/null 2>&1; then
    if ! flock -n 9; then
      log "Sync skipped: another intelligent sync process is active"
      mark_sync_heartbeat
      exit 0
    fi
  fi
}

is_https_remote() {
  local remote_url="$1"
  [[ "${remote_url}" =~ ^https:// ]]
}

is_truthy() {
  case "${1:-}" in
    1|true|TRUE|yes|YES|on|ON) return 0 ;;
    *) return 1 ;;
  esac
}

is_production_env() {
  local env_value="${PHI_ENVIRONMENT:-${PHI_ENV:-${ENVIRONMENT:-}}}"
  env_value="$(printf '%s' "${env_value}" | tr '[:upper:]' '[:lower:]')"
  case "${env_value}" in
    prod|production|live_ops|live-ops) return 0 ;;
    *) return 1 ;;
  esac
}

working_tree_dirty() {
  ! git diff --quiet || ! git diff --cached --quiet
}

to_unix_path() {
  local input="${1:-}"
  local drive=""
  local rest=""
  if [[ "${input}" =~ ^([A-Za-z]):\\(.*)$ ]]; then
    drive="$(printf '%s' "${BASH_REMATCH[1]}" | tr '[:upper:]' '[:lower:]')"
    rest="${BASH_REMATCH[2]//\\//}"
    printf '/mnt/%s/%s\n' "${drive}" "${rest}"
    return 0
  fi
  printf '%s\n' "${input}"
}

normalize_existing_dir() {
  local raw_path="${1:-}"
  local normalized=""
  [ -n "${raw_path}" ] || return 1
  normalized="$(to_unix_path "${raw_path}")"
  if [ -d "${normalized}" ]; then
    printf '%s\n' "${normalized}"
    return 0
  fi
  return 1
}

normalize_or_default_dir() {
  local raw_path="${1:-}"
  local default_path="${2:-}"
  normalize_existing_dir "${raw_path}" || printf '%s\n' "${default_path}"
}

should_run_interval_task() {
  local heartbeat_file="$1"
  local min_interval="$2"
  local now_epoch last_epoch

  [ "${min_interval}" -gt 0 ] || return 0
  now_epoch="$(date +%s)"
  if [ -f "${heartbeat_file}" ]; then
    last_epoch="$(cat "${heartbeat_file}" 2>/dev/null || echo 0)"
  else
    last_epoch=0
  fi
  [[ "${last_epoch}" =~ ^[0-9]+$ ]] || last_epoch=0
  if [ $(( now_epoch - last_epoch )) -lt "${min_interval}" ]; then
    return 1
  fi
  return 0
}

mark_interval_heartbeat() {
  local heartbeat_file="$1"
  date +%s > "${heartbeat_file}"
}

collect_include_paths() {
  local raw="${1:-}"
  local item=""
  raw="${raw//,/ }"
  for item in ${raw}; do
    [ -n "${item}" ] || continue
    printf '%s\n' "${item}"
  done
}

collect_excludes() {
  local raw="${1:-}"
  local item=""
  raw="${raw//,/ }"
  for item in ${raw}; do
    [ -n "${item}" ] || continue
    printf '%s\n' "${item}"
  done
}

sync_local_mirror() {
  local source_root target_root exclude item
  local mount_root=""
  local rsync_args=()
  local rel_path source_path dest_path
  local had_error=0

  is_truthy "${SYNC_LOCAL_MIRROR_ENABLED}" || return 0
  source_root="$(normalize_or_default_dir "${SYNC_LOCAL_SOURCE_ROOT_RAW}" "${REPO_DIR}")"
  target_root="$(to_unix_path "${SYNC_LOCAL_MIRROR_PATH_RAW}")"
  [ -n "${target_root}" ] || return 0
  [ "${source_root}" != "${target_root}" ] || return 0

  if [[ "${target_root}" =~ ^/mnt/([^/]+)(/.*)?$ ]]; then
    mount_root="/mnt/${BASH_REMATCH[1]}"
    if [ ! -d "${mount_root}" ]; then
      local fallback_root=""
      fallback_root="$(to_unix_path "${SYNC_LOCAL_MIRROR_FALLBACK_PATH_RAW}")"
      if [ -n "${fallback_root}" ] && [ "${fallback_root}" != "${target_root}" ]; then
        log "Local mirror mount unavailable (${mount_root}); using fallback target ${fallback_root}"
        target_root="${fallback_root}"
      else
        log "Local mirror sync skipped: mount root unavailable (${mount_root})"
        return 0
      fi
    fi
  fi

  if ! should_run_interval_task "${SYNC_LOCAL_MIRROR_HEARTBEAT_FILE}" "${SYNC_LOCAL_MIRROR_MIN_INTERVAL_SECONDS}"; then
    log "Local mirror sync skipped: min interval ${SYNC_LOCAL_MIRROR_MIN_INTERVAL_SECONDS}s not reached"
    return 0
  fi

  if ! command -v rsync >/dev/null 2>&1; then
    log "Local mirror sync skipped: rsync not installed"
    return 0
  fi

  mkdir -p "${target_root}" || {
    log "Local mirror sync skipped: cannot create target ${target_root}"
    return 0
  }

  rsync_args=(-a --human-readable)
  while IFS= read -r exclude; do
    rsync_args+=(--exclude "${exclude}")
  done < <(collect_excludes "${SYNC_LOCAL_MIRROR_EXCLUDES}")

  if [ "${SYNC_LOCAL_MIRROR_MODE}" = "targeted" ]; then
    while IFS= read -r rel_path; do
      [ -n "${rel_path}" ] || continue
      source_path="${source_root}/${rel_path}"
      dest_path="${target_root}/${rel_path}"
      [ -e "${source_path}" ] || continue

      if [ -d "${source_path}" ]; then
        mkdir -p "${dest_path}" || true
        if ! rsync "${rsync_args[@]}" --delete --delete-delay "${source_path}/" "${dest_path}/" >> "${LOG}" 2>&1; then
          had_error=1
          log "Local mirror targeted sync failed for ${rel_path}"
        fi
      else
        mkdir -p "$(dirname "${dest_path}")" || true
        if ! rsync "${rsync_args[@]}" "${source_path}" "${dest_path}" >> "${LOG}" 2>&1; then
          had_error=1
          log "Local mirror targeted sync failed for ${rel_path}"
        fi
      fi
    done < <(collect_include_paths "${SYNC_LOCAL_MIRROR_PATHS}")
  else
    if ! rsync "${rsync_args[@]}" --delete --delete-delay "${source_root}/" "${target_root}/" >> "${LOG}" 2>&1; then
      log "Local mirror sync failed: ${source_root} -> ${target_root}"
      return 1
    fi
  fi

  if [ "${had_error}" -eq 0 ]; then
    log "Local mirror sync complete (${SYNC_LOCAL_MIRROR_MODE}): ${source_root} -> ${target_root}"
    mark_interval_heartbeat "${SYNC_LOCAL_MIRROR_HEARTBEAT_FILE}"
    return 0
  fi

  log "Local mirror sync completed with errors (${SYNC_LOCAL_MIRROR_MODE}): ${source_root} -> ${target_root}"
  return 1
}

compute_tree_manifest() {
  local source_root="$1"
  local include_paths="$2"
  local exclude_regex="$3"
  local max_files="$4"

  python3 - "${source_root}" "${include_paths}" "${exclude_regex}" "${max_files}" <<'PY'
import hashlib
import os
import re
import sys

source_root = sys.argv[1]
include_paths = [p for p in sys.argv[2].replace(",", " ").split() if p.strip()]
exclude_regex = sys.argv[3]
max_files = int(sys.argv[4]) if sys.argv[4].isdigit() else 20000

matcher = re.compile(exclude_regex) if exclude_regex else None
entries = []
count = 0

for rel_path in include_paths:
    abs_path = os.path.join(source_root, rel_path)
    if not os.path.exists(abs_path):
        continue

    if os.path.isfile(abs_path):
        rel_file = os.path.relpath(abs_path, source_root).replace("\\", "/")
        if matcher and matcher.search(rel_file):
            continue
        st = os.stat(abs_path)
        entries.append(f"{rel_file}\t{st.st_size}\t{int(st.st_mtime)}")
        count += 1
        continue

    for dirpath, _, files in os.walk(abs_path):
        files.sort()
        for filename in files:
            file_path = os.path.join(dirpath, filename)
            rel_file = os.path.relpath(file_path, source_root).replace("\\", "/")
            if matcher and matcher.search(rel_file):
                continue
            st = os.stat(file_path)
            entries.append(f"{rel_file}\t{st.st_size}\t{int(st.st_mtime)}")
            count += 1
            if count > max_files:
                print("OVERFLOW")
                raise SystemExit(3)

entries.sort()
digest = hashlib.sha256("\n".join(entries).encode("utf-8")).hexdigest()
print(f"{digest}\t{count}")
PY
}

build_gcs_base_uri() {
  local bucket="${SYNC_GCS_BUCKET}"
  local prefix="${SYNC_GCS_PREFIX#/}"
  prefix="${prefix%/}"
  if [ -n "${prefix}" ]; then
    printf 'gs://%s/%s\n' "${bucket}" "${prefix}"
    return 0
  fi
  printf 'gs://%s\n' "${bucket}"
}

sync_path_to_gcs() {
  local source_root="$1"
  local rel_path="$2"
  local source_path="${source_root}/${rel_path}"
  local gcs_base_uri="$3"
  local dest_uri="${gcs_base_uri}/${rel_path}"
  local -a cmd=()

  [ -e "${source_path}" ] || return 0

  if command -v gsutil >/dev/null 2>&1; then
    if is_truthy "${SYNC_GCS_PARALLEL}"; then
      cmd=(gsutil -m)
    else
      cmd=(gsutil)
    fi

    if [ -d "${source_path}" ]; then
      cmd+=(rsync -r)
      if is_truthy "${SYNC_GCS_DELETE_UNMATCHED}"; then
        cmd+=(-d)
      fi
      if [ -n "${SYNC_GCS_EXCLUDE_REGEX}" ]; then
        cmd+=(-x "${SYNC_GCS_EXCLUDE_REGEX}")
      fi
      cmd+=("${source_path}" "${dest_uri}")
    else
      cmd+=(cp "${source_path}" "${dest_uri}")
    fi
  elif command -v gcloud >/dev/null 2>&1; then
    if [ -d "${source_path}" ]; then
      cmd=(gcloud storage rsync --recursive)
      if is_truthy "${SYNC_GCS_DELETE_UNMATCHED}"; then
        cmd+=(--delete-unmatched-destination-objects)
      fi
      cmd+=("${source_path}" "${dest_uri}")
    else
      cmd=(gcloud storage cp "${source_path}" "${dest_uri}")
    fi
  else
    log "GCS sync skipped: neither gsutil nor gcloud is available"
    return 1
  fi

  if "${cmd[@]}" >> "${LOG}" 2>&1; then
    return 0
  fi
  return 1
}

sync_to_gcs() {
  local source_root gcs_base_uri
  local manifest_line=""
  local current_hash="" current_count=""
  local previous_hash=""
  local rel_path
  local had_sync_error=0

  is_truthy "${SYNC_GCS_ENABLED}" || return 0
  if [ -z "${SYNC_GCS_BUCKET}" ]; then
    log "GCS sync skipped: PHI_SYNC_GCS_BUCKET is not set"
    return 0
  fi

  source_root="$(normalize_or_default_dir "${SYNC_GCS_SOURCE_ROOT_RAW}" "${REPO_DIR}")"
  if [ ! -d "${source_root}" ]; then
    log "GCS sync skipped: source root not found (${source_root})"
    return 0
  fi

  if ! should_run_interval_task "${SYNC_GCS_HEARTBEAT_FILE}" "${SYNC_GCS_MIN_INTERVAL_SECONDS}"; then
    log "GCS sync skipped: min interval ${SYNC_GCS_MIN_INTERVAL_SECONDS}s not reached"
    return 0
  fi

  if command -v python3 >/dev/null 2>&1; then
    manifest_line="$(compute_tree_manifest "${source_root}" "${SYNC_GCS_INCLUDE_PATHS}" "${SYNC_GCS_EXCLUDE_REGEX}" "${SYNC_GCS_MAX_FILES}" 2>/dev/null || true)"
    if [ "${manifest_line}" = "OVERFLOW" ]; then
      log "GCS sync manifest overflow (> ${SYNC_GCS_MAX_FILES} files); forcing sync sweep"
      manifest_line=""
    fi
  fi

  if [ -n "${manifest_line}" ]; then
    IFS=$'\t' read -r current_hash current_count <<< "${manifest_line}"
    if [ -f "${SYNC_GCS_MANIFEST_FILE}" ]; then
      previous_hash="$(cat "${SYNC_GCS_MANIFEST_FILE}" 2>/dev/null || true)"
    fi
    if is_truthy "${SYNC_GCS_CHANGED_ONLY}" && [ -n "${current_hash}" ] && [ "${current_hash}" = "${previous_hash}" ]; then
      log "GCS sync skipped: no material changes detected (${current_count} files indexed)"
      mark_interval_heartbeat "${SYNC_GCS_HEARTBEAT_FILE}"
      return 0
    fi
  fi

  gcs_base_uri="$(build_gcs_base_uri)"
  while IFS= read -r rel_path; do
    [ -n "${rel_path}" ] || continue
    if ! sync_path_to_gcs "${source_root}" "${rel_path}" "${gcs_base_uri}"; then
      had_sync_error=1
      log "GCS sync failed for ${rel_path}"
    fi
  done < <(collect_include_paths "${SYNC_GCS_INCLUDE_PATHS}")

  if [ "${had_sync_error}" -eq 1 ]; then
    if is_truthy "${SYNC_GCS_HARD_FAIL}"; then
      return 1
    fi
    log "GCS sync completed with errors (non-fatal)"
    return 0
  fi

  if [ -n "${current_hash}" ]; then
    printf '%s\n' "${current_hash}" > "${SYNC_GCS_MANIFEST_FILE}"
  fi
  mark_interval_heartbeat "${SYNC_GCS_HEARTBEAT_FILE}"
  log "GCS sync complete to ${gcs_base_uri}"
  return 0
}

run_replication_phase() {
  local phase="${1:-post-sync}"

  if is_truthy "${SYNC_REPLICATION_ONLY_ON_PUSH}" && [ "${phase}" != "push" ] && [ "${phase}" != "fallback-push" ]; then
    return 0
  fi

  if ! sync_local_mirror; then
    log "Replication warning: local mirror sync failed during phase=${phase}"
  fi

  if ! sync_to_gcs; then
    log "Replication warning: GCS sync failed during phase=${phase}"
  fi
}

detect_sync_remote() {
  if [ -n "${SYNC_REMOTE}" ]; then
    printf '%s\n' "${SYNC_REMOTE}"
    return
  fi

  if git remote get-url fork >/dev/null 2>&1; then
    printf 'fork\n'
    return
  fi

  if git remote get-url origin >/dev/null 2>&1; then
    printf 'origin\n'
    return
  fi

  printf '\n'
}

trim_credential_value() {
  local value="$1"
  # Normalize carriage returns/newlines from env files and secret stores.
  value="$(printf '%s' "${value}" | tr -d '\r' | tr -d '\n')"
  # Trim leading/trailing whitespace.
  value="$(printf '%s' "${value}" | sed -E 's/^[[:space:]]+//; s/[[:space:]]+$//')"
  value="${value%\"}"
  value="${value#\"}"
  value="${value%\'}"
  value="${value#\'}"
  printf '%s\n' "${value}"
}

emit_credential_candidate() {
  local source="$1"
  local username="$2"
  local token="$3"
  token="$(trim_credential_value "${token}")"
  if [ -z "${token}" ]; then
    return
  fi
  printf '%s\t%s\t%s\n' "${source}" "${username}" "${token}"
}

credentials_from_env() {
  emit_credential_candidate "env:PHI_SYNC_GITHUB_TOKEN" "x-access-token" "${PHI_SYNC_GITHUB_TOKEN:-}"
  emit_credential_candidate "env:GITHUB_TOKEN" "x-access-token" "${GITHUB_TOKEN:-}"
  emit_credential_candidate "env:GH_TOKEN" "x-access-token" "${GH_TOKEN:-}"
}

credentials_from_env_files() {
  local token_files
  token_files="${PHI_SYNC_TOKEN_FILES:-${SCRIPT_DIR}/.env:${REPO_DIR}/.env.mcp:${REPO_DIR}/.env}"
  local file var token

  IFS=':' read -r -a files <<< "${token_files}"
  for file in "${files[@]}"; do
    [ -f "${file}" ] || continue
    for var in GITHUB_TOKEN GH_TOKEN PHI_GITHUB_PAT; do
      token="$(sed -n -E "s/^(export[[:space:]]+)?${var}=(.*)$/\\2/p" "${file}" | head -n1)"
      emit_credential_candidate "file:${file}:${var}" "x-access-token" "${token}"
    done
  done
}

credentials_from_git_stores() {
  local store_file line username token
  for store_file in "${HOME}/.git-credentials" "${HOME}/.git-credentials.backup"; do
    [ -f "${store_file}" ] || continue
    while IFS= read -r line; do
      [[ "${line}" == https://*github.com* ]] || continue
      username="$(printf '%s' "${line}" | sed -n 's|https://\([^:]*\):.*|\1|p')"
      token="$(printf '%s' "${line}" | sed -n 's|https://[^:]*:\([^@]*\)@github.com.*|\1|p')"
      emit_credential_candidate "store:${store_file}" "${username}" "${token}"
    done < "${store_file}"
  done
}

credentials_from_gh_hosts() {
  local hosts_file="${HOME}/.config/gh/hosts.yml"
  local token
  [ -f "${hosts_file}" ] || return
  token="$(sed -n -E 's/^[[:space:]]*oauth_token:[[:space:]]*(.*)$/\1/p' "${hosts_file}" | head -n1)"
  emit_credential_candidate "gh-hosts:${hosts_file}" "x-access-token" "${token}"
}

resolve_authorized_user_adc_path() {
  local path=""
  local candidates=()

  if [ -n "${PHI_SYNC_ADC_PATH:-}" ]; then
    candidates+=("${PHI_SYNC_ADC_PATH}")
  fi
  if [ -n "${GOOGLE_APPLICATION_CREDENTIALS:-}" ]; then
    candidates+=("${GOOGLE_APPLICATION_CREDENTIALS}")
  fi
  candidates+=(
    "${HOME}/.cache/google-vscode-extension/auth/application_default_credentials.json"
    "${HOME}/.config/gcloud/application_default_credentials.json"
  )

  for path in "${candidates[@]}"; do
    [ -n "${path}" ] || continue
    [ -f "${path}" ] || continue
    printf '%s\n' "${path}"
    return 0
  done

  return 1
}

refresh_access_token_from_authorized_user_adc() {
  local adc_path="$1"
  local timeout_seconds="$2"

  timeout "${timeout_seconds}" python3 - "${adc_path}" "${timeout_seconds}" <<'PY'
import json
import sys
import urllib.error
import urllib.parse
import urllib.request

adc_path = sys.argv[1]
timeout_seconds = max(1, int(sys.argv[2]))

try:
    with open(adc_path, "r", encoding="utf-8") as fh:
        adc = json.load(fh)
except Exception:
    raise SystemExit(1)

if adc.get("type") != "authorized_user":
    raise SystemExit(1)

client_id = (adc.get("client_id") or "").strip()
client_secret = (adc.get("client_secret") or "").strip()
refresh_token = (adc.get("refresh_token") or "").strip()
if not client_id or not client_secret or not refresh_token:
    raise SystemExit(1)

data = urllib.parse.urlencode(
    {
        "client_id": client_id,
        "client_secret": client_secret,
        "refresh_token": refresh_token,
        "grant_type": "refresh_token",
    }
).encode("utf-8")

request = urllib.request.Request("https://oauth2.googleapis.com/token", data=data, method="POST")
try:
    with urllib.request.urlopen(request, timeout=timeout_seconds) as response:
        token_payload = json.loads(response.read().decode("utf-8"))
except (urllib.error.HTTPError, urllib.error.URLError, json.JSONDecodeError):
    raise SystemExit(1)

access_token = (token_payload.get("access_token") or "").strip()
if not access_token:
    raise SystemExit(1)

project = (adc.get("quota_project_id") or adc.get("project_id") or "").strip()
print(access_token + "\t" + project)
PY
}

access_gcp_secret_via_rest() {
  local access_token="$1"
  local project="$2"
  local secret_name="$3"
  local timeout_seconds="$4"

  timeout "${timeout_seconds}" python3 - "${access_token}" "${project}" "${secret_name}" "${timeout_seconds}" <<'PY'
import base64
import json
import sys
import urllib.error
import urllib.parse
import urllib.request

access_token = sys.argv[1]
project = sys.argv[2]
secret_name = sys.argv[3]
timeout_seconds = max(1, int(sys.argv[4]))

path_project = urllib.parse.quote(project, safe="")
path_secret = urllib.parse.quote(secret_name, safe="")
url = (
    "https://secretmanager.googleapis.com/v1/projects/"
    + path_project
    + "/secrets/"
    + path_secret
    + "/versions/latest:access"
)

request = urllib.request.Request(url, headers={"Authorization": "Bearer " + access_token})
try:
    with urllib.request.urlopen(request, timeout=timeout_seconds) as response:
        body = json.loads(response.read().decode("utf-8"))
except (urllib.error.HTTPError, urllib.error.URLError, json.JSONDecodeError):
    raise SystemExit(1)

encoded = (((body.get("payload") or {}).get("data")) or "").strip()
if not encoded:
    raise SystemExit(1)

padding = "=" * (-len(encoded) % 4)
try:
    secret_value = base64.b64decode(encoded + padding).decode("utf-8")
except Exception:
    raise SystemExit(1)

print(secret_value)
PY
}

credentials_from_gcloud_secret_manager() {
  local gcp_lookup_enabled="${PHI_SYNC_GCP_LOOKUP_ENABLED:-1}"
  local gcp_rest_fallback_enabled="${PHI_SYNC_GCP_REST_FALLBACK_ENABLED:-1}"
  local secret_names="${PHI_SYNC_GCP_SECRET_NAMES:-GITHUB_TOKEN,GITHUB_PAT,PHI_GITHUB_PAT,github-pat,dominion-github-github-oauthtoken-57a2ca}"
  local project="${PHI_SYNC_GCP_SECRET_PROJECT:-}"
  local gcp_timeout_seconds="${PHI_SYNC_GCP_TIMEOUT_SECONDS:-4}"
  local secret_name token adc_path adc_refresh auth_access_token adc_project
  local -a gcp_secrets=()

  [ "${gcp_lookup_enabled}" = "1" ] || return
  [ -n "${secret_names}" ] || return

  IFS=',' read -r -a gcp_secrets <<< "${secret_names}"

  if [ -z "${project}" ] && command -v gcloud >/dev/null 2>&1; then
    project="$(gcloud config get-value project 2>/dev/null || true)"
  fi

  if command -v gcloud >/dev/null 2>&1; then
    for secret_name in "${gcp_secrets[@]}"; do
      secret_name="$(printf '%s' "${secret_name}" | xargs)"
      [ -n "${secret_name}" ] || continue
      if [ -n "${project}" ]; then
        token="$(timeout "${gcp_timeout_seconds}" gcloud secrets versions access latest --secret="${secret_name}" --project="${project}" 2>/dev/null || true)"
      else
        token="$(timeout "${gcp_timeout_seconds}" gcloud secrets versions access latest --secret="${secret_name}" 2>/dev/null || true)"
      fi
      emit_credential_candidate "gcp-secret:${secret_name}" "x-access-token" "${token}"
    done
  fi

  if [ "${gcp_rest_fallback_enabled}" != "1" ]; then
    return
  fi
  if ! command -v python3 >/dev/null 2>&1; then
    return
  fi

  adc_path="$(resolve_authorized_user_adc_path || true)"
  [ -n "${adc_path}" ] || return

  adc_refresh="$(refresh_access_token_from_authorized_user_adc "${adc_path}" "${gcp_timeout_seconds}" || true)"
  [ -n "${adc_refresh}" ] || return

  IFS=$'\t' read -r auth_access_token adc_project <<< "${adc_refresh}"
  auth_access_token="$(trim_credential_value "${auth_access_token}")"
  adc_project="$(trim_credential_value "${adc_project}")"
  [ -n "${auth_access_token}" ] || return

  if [ -z "${project}" ]; then
    project="${adc_project}"
  fi
  [ -n "${project}" ] || return

  for secret_name in "${gcp_secrets[@]}"; do
    secret_name="$(printf '%s' "${secret_name}" | xargs)"
    [ -n "${secret_name}" ] || continue
    token="$(access_gcp_secret_via_rest "${auth_access_token}" "${project}" "${secret_name}" "${gcp_timeout_seconds}" || true)"
    if [ -n "${token}" ]; then
      emit_credential_candidate "gcp-secret-rest:${secret_name}" "x-access-token" "${token}"
      continue
    fi
    # ADC may be valid while specific secret names are absent or unauthorized.
    if is_truthy "${PHI_SYNC_GCP_REST_VERBOSE:-0}"; then
      log "GCP Secret Manager REST lookup failed for ${secret_name} (project=${project})"
    fi
  done
}

discover_credential_candidates() {
  credentials_from_env
  credentials_from_env_files
  credentials_from_git_stores
  credentials_from_gh_hosts
  credentials_from_gcloud_secret_manager
}

build_auth_remote() {
  local remote_url="$1"
  local username="$2"
  local token="$3"
  local remote_host_path
  local token_encoded

  remote_host_path="$(printf '%s' "${remote_url}" | sed -E 's#^https://([^@/]+@)?##')"
  token_encoded="$(
    python3 -c 'import sys, urllib.parse; print(urllib.parse.quote(sys.argv[1], safe=""))' "${token}" \
      2>/dev/null || true
  )"
  [ -n "${token_encoded}" ] || token_encoded="${token}"
  printf 'https://%s:%s@%s\n' "${username}" "${token_encoded}" "${remote_host_path}"
}

select_https_push_remote() {
  local remote_url="$1"
  local target_branch="$2"
  local source username token auth_remote
  local seen_tokens='|'

  while IFS=$'\t' read -r source username token; do
    [ -n "${token}" ] || continue
    if [[ "${seen_tokens}" == *"|${token}|"* ]]; then
      continue
    fi
    seen_tokens="${seen_tokens}${token}|"
    [ -n "${username}" ] || username="x-access-token"

    auth_remote="$(build_auth_remote "${remote_url}" "${username}" "${token}")"
    if push_preflight "${auth_remote}" "${target_branch}"; then
      log "Credential source selected: ${source}"
      printf '%s\n' "${auth_remote}"
      return 0
    fi

    log "Credential source failed preflight: ${source}"
  done < <(discover_credential_candidates)

  return 1
}

push_with_retry() {
  local push_remote="$1"
  local target_branch="$2"
  local attempt=1

  while [ "${attempt}" -le "${SYNC_MAX_RETRIES}" ]; do
    if git push "${push_remote}" "HEAD:${target_branch}" >> "${LOG}" 2>&1; then
      log "Push successful to ${target_branch} on attempt ${attempt}"
      return 0
    fi

    if [ "${attempt}" -lt "${SYNC_MAX_RETRIES}" ]; then
      local backoff=$(( SYNC_RETRY_SECONDS * attempt ))
      log "Push attempt ${attempt} failed; retrying in ${backoff}s"
      sleep "${backoff}"
    fi

    attempt=$((attempt + 1))
  done

  log "Push failed after ${SYNC_MAX_RETRIES} attempts"
  return 1
}

push_preflight() {
  local push_remote="$1"
  local target_branch="$2"

  if git push --dry-run "${push_remote}" "HEAD:${target_branch}" >> "${LOG}" 2>&1; then
    return 0
  fi
  return 1
}

push_preflight_or_skip() {
  local push_remote="$1"
  local target_branch="$2"
  local display_remote="${3:-remote}"
  if push_preflight "${push_remote}" "${target_branch}"; then
    return 0
  fi
  log "Push preflight failed for ${display_remote}/${target_branch}; skipping push (credentials likely lack write access)"
  return 1
}

workflow_scope_error_detected() {
  tail -n 120 "${LOG}" | grep -Fq "without \`workflow\` scope"
}

determine_nonworkflow_base_ref() {
  local primary_ref="refs/remotes/${SYNC_REMOTE}/${SYNC_BRANCH}"
  local fallback_base_ref="refs/remotes/${SYNC_REMOTE}/${SYNC_WORKFLOW_FALLBACK_BASE_BRANCH}"

  if git show-ref --verify --quiet "${primary_ref}"; then
    printf '%s\n' "${SYNC_REMOTE}/${SYNC_BRANCH}"
    return 0
  fi

  if git show-ref --verify --quiet "${fallback_base_ref}"; then
    printf '%s\n' "${SYNC_REMOTE}/${SYNC_WORKFLOW_FALLBACK_BASE_BRANCH}"
    return 0
  fi

  return 1
}

push_nonworkflow_fallback_snapshot() {
  local push_remote="$1"
  local base_ref="$2"
  local fallback_branch="$3"
  local fallback_branch_name=""
  local fallback_remote_ref=""
  local worktree_base_ref=""
  local fallback_ref=""
  local tmp_root=""
  local fallback_worktree=""
  local patch_file=""
  local ts=""
  local attempt=1

  if ! git diff --name-only "${base_ref}..HEAD" -- ".github/workflows" | grep -q .; then
    return 1
  fi

  if [[ "${fallback_branch}" == refs/* ]]; then
    fallback_ref="${fallback_branch}"
    fallback_branch_name="${fallback_branch#refs/heads/}"
  else
    fallback_ref="refs/heads/${fallback_branch}"
    fallback_branch_name="${fallback_branch}"
  fi

  fallback_remote_ref="refs/remotes/${SYNC_REMOTE}/${fallback_branch_name}"
  worktree_base_ref="${base_ref}"
  if git show-ref --verify --quiet "${fallback_remote_ref}"; then
    worktree_base_ref="${SYNC_REMOTE}/${fallback_branch_name}"
  fi

  tmp_root="$(mktemp -d "${TMPDIR:-/tmp}/phi-sync-fallback.XXXXXX")"
  fallback_worktree="${tmp_root}/worktree"
  patch_file="${tmp_root}/nonworkflow.patch"

  git diff --binary "${worktree_base_ref}..HEAD" -- . ':(exclude).github/workflows/**' > "${patch_file}"
  if [ ! -s "${patch_file}" ]; then
    log "Workflow-scope fallback: no non-workflow delta to publish from ${worktree_base_ref}..HEAD"
    rm -rf "${tmp_root}"
    return 0
  fi

  if ! git worktree add --detach "${fallback_worktree}" "${worktree_base_ref}" >> "${LOG}" 2>&1; then
    log "Workflow-scope fallback: failed to create temporary worktree from ${worktree_base_ref}"
    rm -rf "${tmp_root}"
    return 1
  fi

  if ! git -C "${fallback_worktree}" apply --index --3way "${patch_file}" >> "${LOG}" 2>&1; then
    log "Workflow-scope fallback: unable to apply non-workflow patch cleanly"
    git worktree remove --force "${fallback_worktree}" >> "${LOG}" 2>&1 || true
    rm -rf "${tmp_root}"
    return 1
  fi

  if git -C "${fallback_worktree}" diff --cached --quiet; then
    log "Workflow-scope fallback: computed patch produced no staged changes"
    git worktree remove --force "${fallback_worktree}" >> "${LOG}" 2>&1 || true
    rm -rf "${tmp_root}"
    return 0
  fi

  ts="$(date -u +'%Y-%m-%dT%H:%M:%SZ')"
  if ! git -C "${fallback_worktree}" commit -m "PHI intelligent sync fallback (non-workflow): ${ts}" >> "${LOG}" 2>&1; then
    log "Workflow-scope fallback: failed to create fallback commit"
    git worktree remove --force "${fallback_worktree}" >> "${LOG}" 2>&1 || true
    rm -rf "${tmp_root}"
    return 1
  fi

  while [ "${attempt}" -le "${SYNC_MAX_RETRIES}" ]; do
    if git -C "${fallback_worktree}" push "${push_remote}" "HEAD:${fallback_ref}" >> "${LOG}" 2>&1; then
      log "Workflow-scope fallback: published non-workflow snapshot to ${fallback_branch}"
      git worktree remove --force "${fallback_worktree}" >> "${LOG}" 2>&1 || true
      rm -rf "${tmp_root}"
      return 0
    fi

    # If remote fallback branch advanced, rebase this fallback commit and retry.
    if git -C "${fallback_worktree}" fetch "${push_remote}" "${fallback_ref}" >> "${LOG}" 2>&1; then
      if git -C "${fallback_worktree}" rebase FETCH_HEAD >> "${LOG}" 2>&1; then
        log "Workflow-scope fallback: rebased fallback commit onto latest ${fallback_branch}"
      else
        log "Workflow-scope fallback: rebase onto latest ${fallback_branch} failed"
        git -C "${fallback_worktree}" rebase --abort >> "${LOG}" 2>&1 || true
      fi
    else
      log "Workflow-scope fallback: fetch of latest ${fallback_branch} failed"
    fi

    if [ "${attempt}" -lt "${SYNC_MAX_RETRIES}" ]; then
      local backoff=$(( SYNC_RETRY_SECONDS * attempt ))
      log "Workflow-scope fallback push attempt ${attempt} failed; retrying in ${backoff}s"
      sleep "${backoff}"
    fi
    attempt=$((attempt + 1))
  done

  local timestamped_branch="${fallback_branch_name}-$(date -u +%Y%m%d%H%M%S)"
  if git -C "${fallback_worktree}" push "${push_remote}" "HEAD:refs/heads/${timestamped_branch}" >> "${LOG}" 2>&1; then
    log "Workflow-scope fallback: published non-workflow snapshot to ${timestamped_branch}"
    git worktree remove --force "${fallback_worktree}" >> "${LOG}" 2>&1 || true
    rm -rf "${tmp_root}"
    return 0
  fi

  log "Workflow-scope fallback: failed to publish non-workflow snapshot after ${SYNC_MAX_RETRIES} attempts"
  git worktree remove --force "${fallback_worktree}" >> "${LOG}" 2>&1 || true
  rm -rf "${tmp_root}"
  return 1
}

handle_workflow_scope_fallback() {
  local push_remote="$1"
  local base_ref=""

  if ! is_truthy "${SYNC_WORKFLOW_SCOPE_FALLBACK_ENABLED}"; then
    return 1
  fi

  if ! workflow_scope_error_detected; then
    return 1
  fi

  if ! base_ref="$(determine_nonworkflow_base_ref)"; then
    log "Workflow-scope fallback: no suitable base ref found (tried ${SYNC_BRANCH} and ${SYNC_WORKFLOW_FALLBACK_BASE_BRANCH})"
    return 1
  fi

  log "Workflow-scope fallback: primary push blocked, attempting non-workflow publish from ${base_ref} to ${SYNC_WORKFLOW_FALLBACK_BRANCH}"
  push_nonworkflow_fallback_snapshot "${push_remote}" "${base_ref}" "${SYNC_WORKFLOW_FALLBACK_BRANCH}"
}

main() {
  with_lock_or_exit

  cd "${REPO_DIR}" || exit 1

  log "Intelligent sync start"

  if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    log "Sync aborted: ${REPO_DIR} is not a git repository"
    exit 1
  fi

  if is_truthy "${SYNC_ENFORCE_CONTROLLED_TARGET}"; then
    SYNC_REMOTE="${SYNC_CONTROLLED_REMOTE}"
    log "Controlled target enforced: remote=${SYNC_REMOTE}"
  fi

  SYNC_REMOTE="$(detect_sync_remote)"
  if [ -z "${SYNC_REMOTE}" ]; then
    log "Sync aborted: no usable git remote found (expected fork or origin)"
    exit 1
  fi

  if ! git remote get-url "${SYNC_REMOTE}" >/dev/null 2>&1; then
    log "Sync aborted: git remote '${SYNC_REMOTE}' is not configured"
    exit 1
  fi

  local current_branch
  current_branch="$(git rev-parse --abbrev-ref HEAD)"

  if is_truthy "${SYNC_ENFORCE_CONTROLLED_TARGET}"; then
    SYNC_BRANCH="${SYNC_CONTROLLED_BRANCH}"
    log "Controlled target enforced: branch=${SYNC_BRANCH}"
  elif [ -z "${SYNC_BRANCH}" ]; then
    SYNC_BRANCH="${current_branch}"
  fi

  if is_production_env && is_truthy "${SYNC_ALLOW_AUTOCOMMIT}"; then
    SYNC_ALLOW_AUTOCOMMIT=0
    log "Production environment detected; forcing PHI_SYNC_ALLOW_AUTOCOMMIT=0"
  fi

  git fetch "${SYNC_REMOTE}" >> "${LOG}" 2>&1 || log "Fetch warning: unable to refresh ${SYNC_REMOTE}"

  if working_tree_dirty; then
    if is_truthy "${SYNC_ALLOW_AUTOCOMMIT}"; then
      git add -A
      git commit -m "PHI intelligent sync: $(date -u +'%Y-%m-%dT%H:%M:%SZ')" >> "${LOG}" 2>&1 || true
    else
      log "Working tree has changes; auto-commit disabled (PHI_SYNC_ALLOW_AUTOCOMMIT=0)"
    fi
  fi

  local remote_ref="refs/remotes/${SYNC_REMOTE}/${SYNC_BRANCH}"
  local commits_ahead

  if git show-ref --verify --quiet "${remote_ref}"; then
    local commits_behind
    commits_behind="$(git rev-list --count "HEAD..${SYNC_REMOTE}/${SYNC_BRANCH}" 2>/dev/null || echo 0)"
    if [ "${commits_behind}" -gt 0 ] && is_truthy "${SYNC_REBASE_ON_REMOTE_AHEAD}"; then
      if working_tree_dirty; then
        log "Remote ${SYNC_REMOTE}/${SYNC_BRANCH} is ahead by ${commits_behind}; working tree dirty, deferring rebase/push"
        run_replication_phase "pre-push"
        mark_sync_heartbeat
        exit 0
      fi
      log "Remote ${SYNC_REMOTE}/${SYNC_BRANCH} is ahead by ${commits_behind}; attempting guarded rebase"
      if git rebase "${SYNC_REMOTE}/${SYNC_BRANCH}" >> "${LOG}" 2>&1; then
        log "Rebase successful against ${SYNC_REMOTE}/${SYNC_BRANCH}"
      else
        log "Rebase failed against ${SYNC_REMOTE}/${SYNC_BRANCH}; aborting rebase and deferring push"
        git rebase --abort >> "${LOG}" 2>&1 || true
        exit 1
      fi
    fi
    commits_ahead="$(git rev-list --count "${SYNC_REMOTE}/${SYNC_BRANCH}..HEAD" 2>/dev/null || echo 0)"
  else
    commits_ahead="$(git rev-list --count HEAD 2>/dev/null || echo 0)"
    log "Remote branch ${SYNC_BRANCH} not found; preparing initial push"
  fi

  if [ "${commits_ahead}" -eq 0 ]; then
    log "No commits to push for ${SYNC_BRANCH}"
    run_replication_phase "pre-push"
    mark_sync_heartbeat
    exit 0
  fi

  if [ "${SYNC_PUSH_ENABLED}" != "1" ]; then
    log "Push disabled by PHI_SYNC_PUSH_ENABLED=${SYNC_PUSH_ENABLED}; sync completed locally"
    run_replication_phase "pre-push"
    mark_sync_heartbeat
    exit 0
  fi

  log "Commits ahead on ${SYNC_BRANCH}: ${commits_ahead}"

  local remote_url
  remote_url="$(git remote get-url "${SYNC_REMOTE}")"

  if is_https_remote "${remote_url}"; then
    local push_remote
    # First try any credentials already configured in git/gh helpers.
    if push_preflight "${SYNC_REMOTE}" "${SYNC_BRANCH}"; then
      push_remote="${SYNC_REMOTE}"
    else
      log "Default git credentials failed preflight for ${SYNC_REMOTE}/${SYNC_BRANCH}; scanning stored credentials"
      local auth_remote
      if ! auth_remote="$(select_https_push_remote "${remote_url}" "${SYNC_BRANCH}")"; then
        log "No write-capable stored credential found; push deferred"
        run_replication_phase "pre-push"
        mark_sync_heartbeat
        exit 0
      fi
      push_remote="${auth_remote}"
    fi

    if ! push_with_retry "${push_remote}" "${SYNC_BRANCH}"; then
      if handle_workflow_scope_fallback "${push_remote}"; then
        log "Primary sync push deferred by workflow-scope policy; fallback sync completed"
        run_replication_phase "fallback-push"
        mark_sync_heartbeat
        exit 0
      fi
      exit 1
    fi
  else
    if ! push_preflight_or_skip "${SYNC_REMOTE}" "${SYNC_BRANCH}" "${SYNC_REMOTE}"; then
      run_replication_phase "pre-push"
      mark_sync_heartbeat
      exit 0
    fi
    push_with_retry "${SYNC_REMOTE}" "${SYNC_BRANCH}" || exit 1
  fi

  run_replication_phase "push"
  log "Intelligent sync finished"
  mark_sync_heartbeat
}

main "$@"
