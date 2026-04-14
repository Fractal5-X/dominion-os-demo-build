#!/bin/bash
# PHI System Status Checker
# Comprehensive view of all running PHI services

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
BOLD='\033[1m'
NC='\033[0m'

echo -e "${MAGENTA}╔═══════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${MAGENTA}║              PHI SYSTEMS - STATUS DASHBOARD                       ║${NC}"
echo -e "${MAGENTA}╚═══════════════════════════════════════════════════════════════════╝${NC}"
echo ""

check_service() {
    local port=$1
    local name=$2
    local url=$3
    
    if lsof -ti:$port > /dev/null 2>&1; then
        local pid=$(lsof -ti:$port)
        local cmd=$(ps -p $pid -o comm=)
        echo -e "${GREEN}✓${NC} ${BOLD}$name${NC}"
        echo -e "  ${CYAN}Port:${NC} $port"
        echo -e "  ${CYAN}PID:${NC} $pid ($cmd)"
        echo -e "  ${CYAN}URL:${NC} $url"
        echo ""
        return 0
    else
        echo -e "${RED}✗${NC} ${BOLD}$name${NC} - ${YELLOW}Not Running${NC}"
        echo ""
        return 1
    fi
}

check_process() {
    local pattern=$1
    local name=$2
    
    if pgrep -f "$pattern" > /dev/null; then
        local pid=$(pgrep -f "$pattern" | head -1)
        echo -e "${GREEN}✓${NC} ${BOLD}$name${NC}"
        echo -e "  ${CYAN}PID:${NC} $pid"
        echo ""
        return 0
    else
        echo -e "${RED}✗${NC} ${BOLD}$name${NC} - ${YELLOW}Not Running${NC}"
        echo ""
        return 1
    fi
}

echo -e "${CYAN}━━━ WEB SERVICES ━━━${NC}"
echo ""

ACTIVE=0

check_service 5000 "Command Center Demo (BIMS Financial System)" "http://localhost:5000" && ((ACTIVE++))
check_service 5001 "Billing Service" "http://localhost:5001" && ((ACTIVE++))
check_service 5002 "Alternative Demo" "http://localhost:5002" && ((ACTIVE++))
check_service 8080 "OAuth Server" "http://localhost:8080" && ((ACTIVE++))
check_service 8081 "AskPHI Widget Service" "http://localhost:8081" && ((ACTIVE++))

echo -e "${CYAN}━━━ BACKGROUND SERVICES ━━━${NC}"
echo ""

check_process "phi_background_completion_monitor" "Background Completion Monitor" && ((ACTIVE++))
check_process "phi_cost_minimization" "Cost Minimization Engine" && ((ACTIVE++))
check_process "autonomous_overnight" "Autonomous Overnight Executor" && ((ACTIVE++))
check_process "phi_channel_connect" "Channel Connect SaaS Service" && ((ACTIVE++))
check_process "phi_google_workspace" "Google Workspace Integration" && ((ACTIVE++))

echo -e "${CYAN}━━━ SUMMARY ━━━${NC}"
echo ""
echo -e "${BOLD}Total Active Services:${NC} ${GREEN}$ACTIVE${NC}"
echo ""

if [ $ACTIVE -gt 0 ]; then
    echo -e "${GREEN}✓ PHI Systems Operational${NC}"
else
    echo -e "${YELLOW}⚠ No PHI systems currently running${NC}"
    echo -e "  Run: ${CYAN}bash phi_quick_start.sh${NC} to start services"
fi

echo ""
echo -e "${CYAN}━━━ MANAGEMENT ━━━${NC}"
echo ""
echo "Commands:"
echo "  • Start all:  bash phi_quick_start.sh"
echo "  • Stop all:   pkill -f 'python3.*app.py'"
echo "  • View logs:  tail -f logs/<service>.log"
echo "  • This status: bash phi_status.sh"
echo ""
