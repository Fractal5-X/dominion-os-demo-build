#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEMO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
SYNC_ENV_FILE="${PHI_SYNC_ENV_FILE:-${SCRIPT_DIR}/live_ops_sync.env}"
if [ -f "${SYNC_ENV_FILE}" ]; then
  set -a
  # shellcheck disable=SC1090
  . "${SYNC_ENV_FILE}"
  set +a
fi

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
LOG_DIR="${SCRIPT_DIR}/logs"
mkdir -p "${LOG_DIR}"
TIMESTAMP="$(date -u +%Y%m%d_%H%M%SZ)"
RUN_LOG="${LOG_DIR}/dominion_full_stack_${TIMESTAMP}.log"

PLAN_ONLY=0
VERIFY_ONLY=0
QUIET=0
SAFE_CLEAN=0
LEARN_ATTEMPTS=1
SKIP_DOCKER=0
SKIP_GITHUB=0
SKIP_VSCODE=0
SKIP_DEV_STACK="${DOMINION_FULL_STACK_SKIP_DEV_STACK:-0}"
AUTO_INSTALL_EXTENSIONS="${DOMINION_VSCODE_AUTO_INSTALL:-1}"
LEARN_HISTORY_COUNT="${DOMINION_STARTUP_LEARN_HISTORY_COUNT:-10}"
EXIT_CODE=0
LEARN_REPORT_DIR="${SCRIPT_DIR}/reports"
LEARN_TELEMETRY_DIR="${SCRIPT_DIR}/telemetry"
LEARN_REPORT_FILE="${LEARN_REPORT_DIR}/full_stack_learning_${TIMESTAMP}.md"
LEARN_TELEMETRY_FILE="${LEARN_TELEMETRY_DIR}/full_stack_learning_latest.json"
LEARN_RATE_LIMIT_RUNS=0
LEARN_COMPOSE_FAIL_RUNS=0
LEARN_DEV_STACK_FAIL_RUNS=0
LEARN_ANALYZED_RUNS=0
DOCKER_CLEAN_GATE_BLOCKED=0
DOCKER_RUNTIME_CAPABILITY_BLOCKED=0

declare -a WARNINGS=()

log() {
  local msg="$1"
  if [ "${QUIET}" -eq 0 ]; then
    printf '[%s] %s\n' "$(date -u +'%Y-%m-%d %H:%M:%S UTC')" "${msg}"
  fi
  printf '[%s] %s\n' "$(date -u +'%Y-%m-%d %H:%M:%S UTC')" "${msg}" >> "${RUN_LOG}"
}

warn() {
  local msg="$1"
  WARNINGS+=("${msg}")
  log "WARN: ${msg}"
}

critical() {
  local msg="$1"
  log "ERROR: ${msg}"
  EXIT_CODE=1
}

usage() {
  cat <<'USAGE'
Usage: dominion_command_center_full_stack.sh [options]

Options:
  --plan-only            Print the startup plan and exit.
  --verify-only          Skip startup and run verification only.
  --safe-clean           Strict mode: fail fast unless startup can complete cleanly.
  --no-learn             Disable startup learning from recent attempt logs.
  --skip-docker          Skip Docker preflight and compose startup.
  --skip-github          Skip GitHub readiness checks.
  --skip-vscode          Skip VS Code extension readiness checks.
  --skip-dev-stack       Skip command-center dev tool stack startup.
  --quiet                Reduce console output.
  --help                 Show usage.
USAGE
}

for arg in "$@"; do
  case "$arg" in
    --plan-only) PLAN_ONLY=1 ;;
    --verify-only) VERIFY_ONLY=1 ;;
    --safe-clean) SAFE_CLEAN=1 ;;
    --no-learn) LEARN_ATTEMPTS=0 ;;
    --skip-docker) SKIP_DOCKER=1 ;;
    --skip-github) SKIP_GITHUB=1 ;;
    --skip-vscode) SKIP_VSCODE=1 ;;
    --skip-dev-stack) SKIP_DEV_STACK=1 ;;
    --quiet) QUIET=1 ;;
    --help|-h)
      usage
      exit 0
      ;;
    *)
      printf 'Unknown option: %s\n\n' "$arg" >&2
      usage >&2
      exit 2
      ;;
  esac
