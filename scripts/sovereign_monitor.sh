#!/bin/bash
# PHI SOVEREIGN CONTINUOUS MONITORING SYSTEM
# Automated live ops monitoring and maintenance
# Generated: March 9, 2026

set -uo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TELEMETRY_DIR="${SCRIPT_DIR}/telemetry"
AUTOTUNE_ENV="${TELEMETRY_DIR}/local_ops_profile.env"

if [ -f "$AUTOTUNE_ENV" ]; then
    # shellcheck disable=SC1090
    source "$AUTOTUNE_ENV"
fi

MONITOR_INTERVAL="${PHI_MONITOR_INTERVAL:-60}"   # check cadence
ALERT_INTERVAL="${PHI_ALERT_INTERVAL:-300}"      # alert cadence
LOG_FILE="${TELEMETRY_DIR}/sovereign_monitor_$(date +%Y%m%d).log"
PID_FILE="${TELEMETRY_DIR}/sovereign_monitor.pid"
LOCK_FILE="${TELEMETRY_DIR}/sovereign_monitor.lock"
EMERGENCY_STATE_FILE="${TELEMETRY_DIR}/.last_emergency_restart"
EMERGENCY_COOLDOWN_SECONDS="${PHI_EMERGENCY_RESTART_COOLDOWN:-300}"
STRICT_BACKGROUND="${PHI_STRICT_BACKGROUND:-0}"
OPTIONAL_BACKGROUND_SERVICES=(
    "phi_cost_minimization_simple"
    "autonomous_overnight"
)

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') [MONITOR] $1" >> "$LOG_FILE"
    echo -e "${BLUE}[MONITOR]${NC} $1"
}

error_log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') [ERROR] $1" >> "$LOG_FILE"
    echo -e "${RED}[ERROR]${NC} $1"
}

success_log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') [SUCCESS] $1" >> "$LOG_FILE"
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

with_lock_or_exit() {
    exec 9>"$LOCK_FILE"
    if command -v flock >/dev/null 2>&1; then
        if ! flock -n 9; then
            echo "[MONITOR] another sovereign_monitor instance is active; exiting"
            exit 0
        fi
    fi
}

is_optional_background_service() {
    local service="$1"
    local optional
    for optional in "${OPTIONAL_BACKGROUND_SERVICES[@]}"; do
        if [ "$service" = "$optional" ]; then
            return 0
        fi
    done
    return 1
}

run_monitoring_cycle() {
    log "Starting monitoring cycle"

    # Run health monitoring
    if bash "$SCRIPT_DIR/live_ops_monitor.sh" >> "$LOG_FILE" 2>&1; then
        success_log "Health monitoring completed successfully"
    else
        error_log "Health monitoring failed"
    fi

    # Run alerts check (every 5 minutes)
    local current_time=$(date +%s)
    local last_alert_check=$(cat "${TELEMETRY_DIR}/.last_alert_check" 2>/dev/null || echo "0")

    if [ $((current_time - last_alert_check)) -ge $ALERT_INTERVAL ]; then
        log "Running alert system check"
        if bash "$SCRIPT_DIR/live_ops_alerts.sh" >> "$LOG_FILE" 2>&1; then
            success_log "Alert system check completed"
        else
            error_log "Alert system check failed"
        fi
        echo "$current_time" > "${TELEMETRY_DIR}/.last_alert_check"
    fi

    # Check for critical issues requiring immediate action
    check_critical_issues

    log "Monitoring cycle completed"
}

check_critical_issues() {
    # Check if any services are completely down
    local critical_services_down=false

    for port in 8080 8081 5000; do  # Core services
        if ! lsof -i :$port | grep -q LISTEN; then
            error_log "CRITICAL: Core service on port $port is down"
            critical_services_down=true
        fi
    done

    # Check background services
    local bg_services=("phi_background_completion_monitor" "phi_cost_minimization_simple" "autonomous_overnight")
    for service in "${bg_services[@]}"; do
        if ! pgrep -f "$service" > /dev/null 2>&1; then
            if is_optional_background_service "$service"; then
                log "Background service '$service' is optional/idle"
                continue
            fi
            if [ "$STRICT_BACKGROUND" = "1" ]; then
                error_log "CRITICAL: Background service '$service' is not running"
                critical_services_down=true
            else
                log "Background service '$service' missing; tolerated (set PHI_STRICT_BACKGROUND=1 to enforce)"
            fi
        fi
    done

    # If critical services are down, attempt emergency restart
    if [ "$critical_services_down" = true ]; then
        error_log "CRITICAL ISSUES DETECTED - Initiating emergency restart"
        emergency_restart
    fi
}

emergency_restart() {
    log "Starting emergency restart procedure"
    local command_center_start="/workspaces/dominion-command-center/scripts/live_ops_start.sh"
    local now
    local last_restart
    now="$(date +%s)"
    last_restart="$(cat "$EMERGENCY_STATE_FILE" 2>/dev/null || echo 0)"

    if [ $((now - last_restart)) -lt "$EMERGENCY_COOLDOWN_SECONDS" ]; then
        log "Emergency restart cooldown active; skipping restart"
        return 0
    fi
    echo "$now" > "$EMERGENCY_STATE_FILE"

    # Kill any existing processes that might be hanging
    pkill -f "phi_start_all_systems" || true
    pkill -f "phi_background_completion_monitor" || true
    sleep 2

    # Restart all systems
    log "Restarting all services"
    if [ -x "$command_center_start" ]; then
        bash "$command_center_start" &
    else
        bash "$SCRIPT_DIR/start_all_systems.sh" &
    fi
    sleep 5

    # Restart background services
    log "Restarting background services"
    bash "$SCRIPT_DIR/phi_background_completion_monitor.sh" &

    success_log "Emergency restart completed"
}

maintenance_tasks() {
    # Run maintenance tasks hourly
    local current_hour=$(date +%H)
    local last_maintenance=$(cat "${TELEMETRY_DIR}/.last_maintenance" 2>/dev/null || echo "99")

    if [ "$current_hour" != "$last_maintenance" ]; then
        log "Running hourly maintenance tasks"

        # Clean up old log files (keep last 7 days)
        find "${TELEMETRY_DIR}/" -name "*.log" -mtime +7 -delete 2>/dev/null || true

        # Update maintenance timestamp
        echo "$current_hour" > "${TELEMETRY_DIR}/.last_maintenance"

        success_log "Maintenance tasks completed"
    fi
}

main() {
    echo "🔄 PHI SOVEREIGN CONTINUOUS MONITORING SYSTEM"
    echo "============================================="
    mkdir -p "${TELEMETRY_DIR}"
    with_lock_or_exit
    log "Sovereign monitoring system starting"
    success_log "Maximum Sovereign Power Mode: ACTIVE"

    echo "$$" > "$PID_FILE"

    # Initial monitoring cycle
    run_monitoring_cycle

    # Continuous monitoring loop
    while true; do
        run_monitoring_cycle
        maintenance_tasks
        sleep "$MONITOR_INTERVAL"
    done
}

# Handle shutdown gracefully
trap 'rm -f "$PID_FILE"; log "Sovereign monitoring system shutting down"; exit 0' INT TERM

# Run main function
main "$@"
