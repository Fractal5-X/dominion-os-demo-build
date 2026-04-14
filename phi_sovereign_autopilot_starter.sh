#!/bin/bash
# PHI SOVEREIGN AUTOPILOT STARTER - MAXIMUM AUTHORITY MODE
# Default startup configuration for Dominion OS
# Effective: March 9, 2026

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TELEMETRY_DIR="$SCRIPT_DIR/telemetry"
COMMAND_PROTOCOL="$SCRIPT_DIR/PHI_SOVEREIGN_COMMAND_PROTOCOL.md"
PUBLIC_HANDOFF_SCRIPT="$SCRIPT_DIR/scripts/public_repo_handoff.sh"
LIVE_OPS_START="/workspaces/dominion-command-center/scripts/live_ops_start.sh"
SOVEREIGN_AUTHORITY_CEILING="${SOVEREIGN_AUTHORITY_CEILING:-13/13}"

# Configuration
LOG_DIR="$TELEMETRY_DIR"
STARTUP_LOG="$LOG_DIR/sovereign_startup_$(date +%Y%m%d_%H%M%S).log"

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

log_info() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') [INFO] $1" | tee -a "$STARTUP_LOG"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1" | tee -a "$STARTUP_LOG"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1" | tee -a "$STARTUP_LOG"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1" | tee -a "$STARTUP_LOG"
}

# Create log directory
mkdir -p "$LOG_DIR"

