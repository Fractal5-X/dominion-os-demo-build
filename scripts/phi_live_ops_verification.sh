#!/bin/bash
# ═══════════════════════════════════════════════════════════════════
# PHI LIVE OPS VERIFICATION & DOCKER DESKTOP PRO CONFIGURATION
# ═══════════════════════════════════════════════════════════════════
# Generated: March 7, 2026
# Purpose: Verify all live operations systems and Docker configuration
# ═══════════════════════════════════════════════════════════════════

set -uo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/public_repo_handoff.sh"
require_command_center_context "live-ops verification"

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/runtime_preflight.sh"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
BOLD='\033[1m'
NC='\033[0m'

DOCKER_DAEMON_AVAILABLE=false
DOCKER_CONTROL_AVAILABLE=false
DOCKER_POINTS_AVAILABLE=20
DOCKER_RUNTIME_NA=false

if command -v systemctl > /dev/null 2>&1 || command -v service > /dev/null 2>&1; then
    DOCKER_CONTROL_AVAILABLE=true
fi

if docker_daemon_available; then
    DOCKER_DAEMON_AVAILABLE=true
elif docker_runtime_blocked || ! docker_cli_available; then
    DOCKER_POINTS_AVAILABLE=0
    DOCKER_RUNTIME_NA=true
fi

echo -e "${MAGENTA}╔═══════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${MAGENTA}║        PHI LIVE OPS VERIFICATION & SYSTEM STATUS                  ║${NC}"
echo -e "${MAGENTA}╚═══════════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${CYAN}Timestamp:${NC} $(date '+%Y-%m-%d %H:%M:%S %Z')"
echo ""

# System Resources
echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${CYAN}SYSTEM RESOURCES${NC}"
echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

CPU_COUNT=$(nproc)
CPU_MODEL=$(grep "model name" /proc/cpuinfo | head -1 | cut -d: -f2 | xargs)
MEM_TOTAL=$(free -h | awk '/^Mem:/ {print $2}')
MEM_USED=$(free -h | awk '/^Mem:/ {print $3}')
MEM_AVAIL=$(free -h | awk '/^Mem:/ {print $7}')
DISK_TOTAL=$(df -h / | awk 'NR==2 {print $2}')
DISK_USED=$(df -h / | awk 'NR==2 {print $3}')
DISK_AVAIL=$(df -h / | awk 'NR==2 {print $4}')

echo -e "${GREEN}✓${NC} CPU: $CPU_MODEL"
echo -e "  └─ Cores: $CPU_COUNT"
echo -e "${GREEN}✓${NC} Memory: $MEM_TOTAL total, $MEM_USED used, $MEM_AVAIL available"
echo -e "${GREEN}✓${NC} Disk: $DISK_TOTAL total, $DISK_USED used, $DISK_AVAIL available"
echo ""

# PHI Services Status
echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${CYAN}PHI WEB SERVICES STATUS${NC}"
echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

SERVICES_UP=0
SERVICES_TOTAL=8

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

probe_service_state() {
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
        pid=$(service_pid_candidates "$port" "$pattern")
        echo -e "${GREEN}✓${NC} $name"
        echo -e "  ├─ Port: $port"
        echo -e "  ├─ PID: ${pid:-n/a}"
        echo -e "  ├─ URL: $url"

        case "$(probe_service_state "$url")" in
            ready)
                echo -e "  └─ Status: ${GREEN}READY${NC}"
                SERVICES_UP=$((SERVICES_UP + 1))
                ;;
            healthy)
                echo -e "  └─ Status: ${GREEN}HEALTHY${NC}"
                SERVICES_UP=$((SERVICES_UP + 1))
                ;;
            degraded)
                echo -e "  └─ Status: ${YELLOW}DEGRADED${NC}"
                ;;
            *)
                echo -e "  └─ Status: ${YELLOW}RUNNING (no health endpoint)${NC}"
                ;;
        esac
        echo ""
        return 0
    else
        echo -e "${RED}✗${NC} $name - ${YELLOW}NOT RUNNING${NC}"
        echo ""
        return 1
    fi
}