done

print_plan() {
  cat <<PLAN
Dominion Command Center Full-Stack Startup Plan

Phase 0: Learning and strict safety gating
- Analyze recent startup logs for repeated blockers and failed phases.
- In safe-clean mode, block startup before any partial changes if strict prerequisites fail.

Phase 1: Docker foundation
- Run docker repair preflight (${SCRIPT_DIR}/docker_repair_optimal.sh) when available.
- Validate docker daemon access.
- Bring up compose overlays in order:
  1) ${DEMO_ROOT}/docker-compose.yml
  2) ${DEMO_ROOT}/docker-compose-mcp.yml
  3) ${DEMO_ROOT}/docker-compose.desktop-pro.yml (if present)

Phase 2: GitHub system readiness
- Verify repository remotes and workflow files.
- Validate authentication with gh CLI and/or token environment.
- Probe remote read access with git ls-remote.

Phase 3: VS Code extension readiness
- Read recommended extensions from ${DEMO_ROOT}/.vscode/extensions.json.
- Install missing extensions through 'code --install-extension' (unless disabled).
- Confirm workspace extension auto-update policy from settings.

Phase 4: Dominion Command Center full-stack start
- Start live ops through ${COMMAND_CENTER_ROOT}/scripts/live_ops_start.sh.
- Start command-center dev stack through scripts/dev/up.sh (optional).

Phase 5: Verification
- Run ${COMMAND_CENTER_ROOT}/scripts/live_ops_verify.sh.
- Run ${SCRIPT_DIR}/phi_live_ops_verification.sh.
- Emit summary and log file: ${RUN_LOG}
PLAN
}

if [ "${PLAN_ONLY}" -eq 1 ]; then
  print_plan
  exit 0
fi

log "Dominion full-stack startup initiated"
log "Log file: ${RUN_LOG}"

if [ ! -d "${DEMO_ROOT}" ]; then
  critical "Demo workspace missing: ${DEMO_ROOT}"
fi

if [ ! -d "${COMMAND_CENTER_ROOT}" ]; then
  warn "Command-center workspace not found at ${COMMAND_CENTER_ROOT}; fallback startup will be used."
fi

COMPOSE_CMD=""

detect_compose_cmd() {
  if command -v docker >/dev/null 2>&1 && docker compose version >/dev/null 2>&1; then
    COMPOSE_CMD="docker compose"
    return 0
  fi
  if command -v docker-compose >/dev/null 2>&1; then
    COMPOSE_CMD="docker-compose"
    return 0
  fi
  return 1
}

learn_from_recent_attempts() {
  if [ "${LEARN_ATTEMPTS}" != "1" ]; then
    log "Phase 0: Learning disabled (--no-learn)."
    return 0
  fi

  mkdir -p "${LEARN_REPORT_DIR}" "${LEARN_TELEMETRY_DIR}"

  local -a recent_logs=()
  mapfile -t recent_logs < <(ls -1t "${LOG_DIR}"/dominion_full_stack_*.log 2>/dev/null | head -n "${LEARN_HISTORY_COUNT}")

  local log_file=""
  for log_file in "${recent_logs[@]}"; do
    [ -f "${log_file}" ] || continue
    [ "${log_file}" = "${RUN_LOG}" ] && continue
    LEARN_ANALYZED_RUNS=$((LEARN_ANALYZED_RUNS + 1))

    if rg -qi 'pull rate limit|unauthenticated pull rate limit' "${log_file}"; then
      LEARN_RATE_LIMIT_RUNS=$((LEARN_RATE_LIMIT_RUNS + 1))
    fi
    if rg -qi 'Compose startup (blocked|failed)' "${log_file}"; then
      LEARN_COMPOSE_FAIL_RUNS=$((LEARN_COMPOSE_FAIL_RUNS + 1))
    fi
    if rg -qi 'Command-center dev stack startup failed' "${log_file}"; then
      LEARN_DEV_STACK_FAIL_RUNS=$((LEARN_DEV_STACK_FAIL_RUNS + 1))
    fi
  done

  log "Phase 0: Learning from attempts"
  log "Learning scan analyzed ${LEARN_ANALYZED_RUNS} recent run logs."
  log "Learning signals: rate-limit runs=${LEARN_RATE_LIMIT_RUNS}, compose-failure runs=${LEARN_COMPOSE_FAIL_RUNS}, dev-stack-failure runs=${LEARN_DEV_STACK_FAIL_RUNS}"
}

