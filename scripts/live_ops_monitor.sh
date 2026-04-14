#!/bin/bash
# PHI SOVEREIGN LIVE OPS MONITORING SYSTEM
# Continuous health monitoring and alerting for all services
# Generated: March 9, 2026

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_DIR="${SCRIPT_DIR}/telemetry"
HEALTH_LOG="$LOG_DIR/live_ops_health_$(date +%Y%m%d).log"
ALERT_LOG="$LOG_DIR/live_ops_alerts_$(date +%Y%m%d).log"
STATUS_FILE="$LOG_DIR/live_ops_status.json"
AUTOTUNE_ENV="$LOG_DIR/local_ops_profile.env"

if [ -f "$AUTOTUNE_ENV" ]; then
    # shellcheck disable=SC1090
    source "$AUTOTUNE_ENV"
fi

MAX_MEMORY_PERCENT="${PHI_MAX_MEMORY_PERCENT:-85}"
MAX_DISK_PERCENT="${PHI_MAX_DISK_PERCENT:-90}"

case "${PHI_AUTOTUNE_PROFILE:-balanced}" in
    ceiling|high) CPU_WARN_PERCENT=90 ;;
    balanced) CPU_WARN_PERCENT=85 ;;
    *) CPU_WARN_PERCENT=80 ;;
esac

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Service endpoints
SERVICES=(
    "oauth:8080"
    "widget:8081"
    "java_live_ops_site:8090"
    "command_center:5000"
    "billing:5001"
    "alt_demo:5002"
    "sidecar:5003"
    "chatgpt_gateway:5004"
)

OPTIONAL_BACKGROUND_SERVICES=(
    "phi_cost_minimization_simple"
    "autonomous_overnight"
)

# Create log directory
mkdir -p "$LOG_DIR"

log_info() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') [INFO] $1" >> "$HEALTH_LOG"
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_warn() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') [WARN] $1" >> "$HEALTH_LOG"
    echo "$(date '+%Y-%m-%d %H:%M:%S') [WARN] $1" >> "$ALERT_LOG"
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') [ERROR] $1" >> "$HEALTH_LOG"
    echo "$(date '+%Y-%m-%d %H:%M:%S') [ERROR] $1" >> "$ALERT_LOG"
    echo -e "${RED}[ERROR]${NC} $1"
}

log_success() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') [SUCCESS] $1" >> "$HEALTH_LOG"
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

float_gt() {
    awk -v left="$1" -v right="$2" 'BEGIN { exit !(left > right) }'
}

float_gte() {
    awk -v left="$1" -v right="$2" 'BEGIN { exit !(left >= right) }'
}

check_service_health() {
    local service=$1
    local port=$2
    local name=$3

    # Check if port is listening
    if lsof -i :$port | grep -q LISTEN; then
        local endpoints=("/health" "/healthz" "/-/healthy" "/api/health" "/")
        local endpoint
        for endpoint in "${endpoints[@]}"; do
            if curl -s -m 3 -o /dev/null "http://localhost:$port$endpoint"; then
                if [ "$endpoint" = "/" ]; then
                    log_success "$name ($port): REACHABLE"
                else
                    log_success "$name ($port): HEALTHY via $endpoint"
                fi
                return 0
            fi
        done

        log_warn "$name ($port): PORT OPEN but no health endpoint responded"
        return 1
    else
        log_error "$name ($port): PORT NOT LISTENING"
        return 2
    fi
}

is_optional_background_service() {
    local service=$1
    local optional
    for optional in "${OPTIONAL_BACKGROUND_SERVICES[@]}"; do
        if [ "$service" = "$optional" ]; then
            return 0
        fi
    done
    return 1
}