check_service 5000 "Dominion Command Center" "http://localhost:5000" "uvicorn app.main:app|python3 -m uvicorn app.main:app" || true
check_service 5001 "Billing Service" "http://localhost:5001" "billing-service/app.py|PORT=5001 python3 app.py" || true
check_service 5002 "Dominion Command Core" "http://localhost:5002" "command_core.py" || true
check_service 5003 "Sidecar Service" "http://localhost:5003" "python3 -m uvicorn app:app --host 0.0.0.0 --port 5003|sidecar/app.py" || true
check_service 5004 "ChatGPT Gateway" "http://localhost:5004" "chatgpt-gateway/main.py|PORT=5004 python3 main.py" || true
check_service 8080 "OAuth Server" "http://localhost:8080" "oauth_server/app.py|PHI-OAuth-Server" || true
check_service 8081 "AskPHI Widget Service" "http://localhost:8081" "widget_service/app.py|PHI-AskPHI-Widget" || true
check_service 8090 "Dominion Java Live Ops Site" "http://localhost:8090" "JavaLiveOpsSite|java_live_ops_site.sh" || true

echo -e "${CYAN}Summary:${NC} ${GREEN}$SERVICES_UP${NC}/${SERVICES_TOTAL} services operational"
echo ""

# Docker Status
echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${CYAN}DOCKER DESKTOP PRO CONFIGURATION${NC}"
echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

DOCKER_VERSION=$(docker --version 2>/dev/null || echo "Not installed")
DOCKER_COMPOSE_VERSION=$(docker-compose --version 2>/dev/null || echo "Not installed")

echo -e "${CYAN}Docker CLI:${NC} $DOCKER_VERSION"
echo -e "${CYAN}Docker Compose:${NC} $DOCKER_COMPOSE_VERSION"
echo ""

if $DOCKER_DAEMON_AVAILABLE; then
    echo -e "${GREEN}✓${NC} Docker Daemon: RUNNING"
    echo ""
    echo -e "${CYAN}Docker Configuration:${NC}"
    docker info 2>/dev/null | grep -E "Server Version|Storage Driver|Logging Driver|CPUs|Total Memory" | sed 's/^/  /'
    echo ""
    
    echo -e "${CYAN}Running Containers:${NC}"
    CONTAINER_COUNT=$(docker ps -q | wc -l)
    if [ $CONTAINER_COUNT -gt 0 ]; then
        docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" | sed 's/^/  /'
    else
        echo -e "  ${YELLOW}No containers running${NC}"
    fi
else
    if $DOCKER_RUNTIME_NA; then
        echo -e "${CYAN}i${NC}  Docker Daemon: N/A in this runtime"
        echo -e "${CYAN}  Docker checks are informational only${NC}"
    elif ! $DOCKER_CONTROL_AVAILABLE; then
        echo -e "${CYAN}i${NC}  Docker Daemon: unavailable"
        echo -e "${CYAN}  Docker checks are informational only${NC}"
    else
        echo -e "${YELLOW}⚠${NC}  Docker Daemon: NOT RUNNING"
    fi
    echo ""
    echo -e "${CYAN}Docker Desktop Pro Optimal Configuration:${NC}"
    echo -e "  ${BLUE}Recommended Settings:${NC}"
    echo -e "  ├─ CPUs: $CPU_COUNT cores (all available)"
    echo -e "  ├─ Memory: 48 GB (leaving 14GB for system)"
    echo -e "  ├─ Swap: 4 GB"
    echo -e "  ├─ Disk: 100 GB (dynamic allocation)"
    echo -e "  ├─ Storage Driver: overlay2"
    echo -e "  ├─ Log Driver: json-file"
    echo -e "  └─ Log Max Size: 10MB"
    echo ""
    echo -e "  ${BLUE}daemon.json Configuration:${NC}"
    cat << 'EOF' | sed 's/^/  /'
{
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "10m",
    "max-file": "3"
  },
  "storage-driver": "overlay2",
  "default-ulimits": {
    "nofile": {
      "Name": "nofile",
      "Hard": 64000,
      "Soft": 64000
    }
  },
  "max-concurrent-downloads": 10,
  "max-concurrent-uploads": 10,
  "insecure-registries": [],
  "registry-mirrors": []
}
EOF
    echo ""
