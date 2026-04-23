#!/bin/bash
#
# Dominion OS Auto-Startup Script for Linux/macOS
# Automatically starts all Dominion OS services on system boot
#
# Installation:
#   1. Copy to: /usr/local/bin/dominion-startup.sh
#   2. Make executable: chmod +x /usr/local/bin/dominion-startup.sh
#   3. Add to systemd: see dominion-startup.service
#
# Usage:
#   ./dominion-startup.sh        # Start all services
#   ./dominion-startup.sh status # Check status
#   ./dominion-startup.sh stop   # Stop all services
#

set -euo pipefail

# Configuration
WORKSPACE_DIR="/workspaces/dominion-os-demo-build"
COMMAND_CENTER_DIR="/workspaces/dominion-command-center"
LOG_DIR="${WORKSPACE_DIR}/logs"
TELEMETRY_DIR="${WORKSPACE_DIR}/scripts/telemetry"
TIMESTAMP=$(date -u +"%Y%m%dT%H%M%SZ")

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging
log_info() {
    echo -e "${GREEN}[$(date -u +"%Y-%m-%d %H:%M:%S UTC")]${NC} INFO: $1"
}

log_warn() {
    echo -e "${YELLOW}[$(date -u +"%Y-%m-%d %H:%M:%S UTC")]${NC} WARN: $1"
}

log_error() {
    echo -e "${RED}[$(date -u +"%Y-%m-%d %H:%M:%S UTC")]${NC} ERROR: $1"
}

log_status() {
    echo -e "${BLUE}[$(date -u +"%Y-%m-%d %H:%M:%S UTC")]${NC} STATUS: $1"
}

# Banner
show_banner() {
    cat << 'EOF'
╔═══════════════════════════════════════════════════════════════════════════╗
║                                                                           ║
║               🚀 DOMINION OS AUTO-STARTUP SYSTEM 🚀                       ║
║                                                                           ║
║                    INITIALIZING ALL SERVICES...                           ║
║                                                                           ║
╚═══════════════════════════════════════════════════════════════════════════╝
EOF
}

# Check if directories exist
check_directories() {
    log_info "Checking workspace directories..."

    if [ ! -d "$WORKSPACE_DIR" ]; then
        log_error "Demo build workspace not found: $WORKSPACE_DIR"
        return 1
    fi

    if [ ! -d "$COMMAND_CENTER_DIR" ]; then
        log_error "Command center workspace not found: $COMMAND_CENTER_DIR"
        return 1
    fi

    # Create log directory if it doesn't exist
    mkdir -p "$LOG_DIR"
    mkdir -p "$TELEMETRY_DIR"

    log_info "✅ All directories verified"
    return 0
}

# Start background monitors
start_monitors() {
    log_info "Starting background monitors..."

    cd "$WORKSPACE_DIR/scripts"

    # Start PHI Monitor Supervisor
    if ! pgrep -f "phi_monitor_supervisor.sh" > /dev/null; then
        log_info "Starting PHI Monitor Supervisor..."
        bash phi_monitor_supervisor.sh run >> "$LOG_DIR/phi_monitor_supervisor.log" 2>&1 &
        sleep 1
    else
        log_info "✅ PHI Monitor Supervisor already running"
    fi

    # Start Sovereign Monitor
    if ! pgrep -f "sovereign_monitor.sh" > /dev/null; then
        log_info "Starting Sovereign Monitor..."
        bash sovereign_monitor.sh run >> "$LOG_DIR/sovereign_monitor.log" 2>&1 &
        sleep 1
    else
        log_info "✅ Sovereign Monitor already running"
    fi

    # Start Intelligent Sync Daemon
    if ! pgrep -f "phi_intelligent_sync_daemon.sh" > /dev/null; then
        log_info "Starting Intelligent Sync Daemon..."
        bash phi_intelligent_sync_daemon.sh run >> "$LOG_DIR/phi_intelligent_sync_daemon.log" 2>&1 &
        sleep 1
    else
        log_info "✅ Intelligent Sync Daemon already running"
    fi

    log_info "✅ All monitors started"
}

# Start web services
start_services() {
    log_info "Starting web services..."

    cd "$WORKSPACE_DIR/scripts"

    # Use the existing start script
    if [ -f "phi_start_all_systems.sh" ]; then
        log_info "Using phi_start_all_systems.sh to start services..."
        bash phi_start_all_systems.sh >> "$LOG_DIR/services_startup_${TIMESTAMP}.log" 2>&1 &

        # Wait for services to initialize
        log_info "Waiting for services to initialize (30 seconds)..."
        sleep 30
    else
        log_error "Start script not found: phi_start_all_systems.sh"
        return 1
    fi

    log_info "✅ Web services started"
}