dockerhub_auth_configured() {
  local docker_cfg="${HOME}/.docker/config.json"
  [ -f "${docker_cfg}" ] || return 1

  python3 - <<PY
import json
import sys
from pathlib import Path

path = Path("${docker_cfg}")
try:
    data = json.loads(path.read_text())
except Exception:
    sys.exit(1)

docker_host_keys = {
    "docker.io",
    "https://index.docker.io/v1/",
    "index.docker.io",
    "registry-1.docker.io",
}

ok = False
for key in docker_host_keys:
    if key in data.get("auths", {}):
        ok = True
        break
    if key in data.get("credHelpers", {}):
        ok = True
        break

if not ok and data.get("credsStore"):
    ok = True

sys.exit(0 if ok else 1)
PY
}

collect_compose_images() {
  declare -A seen_images=()
  local compose_file=""
  local image=""
  local -a images=()

  for compose_file in \
    "${DEMO_ROOT}/docker-compose.yml" \
    "${DEMO_ROOT}/docker-compose-mcp.yml" \
    "${DEMO_ROOT}/docker-compose.desktop-pro.yml"; do
    [ -f "${compose_file}" ] || continue
    mapfile -t images < <(${COMPOSE_CMD} -f "${compose_file}" config --images 2>/dev/null || true)
    for image in "${images[@]}"; do
      [ -n "${image}" ] || continue
      seen_images["${image}"]=1
    done
  done

  for image in "${!seen_images[@]}"; do
    printf '%s\n' "${image}"
  done | sort
}

docker_runtime_allows_image_layers() {
  if command -v unshare >/dev/null 2>&1; then
    if ! unshare -m true >/dev/null 2>&1; then
      return 1
    fi
  fi
  return 0
}

enforce_safe_clean_docker_gate() {
  if [ "${SAFE_CLEAN}" -ne 1 ]; then
    return 0
  fi

  if [ -z "${COMPOSE_CMD}" ]; then
    DOCKER_CLEAN_GATE_BLOCKED=1
    critical "Safe-clean gate failed: compose command unavailable."
    return 1
  fi

  local -a compose_images=()
  mapfile -t compose_images < <(collect_compose_images)
  if [ "${#compose_images[@]}" -eq 0 ]; then
    log "Safe-clean Docker gate: no compose images detected."
    return 0
  fi

  if ! docker_runtime_allows_image_layers; then
    DOCKER_RUNTIME_CAPABILITY_BLOCKED=1
    log "Safe-clean Docker gate: runtime blocks image layer extraction; compose overlays will be skipped."
    return 2
  fi

  local -a missing_images=()
  local image=""
  for image in "${compose_images[@]}"; do
    if ! docker image inspect "${image}" >/dev/null 2>&1; then
      missing_images+=("${image}")
    fi
  done

  if [ "${#missing_images[@]}" -eq 0 ]; then
    log "Safe-clean Docker gate: all compose images already cached locally."
    return 0
  fi

  if dockerhub_auth_configured; then
    log "Safe-clean Docker gate: Docker Hub auth is configured; missing images can be pulled safely."
    return 0
  fi

  DOCKER_CLEAN_GATE_BLOCKED=1
  critical "Safe-clean gate blocked startup: missing compose images with no Docker Hub auth configured."
  log "Missing compose images: ${missing_images[*]}"
  log "Action: run 'docker login' and rerun with --safe-clean."
  return 1
}

