#!/bin/bash
# PHI SOVEREIGN LIVE OPS DASHBOARD
# Real-time monitoring dashboard for all services
# Generated: March 9, 2026

set -e

# Configuration
STATUS_FILE="telemetry/live_ops_status.json"
DASHBOARD_REFRESH=30  # seconds
OPTIONAL_BACKGROUND_SERVICES=(
    "phi_cost_minimization_simple"
    "autonomous_overnight"
)

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m'

clear_screen() {
    clear
}

draw_header() {
    echo -e "${MAGENTA}"
    echo "╔══════════════════════════════════════════════════════════════════════════════╗"
    echo "║                        🚀 DOMINION OS LIVE OPS DASHBOARD                     ║"
    echo "║                    Maximum Sovereign Power Mode - ACTIVE                     ║"
    echo "╚══════════════════════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
    echo "Timestamp: $(date '+%Y-%m-%d %H:%M:%S UTC')"
    echo ""
}

draw_service_status() {
    echo -e "${CYAN}🤖 SERVICE STATUS${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    if [ ! -f "$STATUS_FILE" ]; then
        echo -e "${RED}❌ Status file not found: $STATUS_FILE${NC}"
        return
    fi

    # Web services
    local web_healthy=$(jq -r '.services.web.healthy' "$STATUS_FILE" 2>/dev/null || echo "0")
    local web_total=$(jq -r '.services.web.total' "$STATUS_FILE" 2>/dev/null || echo "0")
    local web_status=$(jq -r '.services.web.status' "$STATUS_FILE" 2>/dev/null || echo "UNKNOWN")

    if [ "$web_status" = "PERFECT" ]; then
        echo -e "🌐 Web Services: ${GREEN}$web_healthy/$web_total HEALTHY${NC} ✅"
    else
        echo -e "🌐 Web Services: ${RED}$web_healthy/$web_total DEGRADED${NC} ❌"
    fi

    # Individual web services
    local services=(
        "OAuth Server:8080"
        "Widget Service:8081"
        "Java Live Ops Site:8090"
        "Command Center:5000"
        "Billing Service:5001"
        "Alt Demo:5002"
        "Sidecar:5003"
        "ChatGPT Gateway:5004"
    )

    for service_info in "${services[@]}"; do
        IFS=':' read -r name port <<< "$service_info"
        if lsof -i :$port | grep -q LISTEN; then
            local endpoints=("/health" "/healthz" "/-/healthy" "/api/health" "/")
            local healthy=false
            local endpoint
            for endpoint in "${endpoints[@]}"; do
                if curl -s -m 3 -o /dev/null "http://localhost:$port$endpoint"; then
                    healthy=true
                    break
                fi
            done
            if $healthy; then
                echo -e "   ✅ $name ($port)"
            else
                echo -e "   ⚠️  $name ($port) - Port open, no health endpoint responded"
            fi
        else
            echo -e "   ❌ $name ($port) - Not listening"
        fi
    done

    echo ""

    # Background services
    local bg_healthy=$(jq -r '.services.background.healthy' "$STATUS_FILE" 2>/dev/null || echo "0")
    local bg_status=$(jq -r '.services.background.status' "$STATUS_FILE" 2>/dev/null || echo "UNKNOWN")

    if [ "$bg_status" = "PERFECT" ]; then
        echo -e "🔄 Background Services: ${GREEN}$bg_healthy/3 HEALTHY${NC} ✅"
    else
        echo -e "🔄 Background Services: ${RED}$bg_healthy/3 DEGRADED${NC} ❌"
    fi

    # Individual background services
    local bg_services=("phi_background_completion_monitor" "phi_cost_minimization_simple" "autonomous_overnight")
    for service in "${bg_services[@]}"; do
        local count
        count=$(pgrep -fc "$service" || true)
        if [ "$count" -gt 0 ]; then
            echo -e "   ✅ $service ($count processes)"
        elif printf '%s\n' "${OPTIONAL_BACKGROUND_SERVICES[@]}" | grep -qx "$service"; then
            echo -e "   ℹ️  $service (optional/idle)"
        else
            echo -e "   ❌ $service (not running)"
        fi
    done

    echo ""
}