fi

echo ""

# Network Status
echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${CYAN}NETWORK CONNECTIVITY${NC}"
echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

CONNECTIVITY_UP=0
CONNECTIVITY_TOTAL=8

check_endpoint() {
    local url=$1
    local name=$2
    
    if curl -s -m 2 -o /dev/null "$url/health" || curl -s -m 2 -o /dev/null "$url/healthz" || curl -s -m 2 -o /dev/null "$url"; then
        echo -e "${GREEN}✓${NC} $name: $url"
        CONNECTIVITY_UP=$((CONNECTIVITY_UP + 1))
        return 0
    else
        echo -e "${RED}✗${NC} $name: $url ${YELLOW}(not reachable)${NC}"
        return 1
    fi
}

check_endpoint "http://localhost:5000" "Command Center"
check_endpoint "http://localhost:5001" "Billing"
check_endpoint "http://localhost:5002" "Command Core"
check_endpoint "http://localhost:5003" "Sidecar"
check_endpoint "http://localhost:5004" "ChatGPT Gateway"
check_endpoint "http://localhost:8080" "OAuth"
check_endpoint "http://localhost:8081" "AskPHI Widget"
check_endpoint "http://localhost:8090" "Java Live Ops Site"
echo ""

# Process Status
echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${CYAN}RUNTIME PROCESSES${NC}"
echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

RUNTIME_PATTERN="python(3)? .*app\.py|python3 command_core\.py|python3 main\.py|gunicorn|uvicorn|flask run|JavaLiveOpsSite"
RUNTIME_PROCS=$(ps -eo pid,args | grep -E "$RUNTIME_PATTERN" | grep -v grep | wc -l)
echo -e "${CYAN}Active Runtime Services:${NC} $RUNTIME_PROCS"
echo ""
ps -eo pid=,args= | grep -E "$RUNTIME_PATTERN" | grep -v grep | awk '{printf "  %-8s %s\n", $1, substr($0, index($0,$2))}' | sed '1i\  PID      ARGS'
echo ""

# Telemetry Check
echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${CYAN}TELEMETRY & MONITORING${NC}"
echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TELEMETRY_DIR="$SCRIPT_DIR/telemetry"

if [ -d "$TELEMETRY_DIR" ]; then
    echo -e "${GREEN}✓${NC} Telemetry directory exists"
    
    # Check for telemetry files
    if [ -f "$TELEMETRY_DIR/system_status.json" ]; then
        echo -e "  ├─ System Status: ${GREEN}Available${NC}"
        LAST_UPDATED=$(stat -c %y "$TELEMETRY_DIR/system_status.json" 2>/dev/null | cut -d. -f1 || echo "Unknown")
        LAST_UPDATED_EPOCH=$(stat -c %Y "$TELEMETRY_DIR/system_status.json" 2>/dev/null || echo 0)
        NOW_EPOCH=$(date +%s)
        AGE_HOURS=$(( (NOW_EPOCH - LAST_UPDATED_EPOCH) / 3600 ))
        if [ "$LAST_UPDATED_EPOCH" -gt 0 ] && [ "$AGE_HOURS" -gt 24 ]; then
            echo -e "  ├─ Last Updated: $LAST_UPDATED"
            echo -e "  └─ Freshness: ${YELLOW}STALE (${AGE_HOURS}h old)${NC}"
        else
            echo -e "  └─ Last Updated: $LAST_UPDATED"
        fi
    else
        echo -e "  └─ System Status: ${YELLOW}Not found${NC}"
    fi
else
    echo -e "${YELLOW}⚠${NC}  Telemetry directory not found"
fi
echo ""

# Live Ops Score
echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${CYAN}LIVE OPS READINESS SCORE${NC}"
echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

SCORE=0
MAX_SCORE=100
APPLICABLE_MAX_SCORE=$((MAX_SCORE - 20 + DOCKER_POINTS_AVAILABLE))

