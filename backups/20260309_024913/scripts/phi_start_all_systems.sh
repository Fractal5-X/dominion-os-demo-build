#!/bin/bash
# ═══════════════════════════════════════════════════════════════════
# PHI COMMAND CENTER - START ALL SYSTEMS
# ═══════════════════════════════════════════════════════════════════
# Purpose: Start all Dominion OS systems and services
# Mode: Comprehensive activation with intelligent process management
# Generated: March 7, 2026
# ═══════════════════════════════════════════════════════════════════

# set -e

# Color definitions
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
BOLD='\033[1m'
NC='\033[0m'

# Directories
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE_ROOT="$(dirname "$SCRIPT_DIR")"
LOG_DIR="$SCRIPT_DIR/logs"
mkdir -p "$LOG_DIR"

STARTUP_LOG="$LOG_DIR/phi_startup_$(date +%Y%m%d_%H%M%S).log"

# Functions
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$STARTUP_LOG"
}

success() {
    echo -e "${GREEN}✅ $1${NC}" | tee -a "$STARTUP_LOG"
}

warning() {
    echo -e "${YELLOW}⚠️  $1${NC}" | tee -a "$STARTUP_LOG"
}

error() {
    echo -e "${RED}❌ $1${NC}" | tee -a "$STARTUP_LOG"
}

info() {
    echo -e "${BLUE}ℹ️  $1${NC}" | tee -a "$STARTUP_LOG"
}

section() {
    echo ""
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}" | tee -a "$STARTUP_LOG"
    echo -e "${CYAN}$1${NC}" | tee -a "$STARTUP_LOG"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}" | tee -a "$STARTUP_LOG"
}

start_service() {
    local service_name="$1"
    local service_path="$2"
    local start_cmd="$3"
    local port="$4"
    
    log "Starting $service_name..."
    
    if [ ! -f "$service_path" ]; then
        warning "$service_name not found at $service_path - skipping"
        return 1
    fi
    
    # Check if already running
    if lsof -ti:$port > /dev/null 2>&1; then
        success "$service_name already running on port $port"
        return 0
    fi
    
    # Start service in background
    cd "$(dirname "$service_path")"
    if [ -f ".venv/bin/activate" ]; then
        VENV_ACTIVATE=".venv/bin/activate"
    else
        VENV_ACTIVATE="$SCRIPT_DIR/.venv/bin/activate"
    fi
    nohup bash -c "source $VENV_ACTIVATE 2>/dev/null; $start_cmd" > "$LOG_DIR/${service_name}.log" 2>&1 &
    local pid=$!
    echo $pid > "$LOG_DIR/${service_name}.pid"
    
    # Wait for service to start (with timeout)
    local timeout=10
    local elapsed=0
    while [ $elapsed -lt $timeout ]; do
        if lsof -ti:$port > /dev/null 2>&1; then
            success "$service_name started successfully (PID: $pid, Port: $port)"
            return 0
        fi
        sleep 1
        ((elapsed++))
    done
    
    # Check if process is still alive but port not bound
    if ps -p $pid > /dev/null 2>&1; then
        warning "$service_name started but port $port not ready yet (PID: $pid)"
        return 0
    else
        error "$service_name failed to start - check $LOG_DIR/${service_name}.log"
        [ -f "$LOG_DIR/${service_name}.log" ] && tail -3 "$LOG_DIR/${service_name}.log"
        return 1
    fi
}

# Header
clear
echo -e "${MAGENTA}╔═══════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${MAGENTA}║                                                                   ║${NC}"
echo -e "${MAGENTA}║              PHI SYSTEMS - COMPREHENSIVE STARTUP                  ║${NC}"
echo -e "${MAGENTA}║                                                                   ║${NC}"
echo -e "${MAGENTA}║              Dominion OS & SaaS Suite                             ║${NC}"
echo -e "${MAGENTA}║              All Systems Activation                               ║${NC}"
echo -e "${MAGENTA}║                                                                   ║${NC}"
echo -e "${MAGENTA}╚═══════════════════════════════════════════════════════════════════╝${NC}"
echo ""
log "═══════════════════════════════════════════════════════════════════"
log "PHI System Startup initiated at $(date '+%Y-%m-%d %H:%M:%S %Z')"
log "═══════════════════════════════════════════════════════════════════"
echo ""

