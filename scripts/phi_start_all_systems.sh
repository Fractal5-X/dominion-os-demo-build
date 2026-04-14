#!/bin/bash
set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/public_repo_handoff.sh"
require_command_center_context "local live-ops startup"

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
DETACHED_EXEC_SCRIPT="$SCRIPT_DIR/detached_exec.sh"
mkdir -p "$LOG_DIR"

STARTUP_LOG="$LOG_DIR/phi_startup_$(date +%Y%m%d_%H%M%S).log"
TRACKED_PIDFILES=()
FAILED_SERVICES=()
CURRENT_SERVICE_NAME=""
CURRENT_SERVICE_LOG=""

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

load_env_file() {
    local env_file="$1"

    if [ ! -f "$env_file" ]; then
        return 0
    fi

    set -a
    # shellcheck disable=SC1090
    source "$env_file"
    set +a
    info "Loaded env file: $env_file"
}

record_failure() {
    local service_name="${1:-unknown-service}"

    for failed in "${FAILED_SERVICES[@]:-}"; do
        if [ "$failed" = "$service_name" ]; then
            return 0
        fi
    done

    FAILED_SERVICES+=("$service_name")
}

report_startup_failure() {
    local exit_code=$?
    local line_no="${1:-unknown}"

    if [ "$exit_code" -eq 0 ]; then
        return 0
    fi

    echo ""
    error "Startup aborted at line $line_no with exit code $exit_code"
    if [ -n "$CURRENT_SERVICE_NAME" ]; then
        error "Last startup action: $CURRENT_SERVICE_NAME"
    fi
    if [ -n "$CURRENT_SERVICE_LOG" ] && [ -f "$CURRENT_SERVICE_LOG" ]; then
        info "Last service log: $CURRENT_SERVICE_LOG"
        tail -n 10 "$CURRENT_SERVICE_LOG" | sed 's/^/  /'
    fi
    info "Startup log: $STARTUP_LOG"
}

section() {
    echo ""
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}" | tee -a "$STARTUP_LOG"
    echo -e "${CYAN}$1${NC}" | tee -a "$STARTUP_LOG"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}" | tee -a "$STARTUP_LOG"
}

is_truthy() {
    case "${1:-}" in
        1|true|TRUE|yes|YES|on|ON) return 0 ;;
        *) return 1 ;;
    esac
}

contains_csv_token() {
    local csv="${1:-}"
    local token="${2:-}"
    local normalized=",${csv// /},"
    [[ "$normalized" == *",$token,"* ]]
}

start_optional_background_service() {
    local service_name="$1"
    local start_cmd="$2"
    local process_pattern="$3"
    local pid_file="$4"
    local log_file="$5"

    if pgrep -f "$process_pattern" > /dev/null 2>&1; then
        success "$service_name already running"
        return 0
    fi

    log "Starting optional service: $service_name..."
    local pid
    pid=$(bash "$DETACHED_EXEC_SCRIPT" "$pid_file" "$log_file" "cd '$SCRIPT_DIR' && $start_cmd")
    TRACKED_PIDFILES+=("$pid_file")
    sleep 2

    if ps -p "$pid" > /dev/null 2>&1; then
        success "$service_name started (PID: $pid)"
    else
        warning "$service_name did not remain running - check $log_file"
    fi
}

gcloud_auth_available() {
    local project_probe="${GCP_PROJECT_PROBE:-dominion-os-1-0-main}"

    if ! command -v gcloud > /dev/null 2>&1; then
        return 1
    fi

    if ! gcloud auth print-access-token > /dev/null 2>&1; then
        return 1
    fi

    gcloud run services list --project "$project_probe" --limit 1 --format="value(metadata.name)" > /dev/null 2>&1
}

trap 'report_startup_failure $LINENO' ERR

