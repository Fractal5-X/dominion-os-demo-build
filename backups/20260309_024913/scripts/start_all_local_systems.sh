#!/bin/bash
# ═══════════════════════════════════════════════════════════════════
# PHI LOCAL SYSTEMS STARTUP - COMPLETE ORCHESTRATION
# ═══════════════════════════════════════════════════════════════════
# Purpose: Start VS Code, PHI MCP Server, Docker Services, Command Center
# Mode: Local Development with Full Sovereignty
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

echo ""
echo "═══════════════════════════════════════════════════════════════════"
echo "  🚀 PHI LOCAL SYSTEMS STARTUP"
echo "═══════════════════════════════════════════════════════════════════"
echo "  Timestamp: $(date '+%Y-%m-%d %H:%M:%S')"
echo "═══════════════════════════════════════════════════════════════════"
echo ""

# Function to check if a process is running
check_running() {
    local name="$1"
    local pattern="$2"
    echo -e "${BLUE}[CHECK]${NC} $name..."
    if pgrep -f "$pattern" > /dev/null 2>&1; then
        echo -e "${GREEN}  ✅ $name is running${NC}"
        return 0
    else
        echo -e "${YELLOW}  ⚠️  $name is not running${NC}"
        return 1
    fi
}

# Function to start a service
start_service() {
    local name="$1"
    local command="$2"
    local log_file="$3"
    
    echo -e "${BLUE}[START]${NC} $name..."
    if eval "$command" > "$log_file" 2>&1 &
    then
        echo -e "${GREEN}  ✅ $name started (PID: $!)${NC}"
        echo -e "${CYAN}  📋 Log: $log_file${NC}"
        return 0
    else
        echo -e "${RED}  ❌ Failed to start $name${NC}"
        return 1
    fi
}

# ═══════════════════════════════════════════════════════════════════
# STEP 1: VS CODE VERIFICATION
# ═══════════════════════════════════════════════════════════════════
echo -e "${BOLD}${MAGENTA}[1/5] VS Code Status${NC}"
echo "───────────────────────────────────────────────────────────────────"

if check_running "VS Code Server" "vscode-server"; then
    echo -e "${GREEN}  ✨ VS Code is active${NC}"
else
    echo -e "${YELLOW}  ℹ️  VS Code not detected (may be running on host)${NC}"
fi
echo ""

# ═══════════════════════════════════════════════════════════════════
# STEP 2: PHI MCP SERVER
# ═══════════════════════════════════════════════════════════════════
echo -e "${BOLD}${MAGENTA}[2/5] PHI MCP Server${NC}"
echo "───────────────────────────────────────────────────────────────────"

MCP_DIR="/workspaces/phi-mcp-server"
MCP_LOG="$MCP_DIR/phi-server.log"

if [ -d "$MCP_DIR" ]; then
    cd "$MCP_DIR"
    
    # Check if already running
    if check_running "PHI MCP Server" "main.py"; then
        echo -e "${GREEN}  ✨ PHI MCP Server already running${NC}"
    else
        # Check for venv
        if [ -d "venv" ]; then
            echo -e "${BLUE}  🔧 Activating virtual environment...${NC}"
            source venv/bin/activate
        else
            echo -e "${YELLOW}  ⚠️  Creating virtual environment...${NC}"
            python3 -m venv venv
            source venv/bin/activate
            pip install -r requirements.txt
        fi
        
        # Start MCP server
        start_service "PHI MCP Server" "python3 main.py" "$MCP_LOG"
        sleep 2
    fi
else
    echo -e "${RED}  ❌ PHI MCP Server directory not found: $MCP_DIR${NC}"
fi
echo ""

# ═══════════════════════════════════════════════════════════════════
# STEP 3: DOCKER SERVICES
# ═══════════════════════════════════════════════════════════════════
echo -e "${BOLD}${MAGENTA}[3/5] Docker Services${NC}"
echo "───────────────────────────────────────────────────────────────────"

DOCKER_DIR="/workspaces/dominion-os-demo-build/scripts"

if [ -f "$DOCKER_DIR/docker-compose.yml" ]; then
    cd "$DOCKER_DIR"
    
    echo -e "${BLUE}  🐳 Checking Docker status...${NC}"
    if docker info > /dev/null 2>&1; then
        echo -e "${GREEN}  ✅ Docker is running${NC}"
        
        echo -e "${BLUE}  🔧 Starting Docker Compose services...${NC}"
        docker-compose up -d
        
        echo -e "${BLUE}  📊 Docker services status:${NC}"
        docker-compose ps
        
        echo -e "${GREEN}  ✨ Docker services started${NC}"
    else
        echo -e "${RED}  ❌ Docker is not running${NC}"
        echo -e "${YELLOW}  💡 You may need to start Docker manually${NC}"
    fi