write_learning_artifacts() {
  if [ "${LEARN_ATTEMPTS}" != "1" ]; then
    return 0
  fi

  mkdir -p "${LEARN_REPORT_DIR}" "${LEARN_TELEMETRY_DIR}"
  local current_status="PASS"
  if [ "${EXIT_CODE}" -ne 0 ]; then
    current_status="FAIL"
  fi

  cat > "${LEARN_REPORT_FILE}" <<MD
# Full-Stack Startup Learning Report

- Generated (UTC): $(date -u +%Y-%m-%dT%H:%M:%SZ)
- Safe-clean mode: ${SAFE_CLEAN}
- Recent runs analyzed: ${LEARN_ANALYZED_RUNS}
- Docker rate-limit signal runs: ${LEARN_RATE_LIMIT_RUNS}
- Compose failure signal runs: ${LEARN_COMPOSE_FAIL_RUNS}
- Dev stack failure signal runs: ${LEARN_DEV_STACK_FAIL_RUNS}
- Current run status: ${current_status}
- Current warning count: ${#WARNINGS[@]}
- Docker clean gate blocked: ${DOCKER_CLEAN_GATE_BLOCKED}
- Docker runtime capability blocked: ${DOCKER_RUNTIME_CAPABILITY_BLOCKED}
- Execution log: ${RUN_LOG}

## Learned Guidance

- If Docker rate-limit signals recur and compose images are not cached, require Docker Hub auth before startup.
- Keep startup strict in safe-clean mode to avoid partial startup states.
- Preserve command-center verification as mandatory completion criteria.
MD

  cat > "${LEARN_TELEMETRY_FILE}" <<JSON
{
  "generated_utc": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "safe_clean_mode": ${SAFE_CLEAN},
  "recent_runs_analyzed": ${LEARN_ANALYZED_RUNS},
  "signals": {
    "docker_rate_limit_runs": ${LEARN_RATE_LIMIT_RUNS},
    "compose_failure_runs": ${LEARN_COMPOSE_FAIL_RUNS},
    "dev_stack_failure_runs": ${LEARN_DEV_STACK_FAIL_RUNS}
  },
  "current_run": {
    "status": "${current_status}",
    "warning_count": ${#WARNINGS[@]},
    "exit_code": ${EXIT_CODE},
    "docker_clean_gate_blocked": ${DOCKER_CLEAN_GATE_BLOCKED},
    "docker_runtime_capability_blocked": ${DOCKER_RUNTIME_CAPABILITY_BLOCKED},
    "log_file": "${RUN_LOG}"
  }
}
JSON

  log "Learning artifacts updated: ${LEARN_REPORT_FILE}"
  log "Learning telemetry updated: ${LEARN_TELEMETRY_FILE}"
}

abort_safe_clean_prestart_if_needed() {
  if [ "${SAFE_CLEAN}" -eq 1 ] && { [ "${EXIT_CODE}" -ne 0 ] || [ "${#WARNINGS[@]}" -gt 0 ]; }; then
    if [ "${EXIT_CODE}" -eq 0 ]; then
      critical "Safe-clean preflight blocked startup due warning signals."
    fi
    log "Safe-clean mode aborted before startup to prevent partial/dirty state."
    write_learning_artifacts
    log "Execution log: ${RUN_LOG}"
    exit "${EXIT_CODE}"
  fi
}

run_compose_up() {
  local compose_file="$1"
  if [ ! -f "${compose_file}" ]; then
    return 0
  fi

  if [ -z "${COMPOSE_CMD}" ]; then
    warn "Compose command unavailable; cannot start ${compose_file}"
    return 0
  fi

  local compose_tmp
  compose_tmp="$(mktemp)"
  if ${COMPOSE_CMD} -f "${compose_file}" up -d --remove-orphans > "${compose_tmp}" 2>&1; then
    cat "${compose_tmp}" >> "${RUN_LOG}"
    rm -f "${compose_tmp}"
    log "Compose stack started: ${compose_file}"
    return 0
  fi

  cat "${compose_tmp}" >> "${RUN_LOG}"
  if rg -qi 'pull rate limit|too many requests' "${compose_tmp}"; then
    warn "Compose startup blocked by Docker Hub pull rate limits for ${compose_file} (run 'docker login')."
  else
    warn "Compose startup failed for ${compose_file}; review ${RUN_LOG}"
  fi
  rm -f "${compose_tmp}"
  return 0
}

phase_docker() {
  if [ "${SKIP_DOCKER}" -eq 1 ]; then
    log "Phase 1 skipped: Docker"
    return 0
  fi

  log "Phase 1: Docker foundation"
  if ! command -v docker >/dev/null 2>&1; then
    warn "Docker CLI not found; skipping Docker startup phase."
    return 0
  fi

  local repair_script="${SCRIPT_DIR}/docker_repair_optimal.sh"
  if [ -x "${repair_script}" ]; then
    set +e
    bash "${repair_script}" >> "${RUN_LOG}" 2>&1
    local rc=$?
    set -e
    case "${rc}" in
      0) log "Docker preflight repair completed." ;;
      2)
        if [ "${SAFE_CLEAN}" -eq 1 ]; then
          log "Docker preflight partial (permission limits); strict clean gate will validate readiness."
        else
          warn "Docker preflight partial: runtime permission limits detected."
        fi
        ;;
      3)
        if [ "${SAFE_CLEAN}" -eq 1 ]; then
          log "Docker preflight partial (network/auth limits); strict clean gate will validate readiness."
        else
          warn "Docker preflight partial: network/auth limits detected."
        fi
        ;;
      *) warn "Docker preflight failed with exit code ${rc}; continuing." ;;
    esac
  else
    warn "Docker repair script missing or not executable: ${repair_script}"
  fi

  if docker info >/dev/null 2>&1; then
    log "Docker daemon reachable."
  else
    warn "Docker daemon not reachable after preflight."
  fi

  if detect_compose_cmd; then
    log "Using compose command: ${COMPOSE_CMD}"
  else
    warn "No compose command available."
  fi

  local gate_rc=0
  set +e
  enforce_safe_clean_docker_gate
  gate_rc=$?
  set -e
  if [ "${gate_rc}" -eq 1 ]; then
    return 0
  fi
  if [ "${gate_rc}" -eq 2 ]; then
    log "Docker compose overlays skipped due runtime capability limits."
    return 0
  fi

  run_compose_up "${DEMO_ROOT}/docker-compose.yml"
  run_compose_up "${DEMO_ROOT}/docker-compose-mcp.yml"
  run_compose_up "${DEMO_ROOT}/docker-compose.desktop-pro.yml"
}

