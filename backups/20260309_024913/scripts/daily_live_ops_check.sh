#!/bin/bash
# Daily automated live ops verification
# Runs scoring and sends alerts if score drops below threshold
# 
# Usage: ./daily_live_ops_check.sh [--threshold 85] [--email ops@example.com]
# Cron: 0 9 * * * /path/to/daily_live_ops_check.sh

set -e

# Configuration
THRESHOLD="${THRESHOLD:-85}"
ALERT_EMAIL="${ALERT_EMAIL:-ops@fractal5solutions.com}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
LOG_FILE="/var/log/phi-live-ops-daily.log"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_success() { echo -e "${GREEN}✅ $1${NC}"; }
print_error() { echo -e "${RED}❌ $1${NC}"; }
print_warning() { echo -e "${YELLOW}⚠️  $1${NC}"; }
print_info() { echo -e "${BLUE}ℹ️  $1${NC}"; }

# Header
echo "========================================="
echo "PHI + MCP Daily Live Ops Check"
echo "Time: $(date '+%Y-%m-%d %H:%M:%S')"
echo "Threshold: $THRESHOLD/100"
echo "========================================="
echo ""

# Run PHI scoring
print_info "Checking PHI systems..."
PHI_SCORE=0
if [ -f "$SCRIPT_DIR/phi_complete_status.sh" ]; then
    PHI_OUTPUT=$(bash "$SCRIPT_DIR/phi_complete_status.sh" 2>/dev/null || echo "Overall Score: 0/100")
    PHI_SCORE=$(echo "$PHI_OUTPUT" | grep -oP 'Overall Score:\s*\K\d+' | head -1 || echo "0")
    print_success "PHI Score: $PHI_SCORE/100"
else
    print_warning "PHI scoring script not found"
fi

# Run MCP scoring
print_info "Checking MCP services..."
MCP_SCORE=0
if [ -f "$SCRIPT_DIR/calculate_docker_live_ops_score.sh" ]; then
    MCP_OUTPUT=$(bash "$SCRIPT_DIR/calculate_docker_live_ops_score.sh" 2>/dev/null || echo "TOTAL SCORE: 0/100")
    MCP_SCORE=$(echo "$MCP_OUTPUT" | grep "TOTAL SCORE:" | awk '{print $3}' | cut -d'/' -f1 || echo "0")
    print_success "MCP Score: $MCP_SCORE/100"
else
    print_warning "MCP scoring script not found"
fi

# Calculate combined score
TOTAL_SCORE=$((PHI_SCORE + MCP_SCORE))
if [ "$TOTAL_SCORE" -gt 200 ]; then
    TOTAL_SCORE=200
fi

echo ""
echo "========================================="
echo "TOTAL SYSTEM SCORE: $TOTAL_SCORE/200"
echo "========================================="

# Determine status
if [ "$TOTAL_SCORE" -ge 180 ]; then
    print_success "Status: EXCELLENT - System operating at peak performance"
    STATUS="EXCELLENT"
elif [ "$TOTAL_SCORE" -ge 150 ]; then
    print_success "Status: GOOD - System operating normally"
    STATUS="GOOD"
elif [ "$TOTAL_SCORE" -ge 120 ]; then
    print_warning "Status: FAIR - Some issues detected"
    STATUS="FAIR"
else
    print_error "Status: POOR - Immediate attention required"
    STATUS="POOR"
fi

# Alert if below threshold (using MCP score for threshold check)
if [ "$MCP_SCORE" -lt "$THRESHOLD" ] || [ "$STATUS" = "POOR" ]; then
    print_error "ALERT: System score below threshold or in POOR state"
    
    # Try to send email alert (if mail command available)
    if command -v mail >/dev/null 2>&1; then
        {
            echo "PHI + MCP Live Ops Alert"
            echo "========================"
            echo ""
            echo "Time: $(date '+%Y-%m-%d %H:%M:%S')"
            echo "PHI Score: $PHI_SCORE/100"
            echo "MCP Score: $MCP_SCORE/100"
            echo "Total Score: $TOTAL_SCORE/200"
            echo "Status: $STATUS"
            echo ""
            echo "Threshold: $THRESHOLD/100"
            echo ""
            echo "Action Required: Check system status immediately"
            echo "Run: bash scripts/calculate_docker_live_ops_score.sh"
        } | mail -s "🚨 PHI Live Ops Alert - Score Below Threshold" "$ALERT_EMAIL"
        print_info "Alert email sent to $ALERT_EMAIL"
    else
        print_warning "Mail command not available - alert not sent"
    fi
fi

# Log result
LOG_ENTRY="$(date '+%Y-%m-%d %H:%M:%S') | PHI: $PHI_SCORE | MCP: $MCP_SCORE | Total: $TOTAL_SCORE | Status: $STATUS"
echo "$LOG_ENTRY" >> "$LOG_FILE" 2>/dev/null || print_warning "Could not write to log file: $LOG_FILE"

# Create telemetry data
TELEMETRY_DIR="$PROJECT_ROOT/telemetry"
if [ -d "$TELEMETRY_DIR" ]; then
    cat > "$TELEMETRY_DIR/daily_check_$(date '+%Y%m%d').json" << EOF
{
  "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "phi_score": $PHI_SCORE,
  "mcp_score": $MCP_SCORE,
  "total_score": $TOTAL_SCORE,
  "status": "$STATUS",
  "threshold": $THRESHOLD,
  "alert_triggered": $([ "$MCP_SCORE" -lt "$THRESHOLD" ] && echo "true" || echo "false")
}
EOF
    print_success "Telemetry saved to $TELEMETRY_DIR"
fi

echo ""
print_info "Daily check complete. Next check: $(date -d 'tomorrow 9:00' '+%Y-%m-%d 09:00:00' 2>/dev/null || date '+%Y-%m-%d 09:00:00')"
echo ""

# Exit with status code based on score
if [ "$TOTAL_SCORE" -ge 180 ]; then
    exit 0
elif [ "$TOTAL_SCORE" -ge 120 ]; then
    exit 1
else
    exit 2
fi
