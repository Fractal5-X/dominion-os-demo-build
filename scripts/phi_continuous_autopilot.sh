#!/usr/bin/env bash
#
# PHI Continuous Autopilot - Maximum Sovereign Power
#
# Launches autopilot in continuous autonomous operation mode at 14/14 authority
# with comprehensive safeguards, monitoring, and recovery mechanisms.
#
# Usage:
#   bash phi_continuous_autopilot.sh [mode] [runs]
#
# Modes:
#   standard    - Balanced continuous operation (default)
#   intensive   - High-intensity maximum throughput
#   marathon    - Near-infinite operation (999999 runs)
#
# Examples:
#   bash phi_continuous_autopilot.sh standard 100
#   bash phi_continuous_autopilot.sh intensive 1000
#   bash phi_continuous_autopilot.sh marathon
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE_DIR="$(dirname "$SCRIPT_DIR")"
TELEMETRY_DIR="$SCRIPT_DIR/telemetry"
LOGS_DIR="$SCRIPT_DIR/logs"
FLIGHT_LOG_DIR="$WORKSPACE_DIR/dist/command_core"

# Ensure directories exist
mkdir -p "$TELEMETRY_DIR" "$LOGS_DIR" "$FLIGHT_LOG_DIR"

# Configuration
MODE="${1:-standard}"
RUNS="${2:-}"
LOG_FILE="$LOGS_DIR/phi_continuous_autopilot.log"
PID_FILE="$TELEMETRY_DIR/continuous_autopilot.pid"

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

log() {
    echo -e "${CYAN}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $*" | tee -a "$LOG_FILE"
}

log_error() {
    echo -e "${RED}[$(date +'%Y-%m-%d %H:%M:%S')] ERROR:${NC} $*" | tee -a "$LOG_FILE" >&2
}

log_success() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] SUCCESS:${NC} $*" | tee -a "$LOG_FILE"
}

log_warning() {
    echo -e "${YELLOW}[$(date +'%Y-%m-%d %H:%M:%S')] WARNING:${NC} $*" | tee -a "$LOG_FILE"
}

# Banner
echo ""
echo "╔═══════════════════════════════════════════════════════════════════════════╗"
echo "║                                                                           ║"
echo "║        🚀 PHI CONTINUOUS AUTOPILOT - 14/14 SOVEREIGN POWER 🚀            ║"
echo "║                                                                           ║"
echo "║                   NHITL AUTONOMOUS OPERATION MODE                         ║"
echo "║                                                                           ║"
echo "╚═══════════════════════════════════════════════════════════════════════════╝"
echo ""

# Pre-flight checks
log "Starting pre-flight checks..."

# Check 1: Verify authority level
if [ -f "$TELEMETRY_DIR/sovereign_status.json" ]; then
    AUTHORITY=$(jq -r '.sovereignty_level' "$TELEMETRY_DIR/sovereign_status.json" 2>/dev/null || echo "unknown")
    if [ "$AUTHORITY" != "14/14" ]; then
        log_error "Authority level is $AUTHORITY, expected 14/14"
        exit 1
    fi
    log_success "Authority verified: 14/14 UNIVERSAL_DOMINION"
else
    log_error "Sovereign status file not found"
    exit 1
fi

# Check 2: Verify services
SERVICE_COUNT=$(bash "$SCRIPT_DIR/phi_status.sh" 2>&1 | grep -oP 'Total Active Services: \K\d+' || echo "0")
if [ "$SERVICE_COUNT" -lt 11 ]; then
    log_error "Only $SERVICE_COUNT services active, minimum 11 required"
    exit 1
fi
log_success "Services verified: $SERVICE_COUNT/13 operational"

# Check 3: Verify git status
cd "$WORKSPACE_DIR"
if [ -n "$(git status --porcelain 2>/dev/null)" ]; then
    log_warning "Working tree has uncommitted changes"
    git status --short
fi

# Check 4: Verify upstream
UPSTREAM=$(git rev-parse --abbrev-ref --symbolic-full-name @{u} 2>/dev/null || echo "none")
if [ "$UPSTREAM" = "none" ]; then
    log_error "No upstream configured for current branch"
    exit 1
fi
log_success "Git upstream verified: $UPSTREAM"

# Check 5: Verify resources
AVAILABLE_MEM_GB=$(free -g | awk '/^Mem:/ {print $7}')
if [ "$AVAILABLE_MEM_GB" -lt 15 ]; then
    log_warning "Low memory: ${AVAILABLE_MEM_GB}GB available (recommended: >15GB)"