phase_github() {
  if [ "${SKIP_GITHUB}" -eq 1 ]; then
    log "Phase 2 skipped: GitHub readiness"
    return 0
  fi

  log "Phase 2: GitHub system readiness"
  if ! command -v git >/dev/null 2>&1; then
    critical "git CLI is required for GitHub readiness checks."
    return 0
  fi

  local workflows_dir="${DEMO_ROOT}/.github/workflows"
  if [ -d "${workflows_dir}" ]; then
    local workflow_count
    workflow_count="$(find "${workflows_dir}" -maxdepth 1 -type f \( -name '*.yml' -o -name '*.yaml' \) | wc -l | tr -d ' ')"
    log "Workflow files detected: ${workflow_count}"
  else
    warn "Workflow directory missing: ${workflows_dir}"
  fi

  local origin_url
  origin_url="$(git -C "${DEMO_ROOT}" remote get-url origin 2>/dev/null || true)"
  if [ -n "${origin_url}" ]; then
    log "Origin remote: ${origin_url}"
  else
    warn "No git origin remote configured for ${DEMO_ROOT}"
  fi

  local has_token=0
  local token_var
  for token_var in PHI_SYNC_GITHUB_TOKEN GH_TOKEN GITHUB_TOKEN PHI_GITHUB_PAT; do
    if [ -n "${!token_var:-}" ]; then
      log "Token source detected: ${token_var}"
      has_token=1
      break
    fi
  done
  if [ "${has_token}" -eq 0 ]; then
    warn "No GitHub token found in PHI_SYNC_GITHUB_TOKEN/GH_TOKEN/GITHUB_TOKEN/PHI_GITHUB_PAT."
  fi

  if command -v gh >/dev/null 2>&1; then
    if gh auth status -h github.com >> "${RUN_LOG}" 2>&1; then
      log "gh auth status: authenticated."
    else
      warn "gh CLI is installed but not authenticated (gh auth login may be required)."
    fi
  else
    warn "gh CLI not found; GitHub CLI checks skipped."
  fi

  if [ -n "${origin_url}" ]; then
    if GIT_TERMINAL_PROMPT=0 git -C "${DEMO_ROOT}" ls-remote --heads origin >/dev/null 2>&1; then
      log "Remote read probe passed (git ls-remote origin)."
    else
      warn "Remote read probe failed for origin (git ls-remote)."
    fi
  fi
}