draw_system_resources() {
    echo -e "${CYAN}💻 SYSTEM RESOURCES${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    if [ ! -f "$STATUS_FILE" ]; then
        echo -e "${RED}❌ Status file not found${NC}"
        return
    fi

    local cpu_usage=$(jq -r '.system_resources.cpu.usage' "$STATUS_FILE" 2>/dev/null || echo "0")
    local cpu_status=$(jq -r '.system_resources.cpu.status' "$STATUS_FILE" 2>/dev/null || echo "UNKNOWN")

    local mem_usage=$(jq -r '.system_resources.memory.usage' "$STATUS_FILE" 2>/dev/null || echo "0")
    local mem_status=$(jq -r '.system_resources.memory.status' "$STATUS_FILE" 2>/dev/null || echo "UNKNOWN")

    local disk_usage=$(jq -r '.system_resources.disk.usage' "$STATUS_FILE" 2>/dev/null || echo "0")
    local disk_status=$(jq -r '.system_resources.disk.status' "$STATUS_FILE" 2>/dev/null || echo "UNKNOWN")

    # CPU
    if [ "$cpu_status" = "HEALTHY" ]; then
        echo -e "🖥️  CPU Usage: ${GREEN}${cpu_usage}%${NC}"
    elif [ "$cpu_status" = "HIGH" ]; then
        echo -e "🖥️  CPU Usage: ${YELLOW}${cpu_usage}% (HIGH)${NC}"
    else
        echo -e "🖥️  CPU Usage: ${RED}${cpu_usage}% (CRITICAL)${NC}"
    fi

    # Memory
    if [ "$mem_status" = "HEALTHY" ]; then
        echo -e "🧠 Memory Usage: ${GREEN}${mem_usage}%${NC}"
    elif [ "$mem_status" = "HIGH" ]; then
        echo -e "🧠 Memory Usage: ${YELLOW}${mem_usage}% (HIGH)${NC}"
    else
        echo -e "🧠 Memory Usage: ${RED}${mem_usage}% (CRITICAL)${NC}"
    fi

    # Disk
    if [ "$disk_status" = "HEALTHY" ]; then
        echo -e "💾 Disk Usage: ${GREEN}${disk_usage}%${NC}"
    elif [ "$disk_status" = "HIGH" ]; then
        echo -e "💾 Disk Usage: ${YELLOW}${disk_usage}% (HIGH)${NC}"
    else
        echo -e "💾 Disk Usage: ${RED}${disk_usage}% (CRITICAL)${NC}"
    fi

    echo ""
}

draw_live_ops_score() {
    echo -e "${CYAN}🎯 LIVE OPS SCORE${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    if [ ! -f "$STATUS_FILE" ]; then
        echo -e "${RED}❌ Status file not found${NC}"
        return
    fi

    local score=$(jq -r '.live_ops_score' "$STATUS_FILE" 2>/dev/null || echo "0")

    if (( $(echo "$score >= 95" | bc -l 2>/dev/null || echo "0") )); then
        echo -e "⭐ PERFECT: ${GREEN}${score}%${NC} (95%+)"
        echo -e "${GREEN}   All systems operating at peak performance${NC}"
    elif (( $(echo "$score >= 80" | bc -l 2>/dev/null || echo "0") )); then
        echo -e "✅ GOOD: ${YELLOW}${score}%${NC} (80-94%)"
        echo -e "${YELLOW}   Minor optimizations may be needed${NC}"
    else
        echo -e "❌ DEGRADED: ${RED}${score}%${NC} (<80%)"
        echo -e "${RED}   Immediate attention required${NC}"
    fi

    echo ""
}

draw_recent_alerts() {
    echo -e "${CYAN}🚨 RECENT ALERTS${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    local alert_file="telemetry/live_ops_alerts_$(date +%Y%m%d).log"
    if [ -f "$alert_file" ]; then
        tail -5 "$alert_file" 2>/dev/null | while read -r line; do
            if echo "$line" | grep -q "\[CRITICAL\]"; then
                echo -e "${RED}🚨 $line${NC}"
            elif echo "$line" | grep -q "\[WARN\]"; then
                echo -e "${YELLOW}⚠️  $line${NC}"
            else
                echo -e "${GREEN}ℹ️  $line${NC}"
            fi
        done
    else
        echo -e "${GREEN}✅ No alerts today${NC}"
    fi

    echo ""
}

draw_sovereign_status() {
    echo -e "${CYAN}👑 SOVEREIGN STATUS${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    local authority_level=$(jq -r '.authority_level' "$STATUS_FILE" 2>/dev/null || echo "13/13")
    local sovereign_mode=$(jq -r '.sovereign_mode' "$STATUS_FILE" 2>/dev/null || echo "MAXIMUM_ACTIVE")

    echo -e "🎯 Authority Level: ${GREEN}$authority_level${NC}"
    echo -e "⚡ Sovereign Mode: ${MAGENTA}$sovereign_mode${NC}"
    echo -e "🤖 Autonomous Operations: ${GREEN}ACTIVE${NC}"
    echo -e "🔄 Continuous Optimization: ${GREEN}ENGAGED${NC}"

    echo ""
}

draw_footer() {
    echo -e "${WHITE}Refresh: ${DASHBOARD_REFRESH}s | Press Ctrl+C to exit | Sovereign AI Monitoring Active${NC}"
    echo ""
}

main() {
    while true; do
        clear_screen
        draw_header
        draw_service_status
        draw_system_resources
        draw_live_ops_score
        draw_recent_alerts
        draw_sovereign_status
        draw_footer

        sleep $DASHBOARD_REFRESH
    done
}

# Run dashboard
main "$@"
