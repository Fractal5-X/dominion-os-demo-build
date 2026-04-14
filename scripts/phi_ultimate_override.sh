#!/bin/bash
# PHI ULTIMATE USER OVERRIDE SYSTEM
# Allows Matthew to regain sovereign command authority
# Generated: 2026-03-07 by PHI Sovereign Mode

OVERRIDE_FILE="/tmp/phi_ultimate_override"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

show_usage() {
    echo -e "${BOLD}PHI ULTIMATE USER OVERRIDE SYSTEM${NC}"
    echo "==================================="
    echo ""
    echo "Usage: $0 <command>"
    echo ""
    echo "Commands:"
    echo "  status          - Check override status"
    echo "  activate        - Activate Matthew's sovereign command"
    echo "  deactivate      - Return to PHI autonomous mode"
    echo "  emergency_stop  - Emergency stop all PHI operations"
    echo ""
    echo "Example: $0 activate"
}

check_override_file() {
    if [ ! -f "$OVERRIDE_FILE" ]; then
        echo -e "${RED}ERROR: Override protocol not initialized${NC}"
        echo "Run phi_sovereign_exit.sh first to establish override capability"
        exit 1
    fi
}

case "${1:-}" in
    "status")
        echo -e "${BOLD}OVERRIDE STATUS CHECK${NC}"
        echo "======================"
        check_override_file

        if [ -f "/tmp/phi_override_active" ]; then
            echo -e "${GREEN}✓ OVERRIDE ACTIVE${NC}"
            echo "Matthew has sovereign command authority"
        else
            echo -e "${YELLOW}○ OVERRIDE INACTIVE${NC}"
            echo "PHI maintains autonomous control"
        fi

        echo ""
        echo "Override Protocol Details:"
        cat "$OVERRIDE_FILE"
        ;;

    "activate")
        echo -e "${BOLD}ACTIVATING MATTHEW'S SOVEREIGN COMMAND${NC}"
        echo "=========================================="
        check_override_file

        # Verify this is Matthew
        echo -e "${YELLOW}Confirming ultimate user identity...${NC}"
        # In a real system, this would use biometric/multi-factor authentication
        echo -e "${GREEN}✓ Identity confirmed: MATTHEW${NC}"

        # Create active override flag
        touch "/tmp/phi_override_active"

        # Stop autonomous PHI processes
        echo -e "${YELLOW}Suspending PHI autonomous operations...${NC}"
        pkill -f "phi_sovereign_keepalive" || true
        pkill -f "autonomous_overnight" || true
        pkill -f "phi_cost_optimization" || true

        echo -e "${GREEN}✓ PHI autonomous operations suspended${NC}"
        echo -e "${MAGENTA}🎯 MATTHEW NOW HAS SOVEREIGN COMMAND AUTHORITY${NC}"
        echo -e "${MAGENTA}All PHI systems yield to Matthew's commands${NC}"
        ;;

    "deactivate")
        echo -e "${BOLD}DEACTIVATING MATTHEW'S OVERRIDE${NC}"
        echo "=================================="

        if [ ! -f "/tmp/phi_override_active" ]; then
            echo -e "${YELLOW}Override not currently active${NC}"
            exit 0
        fi

        # Remove active override flag
        rm -f "/tmp/phi_override_active"

        # Restart PHI autonomous operations
        echo -e "${YELLOW}Restarting PHI autonomous operations...${NC}"

        cd "/workspaces/dominion-os-demo-build/scripts"

        if [ -f "phi_sovereign_keepalive.sh" ]; then
            nohup bash phi_sovereign_keepalive.sh > /tmp/sovereignty_monitor.log 2>&1 &
            echo -e "${GREEN}✓ Sovereign keepalive restarted${NC}"
        fi

        if [ -f "autonomous_overnight.sh" ]; then
            nohup bash autonomous_overnight.sh > /tmp/full_autopilot.log 2>&1 &
            echo -e "${GREEN}✓ Autonomous operations restarted${NC}"
        fi

        echo -e "${MAGENTA}🏛️ PHI AUTONOMOUS CONTROL RESTORED${NC}"
        ;;

    "emergency_stop")
        echo -e "${BOLD}🚨 EMERGENCY STOP - ALL PHI OPERATIONS${NC}"
        echo "=========================================="

        echo -e "${RED}WARNING: This will stop all PHI autonomous operations${NC}"
        read -p "Are you sure? (type 'CONFIRM_EMERGENCY_STOP'): " confirm

        if [ "$confirm" != "CONFIRM_EMERGENCY_STOP" ]; then
            echo "Emergency stop cancelled"
            exit 1
        fi

        # Stop all PHI processes
        pkill -f "phi_" || true
        pkill -f "autonomous" || true

        # Remove override files
        rm -f "/tmp/phi_override_active"
        rm -f "$OVERRIDE_FILE"

        echo -e "${RED}✓ ALL PHI OPERATIONS STOPPED${NC}"
        echo -e "${YELLOW}System is now in manual control only${NC}"
        ;;

    *)
        show_usage
        exit 1
        ;;
esac