phase_vscode() {
  if [ "${SKIP_VSCODE}" -eq 1 ]; then
    log "Phase 3 skipped: VS Code extension readiness"
    return 0
  fi

  log "Phase 3: VS Code extension readiness"
  local extensions_file="${DEMO_ROOT}/.vscode/extensions.json"
  local settings_file="${DEMO_ROOT}/.vscode/settings.json"
  if [ ! -f "${extensions_file}" ]; then
    warn "Missing VS Code extensions file: ${extensions_file}"
    return 0
  fi

  if ! command -v python3 >/dev/null 2>&1; then
    warn "python3 unavailable; cannot parse ${extensions_file}"
    return 0
  fi

  mapfile -t recommended_extensions < <(
    python3 - <<PY
import json
from pathlib import Path
p = Path("${extensions_file}")
try:
    data = json.loads(p.read_text())
    for item in data.get("recommendations", []):
        print(item)
except Exception:
    pass
PY
  )

  if [ "${#recommended_extensions[@]}" -eq 0 ]; then
    warn "No recommended extensions found in ${extensions_file}"
    return 0
  fi
  log "Recommended VS Code extensions: ${#recommended_extensions[@]}"

  if [ -f "${settings_file}" ]; then
    local updates_state
    updates_state="$(python3 - <<PY
import json
from pathlib import Path
p = Path("${settings_file}")
try:
    data = json.loads(p.read_text())
    print(str(data.get("extensions.autoUpdate", "missing")).lower())
except Exception:
    print("missing")
PY
)"
    log "extensions.autoUpdate=${updates_state}"
  fi

  if ! command -v code >/dev/null 2>&1; then
    warn "'code' CLI not found; install extensions manually via VS Code recommendations."
    return 0
  fi

  mapfile -t installed_extensions < <(code --list-extensions 2>/dev/null || true)

  declare -A installed_map=()
  local ext
  for ext in "${installed_extensions[@]}"; do
    installed_map["$(printf '%s' "${ext}" | tr '[:upper:]' '[:lower:]')"]=1
  done

  local missing_count=0
  local install_failures=0
  for ext in "${recommended_extensions[@]}"; do
    local ext_lc
    ext_lc="$(printf '%s' "${ext}" | tr '[:upper:]' '[:lower:]')"
    if [ -n "${installed_map[$ext_lc]:-}" ]; then
      continue
    fi

    # Some IDs are built-in or incompatible with Codespaces and should not be forced.
    if [ "${ext_lc}" = "ms-vscode.vscode-json" ]; then
      log "Skipping built-in VS Code extension recommendation: ${ext}"
      continue
    fi
    if [ "${ext_lc}" = "ms-vscode-remote.remote-wsl" ] && [ -n "${CODESPACES:-}" ]; then
      log "Skipping WSL extension in Codespaces runtime: ${ext}"
      continue
    fi

    missing_count=$((missing_count + 1))
    if [ "${AUTO_INSTALL_EXTENSIONS}" = "1" ]; then
      local install_tmp install_rc
      install_tmp="$(mktemp)"
      set +e
      code --install-extension "${ext}" --force > "${install_tmp}" 2>&1
      install_rc=$?
      set -e
      cat "${install_tmp}" >> "${RUN_LOG}"

      if [ "${install_rc}" -eq 0 ] && ! rg -qi 'Failed Installing Extensions|not found|Cannot install' "${install_tmp}"; then
        log "Installed VS Code extension: ${ext}"
      else
        install_failures=$((install_failures + 1))
        warn "Failed to install VS Code extension: ${ext}"
      fi
      rm -f "${install_tmp}"
    fi
  done

  if [ "${missing_count}" -eq 0 ]; then
    log "All recommended VS Code extensions already installed."
  elif [ "${AUTO_INSTALL_EXTENSIONS}" != "1" ]; then
    warn "${missing_count} recommended extensions are missing (auto install disabled)."
  elif [ "${install_failures}" -eq 0 ]; then
    log "Installed all missing recommended VS Code extensions (${missing_count})."
  fi
}

