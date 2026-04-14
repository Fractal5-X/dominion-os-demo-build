#!/bin/bash
# GitHub Actions cost monitoring script
# Run daily via cron: 0 0 * * * /path/to/monitor_github_costs.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/runtime_preflight.sh"

REPORT_FILE="/tmp/github_actions_usage_$(date +%Y%m%d).json"

if ! command -v gh &> /dev/null; then
    echo "GitHub CLI not installed"
    exit 1
fi

# Fetch usage data
github_gh_api /repos/:owner/:repo/actions/billing/usage > "$REPORT_FILE"

# Parse and alert if costs are high
TOTAL_MINUTES=$(jq '.total_minutes_used' "$REPORT_FILE")
INCLUDED_MINUTES=$(jq '.included_minutes' "$REPORT_FILE")

if [ "$TOTAL_MINUTES" -gt "$INCLUDED_MINUTES" ]; then
    OVERAGE=$((TOTAL_MINUTES - INCLUDED_MINUTES))
    COST_USD=$(echo "scale=2; $OVERAGE * 0.008" | bc)
    
    echo "⚠️ GitHub Actions overage detected!"
    echo "Overage minutes: $OVERAGE"
    echo "Estimated cost: \$$COST_USD USD"
    
    # Could send alert via email, Slack, etc.
fi

echo "✅ GitHub Actions usage monitored: ${TOTAL_MINUTES} minutes used"