# ═══════════════════════════════════════════════════════════════════
# PHASE 1: ENVIRONMENT VERIFICATION
# ═══════════════════════════════════════════════════════════════════
section "PHASE 1: ENVIRONMENT VERIFICATION"

log "Checking Python virtual environment..."
if [ -f "$SCRIPT_DIR/.venv/bin/activate" ]; then
    source "$SCRIPT_DIR/.venv/bin/activate"
    success "Python virtual environment activated"
else
    warning "Virtual environment not found - using system Python"
fi

log "Verifying Python installation..."
if command -v python3 &> /dev/null; then
    PYTHON_VERSION=$(python3 --version)
    success "Python available: $PYTHON_VERSION"
else
    error "Python3 not found! Please install Python 3.8+"
    exit 1
fi

log "Checking required directories..."
for dir in "$LOG_DIR" "$SCRIPT_DIR/data" "$SCRIPT_DIR/exports" "$SCRIPT_DIR/telemetry"; do
    if [ ! -d "$dir" ]; then
        mkdir -p "$dir"
        info "Created directory: $dir"
    fi
done
success "Directory structure verified"

# ═══════════════════════════════════════════════════════════════════
# PHASE 2: CORE SERVICES STARTUP
# ═══════════════════════════════════════════════════════════════════
section "PHASE 2: CORE SERVICES STARTUP"

# OAuth Server
if [ -f "/workspaces/dominion-os-demo-build/oauth_server/app.py" ]; then
    start_service "PHI-OAuth-Server" \
                  "/workspaces/dominion-os-demo-build/oauth_server/app.py" \
                  "python3 app.py" \
                  "8080"
fi

# Widget Service (AskPHI)
if [ -f "/workspaces/dominion-os-demo-build/widget_service/app.py" ]; then
    start_service "PHI-AskPHI-Widget" \
                  "/workspaces/dominion-os-demo-build/widget_service/app.py" \
                  "python3 app.py" \
                  "8081"
fi

# ═══════════════════════════════════════════════════════════════════
# PHASE 3: COMMAND CENTER SERVICES
# ═══════════════════════════════════════════════════════════════════
section "PHASE 3: COMMAND CENTER SERVICES"

# Main Command Center
if [ -f "/workspaces/dominion-command-center/src/main.py" ]; then
    start_service "Dominion-Command-Center" \
                  "/workspaces/dominion-command-center/src/main.py" \
                  "python3 main.py" \
                  "5000"
fi

# Billing Service
if [ -f "/workspaces/dominion-command-center/billing-service/app.py" ]; then
    start_service "Billing-Service" \
                  "/workspaces/dominion-command-center/billing-service/app.py" \
                  "python3 app.py" \
                  "5001"
fi

# Demo Application
if [ -f "/workspaces/dominion-command-center/demo/app.py" ]; then
    start_service "Demo-Application" \
                  "/workspaces/dominion-command-center/demo/app.py" \
                  "PORT=5002 $SCRIPT_DIR/.venv/bin/python app.py" \
                  "5002"
fi

# Sidecar Service
if [ -f "/workspaces/dominion-command-center/sidecar/app.py" ]; then
    start_service "Sidecar-Service" \
                  "/workspaces/dominion-command-center/sidecar/app.py" \
                  "python3 app.py" \
                  "5003"
fi

# ChatGPT Gateway
if [ -f "/workspaces/dominion-command-center/chatgpt-gateway/main.py" ]; then
    start_service "ChatGPT-Gateway" \
                  "/workspaces/dominion-command-center/chatgpt-gateway/main.py" \
                  "python3 main.py" \
                  "5004"
fi

# ═══════════════════════════════════════════════════════════════════
# PHASE 4: LEGACY SYSTEMS
# ═══════════════════════════════════════════════════════════════════
section "PHASE 4: LEGACY SYSTEMS"

# Politics Local (Legacy)
if [ -f "/workspaces/dominion-os-1.0-politics.local-20260305/app.py" ]; then
    start_service "Politics-Local-Legacy" \
                  "/workspaces/dominion-os-1.0-politics.local-20260305/app.py" \
                  "python3 app.py" \
                  "5005"
fi

# ═══════════════════════════════════════════════════════════════════
# PHASE 5: MONITORING & BACKGROUND SERVICES
# ═══════════════════════════════════════════════════════════════════
section "PHASE 5: MONITORING & BACKGROUND SERVICES"

