#!/bin/bash
# PHI System Status Checker
# Comprehensive view of all running PHI services

set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/public_repo_handoff.sh"
require_command_center_context "live-ops status"

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

service_pid_candidates() {
    local port=$1
    local pattern="${2:-}"
    local pids=""

    pids=$(lsof -ti:"$port" 2>/dev/null | tr '\n' ' ' | xargs 2>/dev/null || true)
    if [ -z "$pids" ] && [ -n "$pattern" ]; then
        pids=$(pgrep -f "$pattern" | tr '\n' ' ' | xargs 2>/dev/null || true)
    fi

    printf '%s' "$pids"
}

service_running() {
    local port=$1
    local url=$2
    local pattern="${3:-}"

    if curl -s -m 2 -o /dev/null "$url/health" \
        || curl -s -m 2 -o /dev/null "$url/healthz" \
        || curl -s -m 2 -o /dev/null "$url/ready" \
        || curl -s -m 2 -o /dev/null "$url"; then
        return 0
    fi

    [ -n "$(service_pid_candidates "$port" "$pattern")" ]
}

probe_service() {
    local url=$1
    local health
    local ready

    ready=$(curl -s -m 3 "$url/ready" 2>/dev/null || true)
    if printf '%s' "$ready" | grep -q '"ready":[[:space:]]*true'; then
        echo "ready"
        return 0
    elif [ -n "$ready" ] && printf '%s' "$ready" | grep -q '"status":[[:space:]]*"not_ready"\|"ready":[[:space:]]*false'; then
        echo "degraded"
        return 0
    fi

    health=$(curl -fsS -m 3 "$url/health" 2>/dev/null || true)
    if [ -z "$health" ]; then
        health=$(curl -fsS -m 3 "$url/healthz" 2>/dev/null || true)
    fi
    if [ -z "$health" ]; then
        echo "running"
        return 0
    fi

    if printf '%s' "$health" | grep -q '"status":[[:space:]]*"ok"\|"status":[[:space:]]*"healthy"\|"status":[[:space:]]*"ready"'; then
        echo "healthy"
    elif printf '%s' "$health" | grep -q '"status":[[:space:]]*"not_ready"\|"ready":[[:space:]]*false'; then
        echo "degraded"
    else
        echo "running"
    fi
}

check_service() {
    local port=$1
    local name=$2
    local url=$3
    local pattern="${4:-}"

    if service_running "$port" "$url" "$pattern"; then
        local pid
        local cmd
        local state

        pid=$(service_pid_candidates "$port" "$pattern")
        if [ -n "$pid" ]; then
            cmd=$(ps -p "$(printf '%s' "$pid" | awk '{print $1}')" -o comm= 2>/dev/null || true)
        else
            cmd="http-responsive"
        fi
        state=$(probe_service "$url")
        echo -e "${GREEN}✓${NC} ${BOLD}$name${NC}"
        echo -e "  ${CYAN}Port:${NC} $port"
        echo -e "  ${CYAN}PID:${NC} ${pid:-n/a} (${cmd:-unknown})"
        echo -e "  ${CYAN}URL:${NC} $url"
        case "$state" in
            ready)
                echo -e "  ${CYAN}Health:${NC} ${GREEN}READY${NC}"
                ;;
            healthy)
                echo -e "  ${CYAN}Health:${NC} ${GREEN}HEALTHY${NC}"
                ;;
            degraded)
                echo -e "  ${CYAN}Health:${NC} ${YELLOW}DEGRADED${NC}"
                ;;
            *)
                echo -e "  ${CYAN}Health:${NC} ${YELLOW}RUNNING (no health endpoint)${NC}"
                ;;
        esac
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

check_optional_process() {
    local pattern=$1
    local name=$2
    local recommendation="${3:-}"

    if pgrep -f "$pattern" > /dev/null; then
        local pid
        pid=$(pgrep -f "$pattern" | head -1)
        echo -e "${GREEN}✓${NC} ${BOLD}$name${NC}"
        echo -e "  ${CYAN}PID:${NC} $pid"
        ACTIVE=$((ACTIVE + 1))
    else
        echo -e "${YELLOW}•${NC} ${BOLD}$name${NC} - ${YELLOW}Optional / Not Running${NC}"
        if [ -n "$recommendation" ]; then
            echo -e "  ${CYAN}Hint:${NC} $recommendation"
        fi
    fi
    echo ""
}