else
    echo -e "${YELLOW}  ⚠️  docker-compose.yml not found${NC}"
fi
echo ""

# ═══════════════════════════════════════════════════════════════════
# STEP 4: COMMAND CENTER STATUS
# ═══════════════════════════════════════════════════════════════════
echo -e "${BOLD}${MAGENTA}[4/5] Command Center Status${NC}"
echo "───────────────────────────────────────────────────────────────────"

COMMAND_CENTER_DIR="/workspaces/dominion-command-center"

if [ -d "$COMMAND_CENTER_DIR" ]; then
    echo -e "${GREEN}  ✅ Command Center directory found${NC}"
    echo -e "${CYAN}  📂 Location: $COMMAND_CENTER_DIR${NC}"
    
    # Check for any running processes
    if check_running "Command Center Services" "dominion"; then
        echo -e "${GREEN}  ✨ Command Center services detected${NC}"
    else
        echo -e "${YELLOW}  ℹ️  No active Command Center services detected${NC}"
    fi
else
    echo -e "${YELLOW}  ⚠️  Command Center directory not found${NC}"
fi
echo ""

# ═══════════════════════════════════════════════════════════════════
# STEP 5: SYSTEM STATUS SUMMARY
# ═══════════════════════════════════════════════════════════════════
echo -e "${BOLD}${MAGENTA}[5/5] System Status Summary${NC}"
echo "───────────────────────────────────────────────────────────────────"

echo -e "${BOLD}📊 Running Services:${NC}"
echo ""

# VS Code
if pgrep -f "vscode-server" > /dev/null 2>&1; then
    echo -e "  ${GREEN}✅${NC} VS Code Server"
else
    echo -e "  ${YELLOW}⚠️${NC}  VS Code Server (may be on host)"
fi

# PHI MCP Server
if pgrep -f "main.py" > /dev/null 2>&1; then
    echo -e "  ${GREEN}✅${NC} PHI MCP Server (http://127.0.0.1:8000/mcp)"
else
    echo -e "  ${RED}❌${NC} PHI MCP Server"
fi

# Docker Services
if docker info > /dev/null 2>&1; then
    DOCKER_RUNNING=$(docker ps --format "{{.Names}}" | wc -l)
    if [ $DOCKER_RUNNING -gt 0 ]; then
        echo -e "  ${GREEN}✅${NC} Docker Services ($DOCKER_RUNNING containers running)"
    else
        echo -e "  ${YELLOW}⚠️${NC}  Docker Services (0 containers running)"
    fi
else
    echo -e "  ${RED}❌${NC} Docker Services"
fi

echo ""
echo -e "${BOLD}🌐 Service URLs:${NC}"
echo ""
echo -e "  ${CYAN}•${NC} PHI MCP Server:    ${CYAN}http://127.0.0.1:8000/mcp${NC}"
echo -e "  ${CYAN}•${NC} OAuth Server:      ${CYAN}http://localhost:8080${NC}"
echo -e "  ${CYAN}•${NC} AskPhi Widget:     ${CYAN}http://localhost:8081${NC}"
echo -e "  ${CYAN}•${NC} PostgreSQL:        ${CYAN}localhost:5432${NC}"
echo -e "  ${CYAN}•${NC} Redis:             ${CYAN}localhost:6379${NC}"
echo -e "  ${CYAN}•${NC} Prometheus:        ${CYAN}http://localhost:9090${NC}"
echo -e "  ${CYAN}•${NC} Grafana:           ${CYAN}http://localhost:3000${NC}"
echo ""
echo -e "${BOLD}📋 Logs:${NC}"
echo ""
echo -e "  ${CYAN}•${NC} PHI MCP Server:    ${CYAN}$MCP_LOG${NC}"
echo -e "  ${CYAN}•${NC} Docker Services:   ${CYAN}docker-compose logs -f${NC}"
echo ""
echo "═══════════════════════════════════════════════════════════════════"
echo -e "  ${GREEN}${BOLD}✨ PHI LOCAL SYSTEMS STARTUP COMPLETE${NC}"
echo "═══════════════════════════════════════════════════════════════════"
echo ""
