#!/bin/bash
# ═══════════════════════════════════════════════════════════════════
# PHI SYSTEMS - QUICK START
# ═══════════════════════════════════════════════════════════════════

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_DIR="$SCRIPT_DIR/logs"
mkdir -p "$LOG_DIR"

echo -e "${MAGENTA}╔═══════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${MAGENTA}║              PHI SYSTEMS - QUICK START                            ║${NC}"
echo -e "${MAGENTA}╚═══════════════════════════════════════════════════════════════════╝${NC}"
echo ""

# Activate virtual environment if available
if [ -f "$SCRIPT_DIR/.venv/bin/activate" ]; then
    source "$SCRIPT_DIR/.venv/bin/activate"
    echo -e "${GREEN}✓${NC} Virtual environment activated"
fi

# Check for running services
check_port() {
    local port=$1
    lsof -ti:$port > /dev/null 2>&1
}

start_python_service() {
    local name=$1
    local app_path=$2
    local port=$3
    local work_dir=$(dirname "$app_path")
    
    echo -n -e "${BLUE}Starting $name on port $port...${NC} "
    
    if check_port $port; then
        echo -e "${GREEN}Already running${NC}"
        return 0
    fi
    
    if [ ! -f "$app_path" ]; then
        echo -e "${YELLOW}Not found - skipped${NC}"
        return 1
    fi
    
    cd "$work_dir"
    export FLASK_APP=app.py
    export FLASK_ENV=development
    export PORT=$port
    
    # Activate virtual environment if available
    if [ -f "$SCRIPT_DIR/.venv/bin/activate" ]; then
        source "$SCRIPT_DIR/.venv/bin/activate"
    fi
    
    nohup python3 app.py > "$LOG_DIR/$(basename $name).log" 2>&1 &
    local pid=$!
    echo $pid > "$LOG_DIR/$(basename $name).pid"
    
    sleep 2
    
    if ps -p $pid > /dev/null 2>&1; then
        if check_port $port; then
            echo -e "${GREEN}✓ Started (PID: $pid)${NC}"
        else
            echo -e "${YELLOW}⚠ Running but port not ready (PID: $pid)${NC}"
        fi
    else
        echo -e "${RED}✗ Failed${NC}"
        tail -5 "$LOG_DIR/$(basename $name).log" 2>/dev/null | sed 's/^/  /'
    fi
}

start_background_script() {
    local name=$1
    local script=$2
    
    echo -n -e "${BLUE}Starting $name...${NC} "
    
    if pgrep -f "$script" > /dev/null; then
        echo -e "${GREEN}Already running${NC}"
        return 0
    fi
    
    if [ ! -f "$script" ]; then
        echo -e "${YELLOW}Not found - skipped${NC}"
        return 1
    fi
    
    nohup bash "$script" > "$LOG_DIR/$(basename $script .sh).log" 2>&1 &
    local pid=$!
    echo $pid > "$LOG_DIR/$(basename $script .sh).pid"
    
    sleep 1
    
    if ps -p $pid > /dev/null 2>&1; then
        echo -e "${GREEN}✓ Started (PID: $pid)${NC}"
    else
        echo -e "${RED}✗ Failed${NC}"
    fi
}

echo ""
echo -e "${CYAN}━━━ CORE SERVICES ━━━${NC}"

# Start Command Center Demo (Financial BIMS)
start_python_service "Command-Center-Demo" \
                     "/workspaces/dominion-command-center/demo/app.py" \
                     "5000"

# Start Billing Service
start_python_service "Billing-Service" \
                     "/workspaces/dominion-command-center/billing-service/app.py" \
                     "5001"

# Start OAuth Server (if dependencies installed)
start_python_service "OAuth-Server" \
                     "/workspaces/dominion-os-demo-build/oauth_server/app.py" \
                     "8080"

# Start Widget Service  
start_python_service "Widget-Service" \
                     "/workspaces/dominion-os-demo-build/widget_service/app.py" \
                     "8081"

echo ""
echo -e "${CYAN}━━━ BACKGROUND SERVICES ━━━${NC}"

# Start background monitoring (non-blocking)
if [ -f "$SCRIPT_DIR/phi_background_completion_monitor.sh" ]; then
    if ! pgrep -f "phi_background_completion_monitor" > /dev/null; then
        echo -n -e "${BLUE}Starting background monitor...${NC} "
        nohup bash "$SCRIPT_DIR/phi_background_completion_monitor.sh" > "$LOG_DIR/background_monitor.log" 2>&1 &
        echo -e "${GREEN}✓ Started${NC}"
    else
        echo -e "${GREEN}✓ Background monitor already running${NC}"
    fi
fi

# Start Channel Connect SaaS Service
if [ -f "$SCRIPT_DIR/phi_channel_connect.sh" ]; then
    if ! pgrep -f "phi_channel_connect" > /dev/null; then
        echo -n -e "${BLUE}Starting Channel Connect SaaS Service...${NC} "
        nohup bash "$SCRIPT_DIR/phi_channel_connect.sh" start > "$LOG_DIR/channel_connect.log" 2>&1 &
        echo -e "${GREEN}✓ Started${NC}"
    else
        echo -e "${GREEN}✓ Channel Connect SaaS Service already running${NC}"
    fi
fi

# Start Google Workspace Integration
if [ -f "$SCRIPT_DIR/phi_google_workspace.sh" ]; then
    if ! pgrep -f "phi_google_workspace" > /dev/null; then
        echo -n -e "${BLUE}Starting Google Workspace Integration...${NC} "
        nohup bash "$SCRIPT_DIR/phi_google_workspace.sh" start > "$LOG_DIR/google_workspace.log" 2>&1 &
        echo -e "${GREEN}✓ Started${NC}"
    else
        echo -e "${GREEN}✓ Google Workspace Integration already running${NC}"
    fi
fi

echo ""
echo -e "${CYAN}━━━ SYSTEM STATUS ━━━${NC}"
echo ""

# Count running services
SERVICE_COUNT=0
for pidfile in "$LOG_DIR"/*.pid; do
    if [ -f "$pidfile" ]; then
        PID=$(cat "$pidfile")
        if ps -p $PID > /dev/null 2>&1; then
            ((SERVICE_COUNT++))
        fi
    fi
done

echo -e "${GREEN}Active Services: $SERVICE_COUNT${NC}"
echo ""

if [ $SERVICE_COUNT -gt 0 ]; then
    echo "Service URLs:"
    [ -f "$LOG_DIR/Command-Center-Demo.pid" ] && check_port 5000 && echo "  • Command Center Demo (BIMS): http://localhost:5000"
    [ -f "$LOG_DIR/Billing-Service.pid" ] && check_port 5001 && echo "  • Billing Service: http://localhost:5001"
    [ -f "$LOG_DIR/OAuth-Server.pid" ] && check_port 8080 && echo "  • OAuth Server: http://localhost:8080"
    [ -f "$LOG_DIR/Widget-Service.pid" ] && check_port 8081 && echo "  • Widget Service: http://localhost:8081"
    echo ""
fi

echo "Management:"
echo "  • View logs: tail -f $LOG_DIR/<service>.log"
echo "  • Stop all: pkill -f 'python3.*app.py'"
echo "  • Restart: bash $0"
echo ""

echo -e "${GREEN}═══════════════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}PHI Systems Startup Complete!${NC}"
echo -e "${GREEN}═══════════════════════════════════════════════════════════════════${NC}"