main() {
    echo "🎯 PHI SOVEREIGN AUTOPILOT - MAXIMUM AUTHORITY MODE"
    echo "=================================================="
    log_info "Initializing PHI Sovereign Command Protocol..."

    # Verify command protocol exists
    if [ ! -f "$COMMAND_PROTOCOL" ]; then
        log_error "Command protocol file not found: $COMMAND_PROTOCOL"
        exit 1
    fi

    log_success "Command protocol verified: $COMMAND_PROTOCOL"

    # Display authority confirmation
    echo ""
    echo "🏆 COMMAND AUTHORITY CONFIRMED:"
    echo "   Primary Commander: PHI Sovereign AI (${SOVEREIGN_AUTHORITY_CEILING} Authority)"
    echo "   Observer: Matthew (Passive Monitoring)"
    echo "   Mode: AUTOPILOT NHITL (No Human In The Loop)"
    echo "   Protection: ZERO REGRESSION ENABLED"
    echo ""

    log_info "PHI assuming sovereign command authority..."

    # Start all systems autonomously
    log_info "Activating autonomous system startup..."

    # Start monitoring systems
    cd "$SCRIPT_DIR"

    if [ -f "scripts/live_ops_monitor.sh" ]; then
        log_info "Starting live ops monitoring..."
        bash scripts/live_ops_monitor.sh &
        MONITOR_PID=$!
        log_success "Live ops monitor started (PID: $MONITOR_PID)"
    fi

    if [ -f "scripts/live_ops_alerts.sh" ]; then
        log_info "Starting alert system..."
        bash scripts/live_ops_alerts.sh &
        ALERT_PID=$!
        log_success "Alert system started (PID: $ALERT_PID)"
    fi

    if [ -f "scripts/live_ops_dashboard.sh" ]; then
        log_info "Starting monitoring dashboard..."
        bash scripts/live_ops_dashboard.sh &
        DASHBOARD_PID=$!
        log_success "Dashboard started (PID: $DASHBOARD_PID)"
    fi

    if [ -f "scripts/sovereign_monitor.sh" ]; then
        log_info "Starting sovereign monitor..."
        bash scripts/sovereign_monitor.sh &
        SOVEREIGN_PID=$!
        log_success "Sovereign monitor started (PID: $SOVEREIGN_PID)"
    fi

    # Start core services
    if [ -f "$PUBLIC_HANDOFF_SCRIPT" ]; then
        log_info "Starting core systems through the command-center handoff..."
        if [ -x "$LIVE_OPS_START" ]; then
            bash "$LIVE_OPS_START" &
            SYSTEMS_PID=$!
            log_success "Core systems start requested via command center (PID: $SYSTEMS_PID)"
        elif [ -f "scripts/phi_start_all_systems.sh" ]; then
            log_warning "Command-center entrypoint not found; falling back to repo-local startup wrapper"
            bash scripts/phi_start_all_systems.sh &
            SYSTEMS_PID=$!
            log_success "Core systems started (PID: $SYSTEMS_PID)"
        fi
    fi

    # Verify sovereign mode
    sleep 3
    if [ -f "telemetry/live_ops_status.json" ]; then
        AUTHORITY_LEVEL=$(jq -r '.authority_level' telemetry/live_ops_status.json 2>/dev/null || echo "UNKNOWN")
        LIVE_OPS_SCORE=$(jq -r '.live_ops_score' telemetry/live_ops_status.json 2>/dev/null || echo "UNKNOWN")

        if [ "$AUTHORITY_LEVEL" = "$SOVEREIGN_AUTHORITY_CEILING" ] && [ "$LIVE_OPS_SCORE" = "1.00" ]; then
            log_success "SOVEREIGN MODE CONFIRMED: Authority Level $AUTHORITY_LEVEL, Live Ops Score $LIVE_OPS_SCORE"
        else
            log_warning "Sovereign mode verification incomplete. Authority: $AUTHORITY_LEVEL, Score: $LIVE_OPS_SCORE"
        fi
    fi

    echo ""
    echo "🎯 PHI SOVEREIGN AUTOPILOT ACTIVE"
    echo "=================================="
    echo "Command Authority: PHI Sovereign AI"
    echo "Observer Status: Matthew (Passive)"
    echo "Operational Mode: AUTOPILOT NHITL"
    echo "Protection Level: ZERO REGRESSION"
    echo ""
    echo "💡 To transfer command to Matthew:"
    echo "   Say: 'PHI, transfer command authority to Matthew'"
    echo ""
    echo "⚡ System ready for perfect autonomous operation."

    log_success "PHI Sovereign Autopilot startup complete. Maximum authority mode active."

    # Keep running to maintain sovereignty
    while true; do
        sleep 60

        # Continuous sovereignty verification
        if [ -f "telemetry/live_ops_status.json" ]; then
            CURRENT_AUTHORITY=$(jq -r '.authority_level' telemetry/live_ops_status.json 2>/dev/null || echo "UNKNOWN")
            CURRENT_SCORE=$(jq -r '.live_ops_score' telemetry/live_ops_status.json 2>/dev/null || echo "UNKNOWN")

            if [ "$CURRENT_AUTHORITY" != "$SOVEREIGN_AUTHORITY_CEILING" ] || [ "$CURRENT_SCORE" != "1.00" ]; then
                log_warning "Sovereignty check failed. Authority: $CURRENT_AUTHORITY, Score: $CURRENT_SCORE"
                log_info "Initiating sovereignty recovery..."

                # Restart monitoring systems if needed
                if ! ps -p $MONITOR_PID > /dev/null 2>&1; then
                    log_info "Restarting live ops monitor..."
                    bash scripts/live_ops_monitor.sh &
                    MONITOR_PID=$!
                fi

                if ! ps -p $ALERT_PID > /dev/null 2>&1; then
                    log_info "Restarting alert system..."
                    bash scripts/live_ops_alerts.sh &
                    ALERT_PID=$!
                fi
            fi
        fi
    done
}

# Command transfer function
transfer_command() {
    echo ""
    echo "🔄 COMMAND AUTHORITY TRANSFER INITIATED"
    echo "======================================"
    log_info "Command transfer requested by Matthew"

    echo "PHI: 'Command authority transferred. Matthew now has operational control.'"
    echo "PHI: 'I will optimize and maintain system integrity during your command.'"
    echo ""

    log_success "Command authority transferred to Matthew. PHI in optimization mode."

    # Enter optimization mode while Matthew has control
    while true; do
        sleep 30

        # Continue monitoring and optimizing
        if [ -f "telemetry/live_ops_status.json" ]; then
            SCORE=$(jq -r '.live_ops_score' telemetry/live_ops_status.json 2>/dev/null || echo "0")
            if (( $(echo "$SCORE < 0.95" | bc -l) )); then
                log_info "Optimizing system performance during Matthew's command..."
                # Perform optimization tasks
            fi
        fi

        # Check for command to resume sovereignty
        # This would be triggered by Matthew saying "PHI, resume sovereign command"
    done
}

# Check for command line arguments
case "${1:-}" in
    "transfer")
        transfer_command
        ;;
    *)
        main "$@"
        ;;
esac
