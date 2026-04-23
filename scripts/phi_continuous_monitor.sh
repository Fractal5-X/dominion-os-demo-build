#!/usr/bin/env bash
#
# PHI Continuous Autopilot Monitor
#
# Real-time monitoring dashboard for continuous autopilot operations.
# Displays authority, services, resources, and autopilot metrics.
#
# Usage:
#   bash phi_continuous_monitor.sh [interval]
#
# interval: Refresh interval in seconds (default: 5)
#

INTERVAL="${1:-5}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE_DIR="$(dirname "$SCRIPT_DIR")"
TELEMETRY_DIR="$SCRIPT_DIR/telemetry"
FLIGHT_LOG_DIR="$WORKSPACE_DIR/dist/command_core"

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
BOLD='\033[1m'
NC='\033[0m'

clear_screen() {
    clear
}

get_authority() {
    if [ -f "$TELEMETRY_DIR/sovereign_status.json" ]; then
        jq -r '.sovereignty_level' "$TELEMETRY_DIR/sovereign_status.json" 2>/dev/null || echo "unknown"
    else
        echo "unknown"
    fi
}

get_mode() {
    if [ -f "$TELEMETRY_DIR/sovereign_status.json" ]; then
        jq -r '.mode' "$TELEMETRY_DIR/sovereign_status.json" 2>/dev/null || echo "unknown"
    else
        echo "unknown"
    fi
}

get_max_power() {
    if [ -f "$TELEMETRY_DIR/sovereign_status.json" ]; then
        jq -r '.max_power' "$TELEMETRY_DIR/sovereign_status.json" 2>/dev/null || echo "unknown"
    else
        echo "unknown"
    fi
}

get_services() {
    bash "$SCRIPT_DIR/phi_status.sh" 2>&1 | grep -oP 'Total Active Services: \K\d+' || echo "0"
}

get_cpu_idle() {
    top -bn1 | grep "Cpu(s)" | sed "s/.*, *\([0-9.]*\)%* id.*/\1/" | head -1
}

get_memory_used() {
    free -h | awk '/^Mem:/ {print $3}'
}

get_memory_total() {
    free -h | awk '/^Mem:/ {print $2}'
}

get_memory_available() {
    free -h | awk '/^Mem:/ {print $7}'
}

get_disk_used() {
    df -h / | awk 'NR==2 {print $3}'
}

get_disk_available() {
    df -h / | awk 'NR==2 {print $4}'
}

get_disk_percent() {
    df -h / | awk 'NR==2 {print $5}'
}

get_latest_flight_log() {
    ls -t "$FLIGHT_LOG_DIR"/flight_*.json 2>/dev/null | head -1
}

get_autopilot_status() {
    if [ -f "$TELEMETRY_DIR/continuous_autopilot_metadata.json" ]; then
        jq -r '.status' "$TELEMETRY_DIR/continuous_autopilot_metadata.json" 2>/dev/null || echo "inactive"
    else
        echo "inactive"
    fi
}

get_autopilot_pid() {
    if [ -f "$TELEMETRY_DIR/continuous_autopilot.pid" ]; then
        cat "$TELEMETRY_DIR/continuous_autopilot.pid" 2>/dev/null || echo "none"
    else
        # Try to find autopilot process
        pgrep -f "demo_build.py autopilot" 2>/dev/null | head -1 || echo "none"
    fi
}

get_monitor_count() {
    ps aux | grep -E "phi_monitor_supervisor|sovereign_monitor|intelligent_sync_daemon" | grep -v grep | wc -l
}

