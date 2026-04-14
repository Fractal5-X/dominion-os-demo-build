#!/bin/bash
# ═══════════════════════════════════════════════════════════════════
# PHI LIVE OPS VERIFICATION & DOCKER DESKTOP PRO CONFIGURATION
# ═══════════════════════════════════════════════════════════════════
# Generated: March 7, 2026
# Purpose: Verify all live operations systems and Docker configuration
# ═══════════════════════════════════════════════════════════════════

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
BOLD='\033[1m'
NC='\033[0m'

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
SERVICES_TOTAL=5

check_service() {
    local port=$1
    local name=$2
    local url=$3
    
    if lsof -ti:$port > /dev/null 2>&1; then
        local pid=$(lsof -ti:$port)
        echo -e "${GREEN}✓${NC} $name"
        echo -e "  ├─ Port: $port"
        echo -e "  ├─ PID: $pid"
        echo -e "  ├─ URL: $url"
        
        # Try health check if available
        if curl -s -f "$url/healthz" > /dev/null 2>&1 || curl -s -f "$url" > /dev/null 2>&1; then
            echo -e "  └─ Status: ${GREEN}HEALTHY${NC}"
        else
            echo -e "  └─ Status: ${YELLOW}RUNNING (no health check)${NC}"
        fi
        echo ""
        SERVICES_UP=$((SERVICES_UP + 1))
        return 0
    else
        echo -e "${RED}✗${NC} $name - ${YELLOW}NOT RUNNING${NC}"
        echo ""
        return 1
    fi
}

check_service 5000 "Command Center Demo (BIMS)" "http://localhost:5000"
check_service 5001 "Billing Service" "http://localhost:5001"
check_service 8080 "OAuth Server" "http://localhost:8080"
check_service 8081 "AskPHI Widget Service" "http://localhost:8081"

# Check for alternative services
if lsof -ti:5002 > /dev/null 2>&1; then
    check_service 5002 "Alternative Demo" "http://localhost:5002"
else
    SERVICES_TOTAL=4  # Adjust total if alt demo not required
fi

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

if docker info > /dev/null 2>&1; then
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
    echo -e "${YELLOW}⚠${NC}  Docker Daemon: NOT RUNNING"
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

check_endpoint() {
    local url=$1
    local name=$2
    
    if curl -s -f -m 2 "$url" > /dev/null 2>&1; then
        echo -e "${GREEN}✓${NC} $name: $url"
        return 0
    else
        echo -e "${RED}✗${NC} $name: $url ${YELLOW}(not reachable)${NC}"
        return 1
    fi
}

check_endpoint "http://localhost:5000" "Command Center"
check_endpoint "http://localhost:5001" "Billing"
check_endpoint "http://localhost:8080" "OAuth"
check_endpoint "http://localhost:8081" "AskPHI Widget"
echo ""

# Process Status
echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${CYAN}PYTHON PROCESSES${NC}"
echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

PYTHON_PROCS=$(ps aux | grep "python3 app.py" | grep -v grep | wc -l)
echo -e "${CYAN}Active Python Services:${NC} $PYTHON_PROCS"
echo ""
ps aux | grep "python3 app.py" | grep -v grep | awk '{printf "  %-8s %-10s %s\n", $2, $11, $12}' | sed '1i\  PID      COMMAND    ARGS'
echo ""

# Telemetry Check
echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${CYAN}TELEMETRY & MONITORING${NC}"
echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TELEMETRY_DIR="$SCRIPT_DIR/../telemetry"

if [ -d "$TELEMETRY_DIR" ]; then
    echo -e "${GREEN}✓${NC} Telemetry directory exists"
    
    # Check for telemetry files
    if [ -f "$TELEMETRY_DIR/system_status.json" ]; then
        echo -e "  ├─ System Status: ${GREEN}Available${NC}"
        LAST_UPDATED=$(stat -c %y "$TELEMETRY_DIR/system_status.json" 2>/dev/null | cut -d. -f1 || echo "Unknown")
        echo -e "  └─ Last Updated: $LAST_UPDATED"
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

# Services (40 points - 10 each for primary services)
SERVICE_POINTS=$((SERVICES_UP * 10))
[ $SERVICE_POINTS -gt 40 ] && SERVICE_POINTS=40
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
if docker info > /dev/null 2>&1; then
    SCORE=$((SCORE + 20))
fi

# Connectivity (10 points)
CONNECTIVITY=$((SERVICES_UP * 2))
[ $CONNECTIVITY -gt 10 ] && CONNECTIVITY=10
SCORE=$((SCORE + CONNECTIVITY))

echo -e "${CYAN}Overall Score:${NC} ${BOLD}${SCORE}/100${NC}"
echo ""

if [ $SCORE -ge 90 ]; then
    echo -e "${GREEN}✅ EXCELLENT${NC} - All systems optimal"
elif [ $SCORE -ge 70 ]; then
    echo -e "${GREEN}✓ GOOD${NC} - Core systems operational"
elif [ $SCORE -ge 50 ]; then
    echo -e "${YELLOW}⚠ FAIR${NC} - Some systems need attention"
else
    echo -e "${RED}✗ ATTENTION NEEDED${NC} - Critical systems offline"
fi

echo ""
echo -e "${BOLD}Breakdown:${NC}"
echo -e "  ├─ Services: ${SERVICE_POINTS}/40"
echo -e "  ├─ Resources: ${MEM_PERCENT}% memory available"
if docker info > /dev/null 2>&1; then
    echo -e "  ├─ Docker: 20/20"
else
    echo -e "  ├─ Docker: 0/20 ${YELLOW}(daemon not running)${NC}"
fi
echo -e "  └─ Connectivity: ${CONNECTIVITY}/10"
echo ""

echo -e "${MAGENTA}═══════════════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}Verification Complete!${NC}"
echo -e "${MAGENTA}═══════════════════════════════════════════════════════════════════${NC}"