# Services (40 points - 10 each for primary services)
SERVICE_POINTS=$((SERVICES_UP * 40 / SERVICES_TOTAL))
SCORE=$((SCORE + SERVICE_POINTS))

# System Resources (30 points)
MEM_PERCENT=$(free | awk '/Mem:/ {printf "%.0f", $7/$2 * 100}')
if [ $MEM_PERCENT -gt 50 ]; then
    SCORE=$((SCORE + 30))
elif [ $MEM_PERCENT -gt 25 ]; then
    SCORE=$((SCORE + 20))
else
    SCORE=$((SCORE + 10))
fi

# Docker (20 points)
if $DOCKER_DAEMON_AVAILABLE; then
    SCORE=$((SCORE + 20))
fi

# Connectivity (10 points)
CONNECTIVITY=$((CONNECTIVITY_UP * 10 / CONNECTIVITY_TOTAL))
SCORE=$((SCORE + CONNECTIVITY))

echo -e "${CYAN}Overall Score:${NC} ${BOLD}${SCORE}/${MAX_SCORE}${NC}"
if [ "$APPLICABLE_MAX_SCORE" -lt "$MAX_SCORE" ]; then
    NORMALIZED_SCORE=$((SCORE * MAX_SCORE / APPLICABLE_MAX_SCORE))
    echo -e "${CYAN}Applicable Score:${NC} ${BOLD}${SCORE}/${APPLICABLE_MAX_SCORE}${NC} ${YELLOW}(Docker excluded in this runtime)${NC}"
    echo -e "${CYAN}Normalized Score:${NC} ${BOLD}${NORMALIZED_SCORE}/${MAX_SCORE}${NC}"
fi
echo ""

ASSESSMENT_SCORE=$SCORE
if [ "$APPLICABLE_MAX_SCORE" -lt "$MAX_SCORE" ]; then
    ASSESSMENT_SCORE=$((SCORE * MAX_SCORE / APPLICABLE_MAX_SCORE))
fi

ALL_SERVICES_OPERATIONAL=false
ALL_CONNECTIVITY_OPERATIONAL=false
[ "$SERVICES_UP" -eq "$SERVICES_TOTAL" ] && ALL_SERVICES_OPERATIONAL=true
[ "$CONNECTIVITY_UP" -eq "$CONNECTIVITY_TOTAL" ] && ALL_CONNECTIVITY_OPERATIONAL=true

if [ $ASSESSMENT_SCORE -ge 90 ] && $ALL_SERVICES_OPERATIONAL && $ALL_CONNECTIVITY_OPERATIONAL; then
    echo -e "${GREEN}✅ EXCELLENT${NC} - All systems optimal"
elif [ $ASSESSMENT_SCORE -ge 70 ]; then
    echo -e "${GREEN}✓ GOOD${NC} - Core systems operational"
elif [ $ASSESSMENT_SCORE -ge 50 ]; then
    echo -e "${YELLOW}⚠ FAIR${NC} - Some systems need attention"
else
    echo -e "${RED}✗ ATTENTION NEEDED${NC} - Critical systems offline"
fi

echo ""
echo -e "${BOLD}Breakdown:${NC}"
echo -e "  ├─ Services: ${SERVICE_POINTS}/40"
echo -e "  ├─ Resources: ${MEM_PERCENT}% memory available"
if $DOCKER_DAEMON_AVAILABLE; then
    echo -e "  ├─ Docker: 20/20"
elif $DOCKER_RUNTIME_NA || [ "$DOCKER_POINTS_AVAILABLE" -eq 0 ]; then
    echo -e "  ├─ Docker: N/A ${YELLOW}(informational only in this runtime)${NC}"
else
    echo -e "  ├─ Docker: 0/20 ${YELLOW}(daemon not running)${NC}"
fi
echo -e "  └─ Connectivity: ${CONNECTIVITY}/10"
echo ""

echo -e "${MAGENTA}═══════════════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}Verification Complete!${NC}"
echo -e "${MAGENTA}═══════════════════════════════════════════════════════════════════${NC}"