# Verify services are running
verify_services() {
    log_info "Verifying service health..."

    local all_healthy=true
    local services_count=0
    local healthy_count=0

    # Check web services (should have at least 8 running)
    services_count=$(pgrep -f 'python.*manage.py runserver\|uvicorn.*main:app' 2>/dev/null | wc -l)

    if [ "$services_count" -ge 8 ]; then
        log_info "✅ Web services: $services_count/9 running"
        healthy_count=$((healthy_count + 1))
    else
        log_warn "⚠️  Web services: Only $services_count running (expected 9)"
        all_healthy=false
    fi

    # Check monitors
    local monitors_count=0
    for monitor in phi_monitor_supervisor sovereign_monitor phi_intelligent_sync_daemon; do
        if pgrep -f "$monitor" > /dev/null; then
            monitors_count=$((monitors_count + 1))
        fi
    done

    if [ "$monitors_count" -ge 3 ]; then
        log_info "✅ Background monitors: $monitors_count/3 running"
        healthy_count=$((healthy_count + 1))
    else
        log_warn "⚠️  Background monitors: Only $monitors_count/3 running"
        all_healthy=false
    fi

    if [ "$healthy_count" -eq 2 ]; then
        log_info "✅ System health verification PASSED"
        return 0
    else
        log_warn "⚠️  System health verification PARTIAL (some services may still be starting)"
        return 1
    fi
}

# Update telemetry
update_telemetry() {
    log_info "Updating system telemetry..."

    cat > "$TELEMETRY_DIR/auto_startup_status.json" << EOF
{
  "auto_startup": true,
  "last_startup": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
  "status": "operational",
  "services_started": true,
  "monitors_started": true,
  "timestamp": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
}
EOF

    log_info "✅ Telemetry updated"
}

# Status command
show_status() {
    log_status "Dominion OS System Status"
    echo ""

    echo "=== WEB SERVICES ==="
    local services_count=$(pgrep -f 'python.*manage.py runserver\|uvicorn.*main:app' 2>/dev/null | wc -l)
    echo "Running: $services_count/9"
    pgrep -af 'python.*manage.py runserver\|uvicorn.*main:app' | head -10
    echo ""

    echo "=== BACKGROUND MONITORS ==="
    ps aux | grep -E "phi_monitor|sovereign|sync_daemon" | grep -v grep
    echo ""

    echo "=== AUTHORITY STATUS ==="
    if [ -f "$TELEMETRY_DIR/sovereign_status.json" ]; then
        cat "$TELEMETRY_DIR/sovereign_status.json" | grep -E "sovereignty_level|mode|status" || true
    fi
    echo ""
}

# Stop command
stop_services() {
    log_info "Stopping all Dominion OS services..."

    # Stop web services
    pkill -f 'python.*manage.py runserver' || true
    pkill -f 'uvicorn.*main:app' || true

    # Stop monitors
    pkill -f 'phi_monitor_supervisor.sh' || true
    pkill -f 'sovereign_monitor.sh' || true
    pkill -f 'phi_intelligent_sync_daemon.sh' || true

    log_info "✅ All services stopped"
}

# Main startup sequence
start_all() {
    show_banner

    log_info "Starting Dominion OS Auto-Startup Sequence..."
    log_info "Timestamp: $(date -u +"%Y-%m-%dT%H:%M:%SZ")"
    echo ""

    # Step 1: Check directories
    if ! check_directories; then
        log_error "Directory check failed"
        exit 1
    fi
    echo ""

    # Step 2: Start monitors
    start_monitors
    echo ""

    # Step 3: Start services
    start_services
    echo ""

    # Step 4: Verify health
    verify_services
    echo ""

    # Step 5: Update telemetry
    update_telemetry
    echo ""

    cat << 'EOF'
╔═══════════════════════════════════════════════════════════════════════════╗
║                                                                           ║
║                    ✅ DOMINION OS STARTUP COMPLETE ✅                     ║
║                                                                           ║
║                      ALL SYSTEMS OPERATIONAL                              ║
║                                                                           ║
╚═══════════════════════════════════════════════════════════════════════════╝
EOF

    log_info "Dominion OS is now ready for live operations"
    log_info "Command Center: http://localhost:5000"
    log_info "API Gateway: http://localhost:5002/api/v1"
    log_info "OAuth Server: http://localhost:5002/oauth"
    log_info "GCP Services: http://localhost:5002/gcp"
}

# Main command handler
case "${1:-start}" in
    start)
        start_all
        ;;
    stop)
        stop_services
        ;;
    restart)
        stop_services
        sleep 3
        start_all
        ;;
    status)
        show_status
        ;;
    *)
        echo "Usage: $0 {start|stop|restart|status}"
        exit 1
        ;;
esac
