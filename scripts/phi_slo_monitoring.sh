#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INTERVAL_SECONDS="${SLO_INTERVAL_SECONDS:-300}"

run_once() {
    echo "[$(date -u +'%Y-%m-%dT%H:%M:%SZ')] PHI SLO monitor cycle"

    if [[ -x "$SCRIPT_DIR/phi_live_ops_verification.sh" ]]; then
        "$SCRIPT_DIR/phi_live_ops_verification.sh" || true
    else
        echo "[WARN] phi_live_ops_verification.sh not found"
    fi
}

if [[ "${1:-}" == "--once" ]]; then
    run_once
    exit 0
fi

echo "[$(date -u +'%Y-%m-%dT%H:%M:%SZ')] PHI SLO daemon started (interval=${INTERVAL_SECONDS}s)"
while true; do
    run_once || true
    sleep "$INTERVAL_SECONDS"
done