ensure_command_center_dev_deps() {
  local cc_python="${COMMAND_CENTER_ROOT}/.venv/bin/python"
  if [ ! -x "${cc_python}" ]; then
    warn "Command-center venv python missing: ${cc_python}"
    return 0
  fi

  if "${cc_python}" -c "import multipart" >/dev/null 2>&1; then
    return 0
  fi

  if "${cc_python}" -m pip install -q python-multipart >> "${RUN_LOG}" 2>&1; then
    log "Installed command-center dependency: python-multipart"
  else
    warn "Failed to install command-center dependency python-multipart."
  fi
}

start_full_stack() {
  if [ "${VERIFY_ONLY}" -eq 1 ]; then
    log "Startup skipped (--verify-only)"
    return 0
  fi

  log "Phase 4: Dominion Command Center full-stack start"
  local cc_start="${COMMAND_CENTER_ROOT}/scripts/live_ops_start.sh"
  local fallback_start="${SCRIPT_DIR}/phi_start_all_systems.sh"

  if [ -f "${cc_start}" ]; then
    if bash "${cc_start}" >> "${RUN_LOG}" 2>&1; then
      log "Command-center live ops start completed."
    else
      critical "Command-center live ops start failed: ${cc_start}"
      return 0
    fi
  elif [ -f "${fallback_start}" ]; then
    warn "Command-center start script unavailable; using fallback ${fallback_start}"
    if bash "${fallback_start}" >> "${RUN_LOG}" 2>&1; then
      log "Fallback live ops startup completed."
    else
      critical "Fallback live ops startup failed: ${fallback_start}"
      return 0
    fi
  else
    critical "No startup script found for full stack."
    return 0
  fi

  if [ "${SKIP_DEV_STACK}" = "1" ]; then
    log "Dev stack startup skipped."
    return 0
  fi

  ensure_command_center_dev_deps

  local cc_dev_up="${COMMAND_CENTER_ROOT}/scripts/dev/up.sh"
  if [ -f "${cc_dev_up}" ]; then
    if START_ASKPHI="${START_ASKPHI:-0}" START_MCP="${START_MCP:-1}" bash "${cc_dev_up}" >> "${RUN_LOG}" 2>&1; then
      log "Command-center dev stack started."
    else
      warn "Command-center dev stack startup failed: ${cc_dev_up}"
    fi
  else
    warn "Command-center dev stack script not found: ${cc_dev_up}"
  fi
}

verify_full_stack() {
  log "Phase 5: Verification"

  local cc_verify="${COMMAND_CENTER_ROOT}/scripts/live_ops_verify.sh"
  if [ -f "${cc_verify}" ]; then
    if bash "${cc_verify}" >> "${RUN_LOG}" 2>&1; then
      log "Command-center live ops verification passed."
    else
      critical "Command-center live ops verification failed."
    fi
  else
    warn "Command-center verification script not found: ${cc_verify}"
  fi

  local phi_verify="${SCRIPT_DIR}/phi_live_ops_verification.sh"
  if [ -f "${phi_verify}" ]; then
    if bash "${phi_verify}" >> "${RUN_LOG}" 2>&1; then
      log "PHI live ops verification passed."
    else
      warn "PHI live ops verification reported degraded state."
    fi
  else
    warn "PHI verification script not found: ${phi_verify}"
  fi

  local phi_status="${SCRIPT_DIR}/phi_status.sh"
  if [ -f "${phi_status}" ]; then
    bash "${phi_status}" --quiet >> "${RUN_LOG}" 2>&1 || true
  fi
}

learn_from_recent_attempts
phase_docker
abort_safe_clean_prestart_if_needed
phase_github
abort_safe_clean_prestart_if_needed
phase_vscode
abort_safe_clean_prestart_if_needed

start_full_stack
verify_full_stack

if [ "${SAFE_CLEAN}" -eq 1 ] && [ "${#WARNINGS[@]}" -gt 0 ]; then
  critical "Safe-clean requirement not met: warnings were emitted during startup."
fi

write_learning_artifacts

log "Startup sequence complete."
if [ "${#WARNINGS[@]}" -gt 0 ]; then
  log "Warnings detected: ${#WARNINGS[@]}"
  for item in "${WARNINGS[@]}"; do
    log " - ${item}"
  done
fi
log "Execution log: ${RUN_LOG}"

exit "${EXIT_CODE}"
