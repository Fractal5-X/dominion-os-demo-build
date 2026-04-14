#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEMO_REPO="$(cd "$SCRIPT_DIR/.." && pwd)"
COMMAND_CENTER_REPO="$(cd "$DEMO_REPO/../dominion-command-center" 2>/dev/null && pwd || true)"
INTERVAL_SECONDS="${SYNC_INTERVAL_SECONDS:-300}"

log() {
    echo "[$(date -u +'%Y-%m-%dT%H:%M:%SZ')] $*"
}

sync_repo() {
    local repo_path="$1"
    local name="$2"

    if [[ -z "$repo_path" || ! -d "$repo_path/.git" ]]; then
        log "[WARN] $name repo not found at $repo_path"
        return 0
    fi

    log "[INFO] Sync check: $name ($repo_path)"
    timeout 20 git -C "$repo_path" fetch origin --quiet || log "[WARN] fetch timed out/failed for $name"

    local local_sha
    local remote_sha
    local ahead
    local behind

    local_sha="$(git -C "$repo_path" rev-parse --short HEAD 2>/dev/null || echo unknown)"
    remote_sha="$(git -C "$repo_path" rev-parse --short origin/main 2>/dev/null || echo unknown)"
    ahead="$(git -C "$repo_path" rev-list --count origin/main..HEAD 2>/dev/null || echo 0)"
    behind="$(git -C "$repo_path" rev-list --count HEAD..origin/main 2>/dev/null || echo 0)"

    log "[INFO] $name local=$local_sha remote=$remote_sha ahead=$ahead behind=$behind"
}

run_once() {
    sync_repo "$COMMAND_CENTER_REPO" "dominion-command-center"
    sync_repo "$DEMO_REPO" "dominion-demo-build"
}

if [[ "${1:-}" == "--once" ]]; then
    run_once
    exit 0
fi

log "[INFO] PHI multi-repo sync daemon started (interval=${INTERVAL_SECONDS}s)"
while true; do
    run_once || true
    sleep "$INTERVAL_SECONDS"
done