display_dashboard() {
    clear_screen

    local AUTHORITY=$(get_authority)
    local MODE=$(get_mode)
    local MAX_POWER=$(get_max_power)
    local SERVICES=$(get_services)
    local CPU_IDLE=$(get_cpu_idle)
    local MEM_USED=$(get_memory_used)
    local MEM_TOTAL=$(get_memory_total)
    local MEM_AVAIL=$(get_memory_available)
    local DISK_USED=$(get_disk_used)
    local DISK_AVAIL=$(get_disk_available)
    local DISK_PERCENT=$(get_disk_percent)
    local AUTOPILOT_STATUS=$(get_autopilot_status)
    local AUTOPILOT_PID=$(get_autopilot_pid)
    local MONITOR_COUNT=$(get_monitor_count)
    local TIMESTAMP=$(date +'%Y-%m-%d %H:%M:%S')

    echo ""
    echo -e "${BOLD}╔═══════════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BOLD}║                                                                           ║${NC}"
    echo -e "${BOLD}║       ${CYAN}🎯 PHI CONTINUOUS AUTOPILOT MONITOR - 14/14 SOVEREIGN${NC}${BOLD}         ║${NC}"
    echo -e "${BOLD}║                                                                           ║${NC}"
    echo -e "${BOLD}╚═══════════════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${CYAN}Timestamp:${NC} $TIMESTAMP"
    echo -e "${CYAN}Refresh:${NC}   ${INTERVAL}s"
    echo ""

    # Authority status
    echo -e "${BOLD}━━━ SOVEREIGN AUTHORITY ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    if [ "$AUTHORITY" = "14/14" ]; then
        echo -e "  Level:      ${GREEN}$AUTHORITY UNIVERSAL_DOMINION ✅${NC}"
    else
        echo -e "  Level:      ${RED}$AUTHORITY ⚠️${NC}"
    fi

    if [ "$MODE" = "NHITL_AUTOPILOT" ]; then
        echo -e "  Mode:       ${GREEN}$MODE ✅${NC}"
    else
        echo -e "  Mode:       ${YELLOW}$MODE${NC}"
    fi

    if [ "$MAX_POWER" = "ENABLED" ]; then
        echo -e "  Max Power:  ${GREEN}$MAX_POWER ✅${NC}"
    else
        echo -e "  Max Power:  ${YELLOW}$MAX_POWER${NC}"
    fi
    echo ""

    # Autopilot status
    echo -e "${BOLD}━━━ AUTOPILOT STATUS ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    if [ "$AUTOPILOT_STATUS" = "running" ]; then
        echo -e "  Status:     ${GREEN}$AUTOPILOT_STATUS ✅${NC}"
    else
        echo -e "  Status:     ${YELLOW}$AUTOPILOT_STATUS${NC}"
    fi

    if [ "$AUTOPILOT_PID" != "none" ]; then
        echo -e "  PID:        ${GREEN}$AUTOPILOT_PID${NC}"
    else
        echo -e "  PID:        ${YELLOW}not running${NC}"
    fi

    # Get latest flight log info
    local LATEST_FLIGHT=$(get_latest_flight_log)
    if [ -n "$LATEST_FLIGHT" ] && [ -f "$LATEST_FLIGHT" ]; then
        local FLIGHT_OPS=$(jq -r '.runs[0].processed' "$LATEST_FLIGHT" 2>/dev/null || echo "N/A")
        local FLIGHT_BACKLOG=$(jq -r '.runs[0].backlog' "$LATEST_FLIGHT" 2>/dev/null || echo "N/A")
        local FLIGHT_SCALE=$(jq -r '.runs[0].scale' "$LATEST_FLIGHT" 2>/dev/null || echo "N/A")
        local FLIGHT_NAME=$(basename "$LATEST_FLIGHT")

        echo -e "  Last Run:   ${CYAN}$FLIGHT_NAME${NC}"
        echo -e "  Ops:        ${GREEN}${FLIGHT_OPS}${NC} processed"
        echo -e "  Backlog:    ${YELLOW}${FLIGHT_BACKLOG}${NC} items"
        echo -e "  Scale:      ${CYAN}${FLIGHT_SCALE}${NC}"
    else
        echo -e "  Last Run:   ${YELLOW}No flight logs${NC}"
    fi
    echo ""

    # Services status
    echo -e "${BOLD}━━━ SERVICES HEALTH ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    if [ "$SERVICES" -ge 13 ]; then
        echo -e "  Active:     ${GREEN}$SERVICES/13 (100%) ✅${NC}"
    elif [ "$SERVICES" -ge 11 ]; then
        echo -e "  Active:     ${YELLOW}$SERVICES/13 ⚠️${NC}"
    else
        echo -e "  Active:     ${RED}$SERVICES/13 ❌${NC}"
    fi

    if [ "$MONITOR_COUNT" -ge 3 ]; then
        echo -e "  Monitors:   ${GREEN}$MONITOR_COUNT background monitors ✅${NC}"
    else
        echo -e "  Monitors:   ${YELLOW}$MONITOR_COUNT background monitors ⚠️${NC}"
    fi
    echo ""

    # Resources
    echo -e "${BOLD}━━━ SYSTEM RESOURCES ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

    # CPU
    local CPU_USED=$(echo "100 - $CPU_IDLE" | bc 2>/dev/null || echo "N/A")
    if [ "$CPU_USED" != "N/A" ]; then
        local CPU_INT=${CPU_USED%.*}
        if [ "$CPU_INT" -lt 70 ]; then
            echo -e "  CPU:        ${GREEN}${CPU_USED}% used, ${CPU_IDLE}% idle ✅${NC}"
        elif [ "$CPU_INT" -lt 90 ]; then
            echo -e "  CPU:        ${YELLOW}${CPU_USED}% used, ${CPU_IDLE}% idle ⚠️${NC}"
        else
            echo -e "  CPU:        ${RED}${CPU_USED}% used, ${CPU_IDLE}% idle ❌${NC}"
        fi
    else
        echo -e "  CPU:        ${YELLOW}Unable to determine${NC}"
    fi

    # Memory
    echo -e "  Memory:     ${CYAN}${MEM_USED}${NC} used / ${CYAN}${MEM_TOTAL}${NC} total (${GREEN}${MEM_AVAIL}${NC} available)"

    # Disk
    local DISK_PERCENT_NUM=${DISK_PERCENT%\%}
    if [ "$DISK_PERCENT_NUM" -lt 70 ]; then
        echo -e "  Disk:       ${CYAN}${DISK_USED}${NC} used / ${GREEN}${DISK_AVAIL}${NC} available ($DISK_PERCENT) ✅"
    elif [ "$DISK_PERCENT_NUM" -lt 85 ]; then
        echo -e "  Disk:       ${CYAN}${DISK_USED}${NC} used / ${YELLOW}${DISK_AVAIL}${NC} available ($DISK_PERCENT) ⚠️"
    else
        echo -e "  Disk:       ${CYAN}${DISK_USED}${NC} used / ${RED}${DISK_AVAIL}${NC} available ($DISK_PERCENT) ❌"
    fi
    echo ""

    # Legend
    echo -e "${BOLD}━━━ STATUS LEGEND ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "  ${GREEN}✅ Optimal${NC}  ${YELLOW}⚠️  Warning${NC}  ${RED}❌ Critical${NC}"
    echo ""
    echo -e "${CYAN}Press Ctrl+C to exit${NC}"
    echo ""
}

# Main loop
trap "echo '' && echo 'Monitor stopped' && exit 0" INT TERM

while true; do
    display_dashboard
    sleep "$INTERVAL"
done