fi

AVAILABLE_DISK_GB=$(df -BG / | awk 'NR==2 {print $4}' | sed 's/G//')
if [ "$AVAILABLE_DISK_GB" -lt 20 ]; then
    log_warning "Low disk space: ${AVAILABLE_DISK_GB}GB available (recommended: >20GB)"
fi

log_success "Resources verified: ${AVAILABLE_MEM_GB}GB RAM, ${AVAILABLE_DISK_GB}GB disk"

# Check 6: Verify Python and demo_build module
if ! command -v python &> /dev/null; then
    log_error "Python not found"
    exit 1
fi

cd "$WORKSPACE_DIR"
if ! python -c "import demo_build" 2>/dev/null; then
    log_error "demo_build module not available"
    exit 1
fi
log_success "Python environment verified"

# Check 7: Verify monitors running
MONITOR_COUNT=$(ps aux | grep -E "phi_monitor_supervisor|sovereign_monitor|intelligent_sync_daemon" | grep -v grep | wc -l)
if [ "$MONITOR_COUNT" -lt 2 ]; then
    log_warning "Only $MONITOR_COUNT background monitors running (expected 3)"
fi
log_success "Background monitors verified: $MONITOR_COUNT active"

echo ""
log "✅ All pre-flight checks passed"
echo ""

# Configure autopilot parameters based on mode
case "$MODE" in
    standard)
        SCALE="large"
        DURATION=180
        RUNS="${RUNS:-100}"
        INTERVAL_MS=1000
        log "Mode: STANDARD CONTINUOUS - Balanced operation"
        log "  Expected: ~144 ops/tick, 50-60% CPU, safe for extended operation"
        ;;
    intensive)
        SCALE="large"
        DURATION=180
        RUNS="${RUNS:-1000}"
        INTERVAL_MS=500
        log "Mode: INTENSIVE CONTINUOUS - High throughput"
        log "  Expected: ~144 ops/tick, 70-80% CPU, requires monitoring"
        ;;
    marathon)
        SCALE="large"
        DURATION=180
        RUNS="${RUNS:-999999}"
        INTERVAL_MS=1000
        log "Mode: MARATHON CONTINUOUS - Near-infinite operation"
        log "  Expected: ~144 ops/tick, runs until stopped, full autonomous"
        ;;
    *)
        log_error "Unknown mode: $MODE (use: standard, intensive, or marathon)"
        exit 1
        ;;
esac

echo ""
log "Configuration:"
log "  Scale:        $SCALE"
log "  Duration:     $DURATION ticks"
log "  Runs:         $RUNS"
log "  Interval:     ${INTERVAL_MS}ms"
log "  Authority:    14/14 UNIVERSAL_DOMINION"
log "  Mode:         NHITL_AUTOPILOT"
echo ""

# Confirm execution
read -p "Proceed with continuous autopilot execution? (yes/no): " CONFIRM
if [ "$CONFIRM" != "yes" ]; then
    log "Execution cancelled by user"
    exit 0
fi

echo ""
log "🚀 Launching continuous autopilot..."
echo ""

# Record start time
START_TIME=$(date +%s)
START_TIME_ISO=$(date -Iseconds)

# Create execution metadata
cat > "$TELEMETRY_DIR/continuous_autopilot_metadata.json" <<EOF
{
  "start_time": "$START_TIME_ISO",
  "mode": "$MODE",
  "scale": "$SCALE",
  "duration": $DURATION,
  "runs": $RUNS,
  "interval_ms": $INTERVAL_MS,
  "authority": "14/14",
  "execution_mode": "NHITL_AUTOPILOT",
  "status": "running"
}
EOF

# Execute autopilot
cd "$WORKSPACE_DIR"

# Use autopilot_guard if available
GUARD_SCRIPT="$WORKSPACE_DIR/tools/autopilot_guard.sh"
if [ -f "$GUARD_SCRIPT" ]; then
    log "Running autopilot guard preflight..."
    if bash "$GUARD_SCRIPT" preflight; then
        log_success "Autopilot guard preflight passed"
    else
        log_error "Autopilot guard preflight failed"
        exit 1
    fi
fi

