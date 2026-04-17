#!/usr/bin/env bash
set -euo pipefail

# PHI Intelligent Sync
# Local-first sync with branch-aware push, lock protection, and retry logic.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
TELEMETRY_DIR="${SCRIPT_DIR}/telemetry"
LOG="${TELEMETRY_DIR}/intelligent_sync.log"
LOCK_FILE="${TELEMETRY_DIR}/intelligent_sync.lock"

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

mkdir -p "${TELEMETRY_DIR}"

log() {
  printf '[%s] %s\n' "$(date -u +'%Y-%m-%dT%H:%M:%SZ')" "$1" >> "${LOG}"
}

with_lock_or_exit() {
  exec 9>"${LOCK_FILE}"
  if command -v flock >/dev/null 2>&1; then
    if ! flock -n 9; then
      log "Sync skipped: another intelligent sync process is active"
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

credentials_from_gcloud_secret_manager() {
  local gcp_lookup_enabled="${PHI_SYNC_GCP_LOOKUP_ENABLED:-1}"
  local secret_names="${PHI_SYNC_GCP_SECRET_NAMES:-GITHUB_TOKEN,GITHUB_PAT,PHI_GITHUB_PAT,github-pat,dominion-github-github-oauthtoken-57a2ca}"
  local project="${PHI_SYNC_GCP_SECRET_PROJECT:-}"
  local gcp_timeout_seconds="${PHI_SYNC_GCP_TIMEOUT_SECONDS:-4}"
  local secret_name token

  [ "${gcp_lookup_enabled}" = "1" ] || return
  [ -n "${secret_names}" ] || return
  command -v gcloud >/dev/null 2>&1 || return

  if [ -z "${project}" ]; then
    project="$(gcloud config get-value project 2>/dev/null || true)"
  fi

  IFS=',' read -r -a gcp_secrets <<< "${secret_names}"
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
    exit 0
  fi

  if [ "${SYNC_PUSH_ENABLED}" != "1" ]; then
    log "Push disabled by PHI_SYNC_PUSH_ENABLED=${SYNC_PUSH_ENABLED}; sync completed locally"
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
        exit 0
      fi
      push_remote="${auth_remote}"
    fi

    if ! push_with_retry "${push_remote}" "${SYNC_BRANCH}"; then
      if handle_workflow_scope_fallback "${push_remote}"; then
        log "Primary sync push deferred by workflow-scope policy; fallback sync completed"
        exit 0
      fi
      exit 1
    fi
  else
    if ! push_preflight_or_skip "${SYNC_REMOTE}" "${SYNC_BRANCH}" "${SYNC_REMOTE}"; then
      exit 0
    fi
    push_with_retry "${SYNC_REMOTE}" "${SYNC_BRANCH}" || exit 1
  fi

  log "Intelligent sync finished"
}

main "$@"
