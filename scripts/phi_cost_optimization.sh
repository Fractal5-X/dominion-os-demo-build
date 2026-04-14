#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INTERVAL_SECONDS="${COST_INTERVAL_SECONDS:-3600}"

run_once() {
    echo "[$(date -u +'%Y-%m-%dT%H:%M:%SZ')] PHI cost optimization cycle"

    if [[ -x "$SCRIPT_DIR/optimize_cloud_costs.sh" ]]; then
        "$SCRIPT_DIR/optimize_cloud_costs.sh" || true
    else
        echo "[WARN] optimize_cloud_costs.sh not found"
    fi

    if [[ -x "$SCRIPT_DIR/monitor_github_costs.sh" ]] && command -v gh >/dev/null 2>&1; then
        "$SCRIPT_DIR/monitor_github_costs.sh" || true
    fi
}

if [[ "${1:-}" == "--once" ]]; then
    run_once
    exit 0
fi

echo "[$(date -u +'%Y-%m-%dT%H:%M:%SZ')] PHI cost optimization daemon started (interval=${INTERVAL_SECONDS}s)"
while true; do
    run_once || true
    sleep "$INTERVAL_SECONDS"
done