start_service() {
    local service_name="$1"
    local service_path="$2"
    local start_cmd="$3"
    local port="$4"

    CURRENT_SERVICE_NAME="$service_name"
    CURRENT_SERVICE_LOG="$LOG_DIR/${service_name}.log"

    log "Starting $service_name..."

    if [ ! -f "$service_path" ]; then
        record_failure "$service_name"
        warning "$service_name not found at $service_path - skipping"
        return 1
    fi

    # Check if already running
    if lsof -ti:$port > /dev/null 2>&1; then
        local running_pid
        running_pid=$(lsof -ti:$port | head -1)
        echo "$running_pid" > "$LOG_DIR/${service_name}.pid"
        TRACKED_PIDFILES+=("$LOG_DIR/${service_name}.pid")
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
    local pid_file="$LOG_DIR/${service_name}.pid"
    local pid
    pid=$(bash "$DETACHED_EXEC_SCRIPT" "$pid_file" "$LOG_DIR/${service_name}.log" "source '$VENV_ACTIVATE' 2>/dev/null; $start_cmd")
    TRACKED_PIDFILES+=("$pid_file")

    # Wait for service to start (with timeout)
    local timeout=10
    local elapsed=0
    while [ $elapsed -lt $timeout ]; do
        if lsof -ti:$port > /dev/null 2>&1; then
            success "$service_name started successfully (PID: $pid, Port: $port)"
            CURRENT_SERVICE_NAME=""
            return 0
        fi
        sleep 1
        elapsed=$((elapsed + 1))
    done

    # Check if process is still alive but port not bound
    if ps -p $pid > /dev/null 2>&1; then
        warning "$service_name started but port $port not ready yet (PID: $pid)"
        CURRENT_SERVICE_NAME=""
        return 0
    else
        record_failure "$service_name"
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

load_env_file "$WORKSPACE_ROOT/.env"
load_env_file "$WORKSPACE_ROOT/.env.desktop-pro"
load_env_file "$SCRIPT_DIR/.env"

export GITHUB_CLIENT_ID="${GITHUB_CLIENT_ID:-${OAUTH_CLIENT_ID:-}}"
export GITHUB_CLIENT_SECRET="${GITHUB_CLIENT_SECRET:-${OAUTH_CLIENT_SECRET:-}}"
export JWT_SECRET="${JWT_SECRET:-${JWT_SECRET_KEY:-${SECRET_KEY:-}}}"
export SESSION_SECRET="${SESSION_SECRET:-${FLASK_SECRET_KEY:-${SECRET_KEY:-}}}"
export AUTHORIZED_GITHUB_ORGS="${AUTHORIZED_GITHUB_ORGS:-Fractal5-Solutions}"
export OAUTH_BASE_URL="${OAUTH_BASE_URL:-http://127.0.0.1:8080}"
export ASKPHI_WIDGET_URL="${ASKPHI_WIDGET_URL:-http://127.0.0.1:8081}"
export COOKIE_SECURE="${COOKIE_SECURE:-0}"
info "Applied local OAuth defaults for live ops"

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
                  "PORT=8081 python3 app.py" \
                  "8081"
fi

# ═══════════════════════════════════════════════════════════════════
# PHASE 3: COMMAND CENTER SERVICES
# ═══════════════════════════════════════════════════════════════════
section "PHASE 3: COMMAND CENTER SERVICES"

# Main Command Center
if [ -f "/workspaces/dominion-command-center/app/main.py" ]; then
    start_service "Dominion-Command-Center" \
                  "/workspaces/dominion-command-center/app/main.py" \
                  "cd /workspaces/dominion-command-center && python3 -m uvicorn app.main:app --host 0.0.0.0 --port 5000" \
                  "5000"
fi

# Billing Service
if [ -f "/workspaces/dominion-command-center/billing-service/app.py" ]; then
    start_service "Billing-Service" \
                  "/workspaces/dominion-command-center/billing-service/app.py" \
                  "PORT=5001 python3 app.py" \
                  "5001"
fi

# Dominion Command Core (preferred startup over demo app)
if [ -f "/workspaces/dominion-os-demo-build/command_core.py" ]; then
    start_service "Dominion-Command-Core" \
                  "/workspaces/dominion-os-demo-build/command_core.py" \
                  "cd /workspaces/dominion-os-demo-build && PORT=5002 python3 command_core.py" \
                  "5002"
fi

# Java Live Ops Site
if [ -f "/workspaces/dominion-os-demo-build/scripts/java_live_ops_site.sh" ]; then
    CURRENT_SERVICE_NAME="Dominion-Java-LiveOps-Site"
    CURRENT_SERVICE_LOG="$LOG_DIR/Java-LiveOps-Site.log"
    log "Starting Dominion-Java-LiveOps-Site..."
    if bash "/workspaces/dominion-os-demo-build/scripts/java_live_ops_site.sh" start; then
        [ -f "$LOG_DIR/Java-LiveOps-Site.pid" ] && TRACKED_PIDFILES+=("$LOG_DIR/Java-LiveOps-Site.pid")
        success "Dominion-Java-LiveOps-Site started successfully (Port: 8090)"
        CURRENT_SERVICE_NAME=""
    else
        record_failure "Dominion-Java-LiveOps-Site"
        warning "Dominion-Java-LiveOps-Site failed to start - check $LOG_DIR/Java-LiveOps-Site.log"
    fi
fi

# Sidecar Service
if [ -f "/workspaces/dominion-command-center/sidecar/app.py" ]; then
    start_service "Sidecar-Service" \
                  "/workspaces/dominion-command-center/sidecar/app.py" \
                  "python3 -m uvicorn app:app --host 0.0.0.0 --port 5003" \
                  "5003"
fi

# ChatGPT Gateway
if [ -f "/workspaces/dominion-command-center/chatgpt-gateway/main.py" ]; then
    if [ -f "/workspaces/dominion-command-center/ai_utils/guardrails.py" ]; then
        start_service "ChatGPT-Gateway" \
                      "/workspaces/dominion-command-center/chatgpt-gateway/main.py" \
                      "PORT=5004 python3 main.py" \
                      "5004"
    else
        warning "ChatGPT-Gateway dependency missing: /workspaces/dominion-command-center/ai_utils/guardrails.py"
    fi
fi

# ═══════════════════════════════════════════════════════════════════
# PHASE 4: LEGACY SYSTEMS
# ═══════════════════════════════════════════════════════════════════
section "PHASE 4: LEGACY SYSTEMS"

# Politics Local (Legacy)
if [ -f "/workspaces/dominion-os-1.0-politics.local-20260305/app.py" ]; then
    if ! start_service "Politics-Local-Legacy" \
                      "/workspaces/dominion-os-1.0-politics.local-20260305/app.py" \
                      "cd /workspaces/dominion-os-1.0-politics.local-20260305 && PORT=5005 python3 app.py" \
                      "5005"; then
        warning "Politics-Local-Legacy unavailable (legacy optional service)"
    fi
fi

# ═══════════════════════════════════════════════════════════════════
# PHASE 5: MONITORING & BACKGROUND SERVICES
# ═══════════════════════════════════════════════════════════════════
section "PHASE 5: MONITORING & BACKGROUND SERVICES"

# Start background monitoring
if [ -f "$SCRIPT_DIR/phi_background_completion_monitor.sh" ]; then
    log "Starting background completion monitor..."
    bash "$DETACHED_EXEC_SCRIPT" "$LOG_DIR/background_monitor.pid" "$LOG_DIR/background_monitor.log" "bash '$SCRIPT_DIR/phi_background_completion_monitor.sh'" >/dev/null
    TRACKED_PIDFILES+=("$LOG_DIR/background_monitor.pid")
    success "Background completion monitor started"
fi

# Start cost optimization (if not already running)
if [ -f "$SCRIPT_DIR/phi_cost_minimization_simple.sh" ]; then
    if ! pgrep -f "phi_cost_minimization" > /dev/null; then
        log "Starting cost minimization engine..."
        bash "$DETACHED_EXEC_SCRIPT" "$LOG_DIR/cost_minimization.pid" "$LOG_DIR/cost_minimization.log" "bash '$SCRIPT_DIR/phi_cost_minimization_simple.sh'" >/dev/null
        TRACKED_PIDFILES+=("$LOG_DIR/cost_minimization.pid")
        success "Cost minimization engine started"
    else
        success "Cost minimization engine already running"
    fi
fi

OPTIONAL_BG_ENABLE="${PHI_ENABLE_OPTIONAL_BACKGROUND:-0}"
OPTIONAL_BG_SERVICES="${PHI_OPTIONAL_BACKGROUND_SERVICES:-autonomous_overnight,channel_connect,google_workspace}"

if is_truthy "$OPTIONAL_BG_ENABLE"; then
    info "Optional background services enabled: $OPTIONAL_BG_SERVICES"

    if contains_csv_token "$OPTIONAL_BG_SERVICES" "autonomous_overnight"; then
        if [ -f "$SCRIPT_DIR/autonomous_overnight.sh" ]; then
            if gcloud_auth_available; then
                start_optional_background_service \
                    "Autonomous Overnight Executor" \
                    "bash '$SCRIPT_DIR/autonomous_overnight.sh'" \
                    "autonomous_overnight.sh" \
                    "$LOG_DIR/autonomous_overnight.pid" \
                    "$LOG_DIR/autonomous_overnight.log"
            else
                warning "Skipping Autonomous Overnight Executor: gcloud authentication unavailable"
            fi
        else
            warning "Optional service script missing: $SCRIPT_DIR/autonomous_overnight.sh"
        fi
    fi

    if contains_csv_token "$OPTIONAL_BG_SERVICES" "channel_connect"; then
        if [ -f "$SCRIPT_DIR/phi_channel_connect.sh" ]; then
            start_optional_background_service \
                "Channel Connect SaaS Service" \
                "bash '$SCRIPT_DIR/phi_channel_connect.sh' start" \
                "phi_channel_connect.sh" \
                "$LOG_DIR/channel_connect.pid" \
                "$LOG_DIR/channel_connect.log"
        else
            warning "Optional service script missing: $SCRIPT_DIR/phi_channel_connect.sh"
        fi
    fi

    if contains_csv_token "$OPTIONAL_BG_SERVICES" "google_workspace"; then
        if [ -f "$SCRIPT_DIR/phi_google_workspace.sh" ]; then
            start_optional_background_service \
                "Google Workspace Integration" \
                "bash '$SCRIPT_DIR/phi_google_workspace.sh' start" \
                "phi_google_workspace.sh" \
                "$LOG_DIR/google_workspace.pid" \
                "$LOG_DIR/google_workspace.log"
        else
            warning "Optional service script missing: $SCRIPT_DIR/phi_google_workspace.sh"
        fi
    fi
else
    info "Optional background services disabled (set PHI_ENABLE_OPTIONAL_BACKGROUND=1 to enable)"
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
for pidfile in "${TRACKED_PIDFILES[@]}"; do
    if [ -f "$pidfile" ]; then
        SERVICE_NAME=$(basename "$pidfile" .pid)
        PID=$(cat "$pidfile")
        if ps -p $PID > /dev/null 2>&1; then
            PORT=$(lsof -Pan -p "$PID" -i 2>/dev/null | awk '/LISTEN/ {print $9}' | cut -d: -f2 | head -1 || true)
            if [ -n "$PORT" ]; then
                echo -e "${GREEN}✓${NC} $SERVICE_NAME (PID: $PID) - Port: $PORT"
            else
                echo -e "${GREEN}✓${NC} $SERVICE_NAME (PID: $PID)"
            fi
            SERVICE_COUNT=$((SERVICE_COUNT + 1))
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

if [ ${#FAILED_SERVICES[@]} -gt 0 ]; then
    warning "Services requiring attention: ${FAILED_SERVICES[*]}"
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

STATUS_JSON="$SCRIPT_DIR/telemetry/system_status.json"
cat > "$STATUS_JSON" << EOF
{
  "timestamp": "$(date -u '+%Y-%m-%dT%H:%M:%SZ')",
  "startup_log": "$STARTUP_LOG",
  "active_services": $SERVICE_COUNT,
  "failed_services": [$(printf '"%s",' "${FAILED_SERVICES[@]}" | sed 's/,$//')],
  "generated_by": "phi_start_all_systems.sh"
}
EOF
info "Telemetry snapshot updated: $STATUS_JSON"
echo ""

if [ $SERVICE_COUNT -gt 0 ]; then
    echo -e "${CYAN}Service URLs:${NC}"
    [ -f "$LOG_DIR/PHI-OAuth-Server.pid" ] && echo "  • OAuth Server: http://localhost:8080"
    [ -f "$LOG_DIR/PHI-AskPHI-Widget.pid" ] && echo "  • AskPHI Widget: http://localhost:8081"
    [ -f "$LOG_DIR/Dominion-Command-Center.pid" ] && echo "  • Command Center: http://localhost:5000"
    [ -f "$LOG_DIR/Billing-Service.pid" ] && echo "  • Billing Service: http://localhost:5001"
    [ -f "$LOG_DIR/Dominion-Command-Core.pid" ] && echo "  • Dominion Command Core: http://localhost:5002"
    [ -f "$LOG_DIR/Java-LiveOps-Site.pid" ] && echo "  • Dominion Java Live Ops Site: http://localhost:8090"
    [ -f "$LOG_DIR/Sidecar-Service.pid" ] && echo "  • Sidecar: http://localhost:5003"
    [ -f "$LOG_DIR/ChatGPT-Gateway.pid" ] && echo "  • ChatGPT Gateway: http://localhost:5004"
    echo ""
fi

echo -e "${CYAN}Management Commands:${NC}"
echo "  • View logs: tail -f $LOG_DIR/<service>.log"
echo "  • Stop all: pkill -f 'command_core.py|python3 app.py|uvicorn app.main:app|python3 main.py|JavaLiveOpsSite'"
echo "  • Restart: /workspaces/dominion-command-center/scripts/live_ops_start.sh"
echo "  • Verify:  /workspaces/dominion-command-center/scripts/live_ops_verify.sh"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

success "PHI System Startup Complete!"
info "Command-center startup path is active"

log "═══════════════════════════════════════════════════════════════════"
log "Startup sequence completed successfully"
log "═══════════════════════════════════════════════════════════════════"