# Launch autopilot (will run in foreground)
log "Executing: python demo_build.py autopilot --scale $SCALE --duration $DURATION --runs $RUNS --interval-ms $INTERVAL_MS"
echo ""

# Store PID
echo $$ > "$PID_FILE"

# Execute
python demo_build.py autopilot \
    --scale "$SCALE" \
    --duration "$DURATION" \
    --runs "$RUNS" \
    --interval-ms "$INTERVAL_MS" \
    2>&1 | tee -a "$LOG_FILE"

AUTOPILOT_EXIT_CODE=$?

# Record end time
END_TIME=$(date +%s)
END_TIME_ISO=$(date -Iseconds)
ELAPSED=$((END_TIME - START_TIME))
ELAPSED_HOURS=$((ELAPSED / 3600))
ELAPSED_MINS=$(((ELAPSED % 3600) / 60))
ELAPSED_SECS=$((ELAPSED % 60))

echo ""
log "Continuous autopilot execution completed"
log "Exit code: $AUTOPILOT_EXIT_CODE"
log "Elapsed time: ${ELAPSED_HOURS}h ${ELAPSED_MINS}m ${ELAPSED_SECS}s"
echo ""

# Update metadata
jq --arg end_time "$END_TIME_ISO" \
   --arg elapsed "${ELAPSED}" \
   --arg exit_code "$AUTOPILOT_EXIT_CODE" \
   --arg status "completed" \
   '.end_time = $end_time | .elapsed_seconds = ($elapsed | tonumber) | .exit_code = ($exit_code | tonumber) | .status = $status' \
   "$TELEMETRY_DIR/continuous_autopilot_metadata.json" > "$TELEMETRY_DIR/continuous_autopilot_metadata.json.tmp"
mv "$TELEMETRY_DIR/continuous_autopilot_metadata.json.tmp" "$TELEMETRY_DIR/continuous_autopilot_metadata.json"

# Post-execution validation
echo ""
log "Running post-execution validation..."

# Check authority
AUTHORITY_POST=$(jq -r '.sovereignty_level' "$TELEMETRY_DIR/sovereign_status.json" 2>/dev/null || echo "unknown")
if [ "$AUTHORITY_POST" != "14/14" ]; then
    log_error "Authority changed to $AUTHORITY_POST (expected 14/14)"
else
    log_success "Authority maintained: 14/14"
fi

# Check services
SERVICE_COUNT_POST=$(bash "$SCRIPT_DIR/phi_status.sh" 2>&1 | grep -oP 'Total Active Services: \K\d+' || echo "0")
if [ "$SERVICE_COUNT_POST" -lt 11 ]; then
    log_warning "Only $SERVICE_COUNT_POST services active after execution"
else
    log_success "Services healthy: $SERVICE_COUNT_POST/13 operational"
fi

# Check flight logs
FLIGHT_COUNT=$(ls -1 "$FLIGHT_LOG_DIR"/flight_*.json 2>/dev/null | wc -l)
log "Flight logs generated: $FLIGHT_COUNT"

# Check git status
if [ -n "$(git status --porcelain 2>/dev/null)" ]; then
    log_warning "Working tree has uncommitted changes after execution"
fi

# Run autopilot guard push-or-abort if available
if [ -f "$GUARD_SCRIPT" ]; then
    log "Running autopilot guard push-or-abort..."
    if bash "$GUARD_SCRIPT" push-or-abort; then
        log_success "Autopilot guard push-or-abort completed"
    else
        log_warning "Autopilot guard push-or-abort reported issues"
    fi
fi

# Clean up PID file
rm -f "$PID_FILE"

echo ""
echo "╔═══════════════════════════════════════════════════════════════════════════╗"
echo "║                                                                           ║"
echo "║          ✅ CONTINUOUS AUTOPILOT EXECUTION COMPLETE ✅                    ║"
echo "║                                                                           ║"
echo "║            Authority: $AUTHORITY_POST • Services: $SERVICE_COUNT_POST/13 • Elapsed: ${ELAPSED_HOURS}h ${ELAPSED_MINS}m        ║"
echo "║                                                                           ║"
echo "╚═══════════════════════════════════════════════════════════════════════════╝"
echo ""

log "Execution log: $LOG_FILE"
log "Flight logs: $FLIGHT_LOG_DIR/flight_*.json"
log "Metadata: $TELEMETRY_DIR/continuous_autopilot_metadata.json"
echo ""

exit $AUTOPILOT_EXIT_CODE