# Start background monitoring
if [ -f "$SCRIPT_DIR/phi_background_completion_monitor.sh" ]; then
    log "Starting background completion monitor..."
    nohup bash "$SCRIPT_DIR/phi_background_completion_monitor.sh" > "$LOG_DIR/background_monitor.log" 2>&1 &
    echo $! > "$LOG_DIR/background_monitor.pid"
    success "Background completion monitor started"
fi

# Start cost optimization (if not already running)
if [ -f "$SCRIPT_DIR/phi_cost_minimization_simple.sh" ]; then
    if ! pgrep -f "phi_cost_minimization" > /dev/null; then
        log "Starting cost minimization engine..."
        nohup bash "$SCRIPT_DIR/phi_cost_minimization_simple.sh" > "$LOG_DIR/cost_minimization.log" 2>&1 &
        echo $! > "$LOG_DIR/cost_minimization.pid"
        success "Cost minimization engine started"
    else
        success "Cost minimization engine already running"
    fi
fi

# ═══════════════════════════════════════════════════════════════════
# PHASE 6: SYSTEM STATUS VERIFICATION
# ═══════════════════════════════════════════════════════════════════
section "PHASE 6: SYSTEM STATUS VERIFICATION"

log "Checking all running services..."
echo ""
echo -e "${BOLD}Active Services:${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

SERVICE_COUNT=0
for pidfile in "$LOG_DIR"/*.pid; do
    if [ -f "$pidfile" ]; then
        SERVICE_NAME=$(basename "$pidfile" .pid)
        PID=$(cat "$pidfile")
        if ps -p $PID > /dev/null 2>&1; then
            PORT=$(lsof -Pan -p $PID -i 2>/dev/null | grep LISTEN | awk '{print $9}' | cut -d: -f2 | head -1)
            if [ -n "$PORT" ]; then
                echo -e "${GREEN}✓${NC} $SERVICE_NAME (PID: $PID) - Port: $PORT"
            else
                echo -e "${GREEN}✓${NC} $SERVICE_NAME (PID: $PID)"
            fi
            ((SERVICE_COUNT++))
        else
            echo -e "${RED}✗${NC} $SERVICE_NAME (not running)"
        fi
    fi
done

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

if [ $SERVICE_COUNT -gt 0 ]; then
    success "$SERVICE_COUNT service(s) running successfully"
else
    warning "No services currently running"
fi

# ═══════════════════════════════════════════════════════════════════
# PHASE 7: FINAL STATUS REPORT
# ═══════════════════════════════════════════════════════════════════
section "PHASE 7: STARTUP COMPLETE"

echo ""
echo -e "${BOLD}PHI System Status Report${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo -e "${CYAN}Startup Time:${NC} $(date '+%Y-%m-%d %H:%M:%S %Z')"
echo -e "${CYAN}Active Services:${NC} $SERVICE_COUNT"
echo -e "${CYAN}Log Directory:${NC} $LOG_DIR"
echo -e "${CYAN}Startup Log:${NC} $STARTUP_LOG"
echo ""

if [ $SERVICE_COUNT -gt 0 ]; then
    echo -e "${CYAN}Service URLs:${NC}"
    [ -f "$LOG_DIR/PHI-OAuth-Server.pid" ] && echo "  • OAuth Server: http://localhost:8080"
    [ -f "$LOG_DIR/PHI-AskPHI-Widget.pid" ] && echo "  • AskPHI Widget: http://localhost:8081"
    [ -f "$LOG_DIR/Dominion-Command-Center.pid" ] && echo "  • Command Center: http://localhost:5000"
    [ -f "$LOG_DIR/Billing-Service.pid" ] && echo "  • Billing Service: http://localhost:5001"
    [ -f "$LOG_DIR/Demo-Application.pid" ] && echo "  • Demo App: http://localhost:5002"
    [ -f "$LOG_DIR/Sidecar-Service.pid" ] && echo "  • Sidecar: http://localhost:5003"
    [ -f "$LOG_DIR/ChatGPT-Gateway.pid" ] && echo "  • ChatGPT Gateway: http://localhost:5004"
    echo ""
fi

echo -e "${CYAN}Management Commands:${NC}"
echo "  • View logs: tail -f $LOG_DIR/<service>.log"
echo "  • Stop all: pkill -f 'python3.*app.py'"
echo "  • Restart: bash $0"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

success "PHI System Startup Complete!"

log "═══════════════════════════════════════════════════════════════════"
log "Startup sequence completed successfully"
log "═══════════════════════════════════════════════════════════════════"
