#!/bin/bash
# PHI Sovereign Keepalive Monitor
# Maintains sovereign autonomous operation inside this workspace.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
TELEMETRY_DIR="$PROJECT_ROOT/telemetry"
LOG_FILE="$TELEMETRY_DIR/sovereignty_keepalive.log"
PID_FILE="$TELEMETRY_DIR/phi_sovereign_keepalive.pid"
CHECK_INTERVAL="${CHECK_INTERVAL:-300}"

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

mkdir -p "$TELEMETRY_DIR"
echo "$$" > "$PID_FILE"

log_line() {
    local level="$1"
    local message="$2"
    echo "$(date '+%Y-%m-%d %H:%M:%S') [$level] $message" >> "$LOG_FILE"
    case "$level" in
        SUCCESS) echo -e "${GREEN}[SUCCESS]${NC} $message" ;;
        WARN) echo -e "${YELLOW}[WARN]${NC} $message" ;;
        ERROR) echo -e "${RED}[ERROR]${NC} $message" ;;
        *) echo -e "${BLUE}[INFO]${NC} $message" ;;
    esac
}

start_if_missing() {
    local label="$1"
    local pattern="$2"
    local command="$3"

    if pgrep -f "$pattern" > /dev/null 2>&1; then
        log_line "SUCCESS" "$label active"
        return 0
    fi

    log_line "WARN" "$label missing, starting recovery command"
    nohup bash -lc "$command" >> "$LOG_FILE" 2>&1 &
}

run_keepalive_cycle() {
    log_line "INFO" "Sovereign keepalive cycle started"

    start_if_missing \
        "PHI sovereign monitor" \
        "scripts/sovereign_monitor.sh" \
        "cd '$PROJECT_ROOT' && bash scripts/sovereign_monitor.sh"

    start_if_missing \
        "PHI background completion monitor" \
        "scripts/phi_background_completion_monitor.sh" \
        "cd '$PROJECT_ROOT' && bash scripts/phi_background_completion_monitor.sh"

    if bash "$SCRIPT_DIR/daily_live_ops_check.sh" >> "$LOG_FILE" 2>&1; then
        log_line "SUCCESS" "Daily live ops check green"
    else
        log_line "WARN" "Daily live ops check reported a non-perfect state"
    fi

    log_line "INFO" "Sovereign keepalive cycle completed"
}

trap 'rm -f "$PID_FILE"; log_line "INFO" "Sovereign keepalive shutting down"; exit 0' INT TERM

echo "🏛️ PHI SOVEREIGN KEEPALIVE ACTIVATED"
echo "===================================="
log_line "INFO" "PHI sovereign keepalive activated"

while true; do
    run_keepalive_cycle
    sleep "$CHECK_INTERVAL"
done
