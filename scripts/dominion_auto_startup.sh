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

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SYNC_ENV_FILE="${PHI_SYNC_ENV_FILE:-${SCRIPT_DIR}/live_ops_sync.env}"
if [ -f "${SYNC_ENV_FILE}" ]; then
    set -a
    # shellcheck disable=SC1090
    . "${SYNC_ENV_FILE}"
    set +a
fi

# Configuration
resolve_existing_dir() {
    local candidate=""
    for candidate in "$@"; do
        [ -n "${candidate}" ] || continue
        if [ -d "${candidate}" ]; then
            printf '%s\n' "${candidate}"
            return 0
        fi
    done
    return 1
}

WORKSPACE_DIR="$(
    resolve_existing_dir \
        "${DOMINION_WORKSPACE_DIR:-}" \
        "/mnt/d/workspaces/dominion-os-demo-build" \
        "/workspaces/dominion-os-demo-build" \
        "/mnt/c/workspaces/dominion-os-demo-build" \
    || echo "/workspaces/dominion-os-demo-build"
)"
COMMAND_CENTER_DIR="$(
    resolve_existing_dir \
        "${DOMINION_COMMAND_CENTER_DIR:-}" \
        "/mnt/d/workspaces/dominion-command-center" \
        "/workspaces/dominion-command-center" \
        "/mnt/c/workspaces/dominion-command-center" \
    || echo "/workspaces/dominion-command-center"
)"
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
    log_info "Workspace: $WORKSPACE_DIR"
    log_info "Command Center: $COMMAND_CENTER_DIR"
    return 0
}

run_docker_preflight() {
    local docker_repair_script="$WORKSPACE_DIR/scripts/docker_repair_optimal.sh"
    local docker_log="$LOG_DIR/docker_repair_${TIMESTAMP}.log"
    local rc=0

    if [ "${PHI_DOCKER_REPAIR_ON_START:-1}" != "1" ]; then
        log_info "Docker pre-flight disabled (PHI_DOCKER_REPAIR_ON_START=${PHI_DOCKER_REPAIR_ON_START})"
        return 0
    fi

    if ! command -v docker >/dev/null 2>&1; then
        log_warn "Docker CLI not found; skipping pre-flight"
        return 0
    fi

    if [ ! -x "$docker_repair_script" ]; then
        log_warn "Docker repair script not found: $docker_repair_script"
        return 0
    fi

    log_info "Running Docker pre-flight repair..."
    set +e
    bash "$docker_repair_script" >> "$docker_log" 2>&1
    rc=$?
    set -e

    if [ "$rc" -eq 0 ]; then
        log_info "✅ Docker pre-flight repair completed"
        return 0
    fi

    if [ "$rc" -eq 2 ]; then
        log_warn "Docker pre-flight partial (runtime capability limits); continuing startup"
    elif [ "$rc" -eq 3 ]; then
        log_warn "Docker pre-flight partial (container canary network/auth blocked); continuing startup"
    else
        log_warn "Docker pre-flight failed (exit $rc); continuing startup"
    fi
    return 0
}

# Start background monitors
start_monitors() {
    log_info "Starting background monitors..."

    cd "$WORKSPACE_DIR/scripts"

    local sync_interval="${PHI_INTELLIGENT_SYNC_INTERVAL:-120}"
    local gcs_enabled="${PHI_SYNC_GCS_ENABLED:-1}"
    local gcs_min_interval="${PHI_SYNC_GCS_MIN_INTERVAL_SECONDS:-300}"
    local local_mirror_enabled="${PHI_SYNC_LOCAL_MIRROR_ENABLED:-1}"
    local local_mirror_path="${PHI_SYNC_LOCAL_MIRROR_PATH:-/mnt/d/workspaces/dominion-os-demo-build-live}"
    local ecosystem_apply_enabled="${PHI_ECOSYSTEM_APPLY_SAFE_ENABLED:-1}"
    local ecosystem_apply_every="${PHI_ECOSYSTEM_APPLY_SAFE_EVERY_CYCLES:-12}"
    local local_machine_profile="${PHI_LOCAL_MACHINE_PROFILE:-AT2_LIVE_OPS}"
    local local_perf_mode="${PHI_LOCAL_MACHINE_PERF_MODE:-MAX_PERFORMANCE}"
    local local_cost_mode="${PHI_LOCAL_MACHINE_COST_MODE:-LOWEST_COST}"

    export PHI_LOCAL_MACHINE_PROFILE="$local_machine_profile"
    export PHI_LOCAL_MACHINE_PERF_MODE="$local_perf_mode"
    export PHI_LOCAL_MACHINE_COST_MODE="$local_cost_mode"

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
        PHI_INTELLIGENT_SYNC_INTERVAL="$sync_interval" \
        PHI_SYNC_GCS_ENABLED="$gcs_enabled" \
        PHI_SYNC_GCS_MIN_INTERVAL_SECONDS="$gcs_min_interval" \
        PHI_SYNC_LOCAL_MIRROR_ENABLED="$local_mirror_enabled" \
        PHI_SYNC_LOCAL_MIRROR_PATH="$local_mirror_path" \
        bash phi_intelligent_sync_daemon.sh run >> "$LOG_DIR/phi_intelligent_sync_daemon.log" 2>&1 &
        sleep 1
    else
        log_info "✅ Intelligent Sync Daemon already running"
    fi

    # Start Ecosystem Optimizer Daemon
    if ! pgrep -f "ecosystem_optimizer_daemon.sh" > /dev/null; then
        log_info "Starting Ecosystem Optimizer Daemon..."
        PHI_ECOSYSTEM_APPLY_SAFE_ENABLED="$ecosystem_apply_enabled" \
        PHI_ECOSYSTEM_APPLY_SAFE_EVERY_CYCLES="$ecosystem_apply_every" \
        bash ecosystem_optimizer_daemon.sh run >> "$LOG_DIR/ecosystem_optimizer_daemon.log" 2>&1 &
        sleep 1
    else
        log_info "✅ Ecosystem Optimizer Daemon already running"
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
    for monitor in phi_monitor_supervisor sovereign_monitor phi_intelligent_sync_daemon ecosystem_optimizer_daemon; do
        if pgrep -f "$monitor" > /dev/null; then
            monitors_count=$((monitors_count + 1))
        fi
    done

    if [ "$monitors_count" -ge 4 ]; then
        log_info "✅ Background monitors: $monitors_count/4 running"
        healthy_count=$((healthy_count + 1))
    else
        log_warn "⚠️  Background monitors: Only $monitors_count/4 running"
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
    ps aux | grep -E "phi_monitor|sovereign|sync_daemon|ecosystem_optimizer" | grep -v grep
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
    pkill -f 'ecosystem_optimizer_daemon.sh' || true

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

    # Step 1.5: Docker pre-flight
    run_docker_preflight
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