check_cost_minimization_activity() {
    local telemetry_dir
    local latest_log=""
    telemetry_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/telemetry"
    latest_log=$(ls -1t "$telemetry_dir"/cost_minimization_*.log 2>/dev/null | head -1 || true)

    if pgrep -f "phi_cost_minimization" > /dev/null; then
        local pid
        pid=$(pgrep -f "phi_cost_minimization" | head -1)
        echo -e "${GREEN}✓${NC} ${BOLD}Cost Minimization Engine${NC}"
        echo -e "  ${CYAN}PID:${NC} $pid"
        echo ""
        return 0
    fi

    if [ -n "$latest_log" ]; then
        local last_updated
        last_updated=$(stat -c %y "$latest_log" 2>/dev/null | cut -d. -f1 || echo "unknown")
        echo -e "${YELLOW}•${NC} ${BOLD}Cost Minimization Engine${NC} - ${YELLOW}One-shot complete (not daemonized)${NC}"
        echo -e "  ${CYAN}Last Run:${NC} $last_updated"
        echo -e "  ${CYAN}Log:${NC} $latest_log"
        echo ""
        return 0
    fi

    echo -e "${YELLOW}•${NC} ${BOLD}Cost Minimization Engine${NC} - ${YELLOW}No run history found${NC}"
    echo -e "  ${CYAN}Hint:${NC} Triggered by live_ops_start when available"
    echo ""
    return 0
}

echo -e "${CYAN}━━━ WEB SERVICES ━━━${NC}"
echo ""

ACTIVE=0

check_service 5000 "Dominion Command Center" "http://localhost:5000" "uvicorn app.main:app|python3 -m uvicorn app.main:app" && ACTIVE=$((ACTIVE + 1))
check_service 5001 "Billing Service" "http://localhost:5001" "billing-service/app.py|PORT=5001 python3 app.py" && ACTIVE=$((ACTIVE + 1))
check_service 5002 "Dominion Command Core" "http://localhost:5002" "command_core.py" && ACTIVE=$((ACTIVE + 1))
check_service 5003 "Sidecar Service" "http://localhost:5003" "python3 -m uvicorn app:app --host 0.0.0.0 --port 5003|sidecar/app.py" && ACTIVE=$((ACTIVE + 1))
check_service 5004 "ChatGPT Gateway" "http://localhost:5004" "chatgpt-gateway/main.py|PORT=5004 python3 main.py" && ACTIVE=$((ACTIVE + 1))
check_service 8080 "OAuth Server" "http://localhost:8080" "oauth_server/app.py|PHI-OAuth-Server" && ACTIVE=$((ACTIVE + 1))
check_service 8081 "AskPHI Widget Service" "http://localhost:8081" "widget_service/app.py|PHI-AskPHI-Widget" && ACTIVE=$((ACTIVE + 1))
check_service 8090 "Dominion Java Live Ops Site" "http://localhost:8090" "JavaLiveOpsSite|java_live_ops_site.sh" && ACTIVE=$((ACTIVE + 1))

echo -e "${CYAN}━━━ BACKGROUND SERVICES ━━━${NC}"
echo ""

check_process "phi_background_completion_monitor" "Background Completion Monitor" && ACTIVE=$((ACTIVE + 1))
check_cost_minimization_activity
check_optional_process "autonomous_overnight" "Autonomous Overnight Executor" "Run: bash /workspaces/dominion-os-demo-build/scripts/autonomous_overnight.sh"
check_optional_process "phi_channel_connect" "Channel Connect SaaS Service" "Run: bash /workspaces/dominion-os-demo-build/scripts/phi_channel_connect.sh start"
check_optional_process "phi_google_workspace" "Google Workspace Integration" "Run: bash /workspaces/dominion-os-demo-build/scripts/phi_google_workspace.sh start"

echo -e "${CYAN}━━━ SUMMARY ━━━${NC}"
echo ""
echo -e "${BOLD}Total Active Services:${NC} ${GREEN}$ACTIVE${NC}"
echo ""

if [ $ACTIVE -gt 0 ]; then
    echo -e "${GREEN}✓ PHI Systems Operational${NC}"
else
    echo -e "${YELLOW}⚠ No PHI systems currently running${NC}"
    echo -e "  Run: ${CYAN}/workspaces/dominion-command-center/scripts/live_ops_start.sh${NC}"
fi

echo ""
echo -e "${CYAN}━━━ MANAGEMENT ━━━${NC}"
echo ""
echo "Commands:"
echo "  • Start all:  /workspaces/dominion-command-center/scripts/live_ops_start.sh"
echo "  • Status:     /workspaces/dominion-command-center/scripts/live_ops_status.sh"
echo "  • Verify:     /workspaces/dominion-command-center/scripts/live_ops_verify.sh"
echo "  • Stop all:   pkill -f 'python3.*app.py|JavaLiveOpsSite'"
echo "  • View logs:  tail -f logs/<service>.log"
echo "  • This status: bash /workspaces/dominion-command-center/scripts/live_ops_status.sh"
echo ""

STATUS_FILE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/telemetry/system_status.json"
cat > "$STATUS_FILE" << EOF
{
  "timestamp": "$(date -u '+%Y-%m-%dT%H:%M:%SZ')",
  "active_services": $ACTIVE,
  "generated_by": "phi_status.sh"
}
EOF