check_background_services() {
    local bg_services=("phi_background_completion_monitor" "phi_cost_minimization_simple" "autonomous_overnight")
    local total_bg=${#bg_services[@]}
    local healthy_bg=0

    for service in "${bg_services[@]}"; do
        local count
        count=$(pgrep -fc "$service" || true)

        if [ "$count" -gt 0 ]; then
            healthy_bg=$((healthy_bg + 1))
        elif is_optional_background_service "$service"; then
            healthy_bg=$((healthy_bg + 1))
        fi
    done

    # Return only the count, no logging here
    echo "$healthy_bg/$total_bg"
}

log_background_services() {
    local bg_services=("phi_background_completion_monitor" "phi_cost_minimization_simple" "autonomous_overnight")

    for service in "${bg_services[@]}"; do
        local count
        count=$(pgrep -fc "$service" || true)

        if [ "$count" -gt 0 ]; then
            log_success "Background service '$service': RUNNING ($count processes)"
        elif is_optional_background_service "$service"; then
            log_info "Background service '$service': OPTIONAL/IDLE"
        else
            log_error "Background service '$service': NOT RUNNING"
        fi
    done
}

check_system_resources() {
    # CPU usage
    local cpu_usage=$(top -bn1 | grep "Cpu(s)" | sed "s/.*, *\([0-9.]*\)%* id.*/\1/" | awk '{print 100 - $1}')
    local cpu_status="HEALTHY"
    if float_gt "$cpu_usage" "$CPU_WARN_PERCENT"; then
        cpu_status="HIGH"
    fi

    # Memory usage
    local mem_usage=$(free | grep Mem | awk '{printf "%.2f", $3/$2 * 100.0}')
    local mem_status="HEALTHY"
    if float_gt "$mem_usage" "$MAX_MEMORY_PERCENT"; then
        mem_status="HIGH"
    fi

    # Disk usage
    local disk_usage=$(df / | tail -1 | awk '{print $5}' | sed 's/%//')
    local disk_status="HEALTHY"
    if [ "$disk_usage" -gt "$MAX_DISK_PERCENT" ]; then
        disk_status="CRITICAL"
    elif [ "$disk_usage" -gt $((MAX_DISK_PERCENT - 10)) ]; then
        disk_status="HIGH"
    fi

    echo "{\"cpu\": {\"usage\": $cpu_usage, \"status\": \"$cpu_status\"}, \"memory\": {\"usage\": $mem_usage, \"status\": \"$mem_status\"}, \"disk\": {\"usage\": $disk_usage, \"status\": \"$disk_status\"}}"
}

log_system_resources() {
    # CPU usage
    local cpu_usage=$(top -bn1 | grep "Cpu(s)" | sed "s/.*, *\([0-9.]*\)%* id.*/\1/" | awk '{print 100 - $1}')
    local cpu_status="HEALTHY"
    if float_gt "$cpu_usage" "$CPU_WARN_PERCENT"; then
        cpu_status="HIGH"
        log_warn "CPU usage: ${cpu_usage}% (HIGH)"
    else
        log_info "CPU usage: ${cpu_usage}%"
    fi

    # Memory usage
    local mem_usage=$(free | grep Mem | awk '{printf "%.2f", $3/$2 * 100.0}')
    local mem_status="HEALTHY"
    if float_gt "$mem_usage" "$MAX_MEMORY_PERCENT"; then
        mem_status="HIGH"
        log_warn "Memory usage: ${mem_usage}% (HIGH)"
    else
        log_info "Memory usage: ${mem_usage}%"
    fi

    # Disk usage
    local disk_usage=$(df / | tail -1 | awk '{print $5}' | sed 's/%//')
    local disk_status="HEALTHY"
    if [ "$disk_usage" -gt "$MAX_DISK_PERCENT" ]; then
        disk_status="CRITICAL"
        log_error "Disk usage: ${disk_usage}% (CRITICAL)"
    elif [ "$disk_usage" -gt $((MAX_DISK_PERCENT - 10)) ]; then
        disk_status="HIGH"
        log_warn "Disk usage: ${disk_usage}% (HIGH)"
    else
        log_info "Disk usage: ${disk_usage}%"
    fi
}

generate_status_report() {
    local web_healthy=0
    local web_total=0
    local bg_status=$(check_background_services)
    local bg_healthy=$(echo $bg_status | cut -d'/' -f1)
    local bg_total=$(echo $bg_status | cut -d'/' -f2)
    local resources=$(check_system_resources)

    # Log background service status
    log_background_services

    # Log system resources
    log_system_resources

    # Check web services
    for service_info in "${SERVICES[@]}"; do
        IFS=':' read -r name port <<< "$service_info"
        web_total=$((web_total + 1))

        if check_service_health "$name" "$port" "$name"; then
            web_healthy=$((web_healthy + 1))
        fi
    done

    # Calculate live ops score (weighted average)
    local total_score=$(( (web_healthy * 100) + (bg_healthy * 100) ))
    local total_possible=$(( (web_total * 100) + (bg_total * 100) ))
    local live_ops_score=$(( total_score * 100 / total_possible ))

    # Generate JSON status
    cat > "$STATUS_FILE" << EOF
{
  "timestamp": "$(date -Iseconds)",
  "live_ops_score": "$(printf "%.2f" "$live_ops_score")",
  "services": {
    "web": {
      "healthy": $web_healthy,
      "total": $web_total,
      "status": "$([ $web_healthy -eq $web_total ] && echo "PERFECT" || echo "DEGRADED")"
    },
    "background": {
      "healthy": $bg_healthy,
      "total": $bg_total,
      "status": "$([ $bg_healthy -eq $bg_total ] && echo "PERFECT" || echo "DEGRADED")"
    }
  },
  "system_resources": $resources,
  "sovereign_mode": "MAXIMUM_ACTIVE",
  "authority_level": "13/13"
}
EOF

    log_info "Status report generated: $STATUS_FILE"
}

main() {
    echo "🔍 PHI SOVEREIGN LIVE OPS MONITORING SYSTEM"
    echo "=========================================="
    log_info "Starting live ops monitoring cycle"

    generate_status_report

    # Check overall health
    local live_ops_score=$(jq -r '.live_ops_score' "$STATUS_FILE" 2>/dev/null || echo "0")
    if float_gte "$live_ops_score" "95"; then
        log_success "LIVE OPS SCORE: ${live_ops_score} - PERFECT (95%+)"
    elif float_gte "$live_ops_score" "80"; then
        log_success "LIVE OPS SCORE: ${live_ops_score} - GOOD (80-94%)"
    else
        log_error "LIVE OPS SCORE: ${live_ops_score} - DEGRADED (<80%)"
    fi

    log_info "Live ops monitoring cycle completed"
}

# Run main function
main "$@"
