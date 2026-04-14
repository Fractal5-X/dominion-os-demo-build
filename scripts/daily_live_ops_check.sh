#!/bin/bash
# Daily automated live ops verification
# Runs scoring and sends alerts if score drops below threshold
#
# Usage: ./daily_live_ops_check.sh [--threshold 85] [--email ops@example.com]
# Cron: 0 9 * * * /path/to/daily_live_ops_check.sh

set -euo pipefail

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

MCP_SCORE_APPLICABLE=true
TOTAL_POSSIBLE=200
ALERT_TRIGGERED=false

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
    MCP_OUTPUT=$(bash "$SCRIPT_DIR/calculate_docker_live_ops_score.sh" 2>/dev/null || echo "Score: 0")
    if echo "$MCP_OUTPUT" | grep -q "Score: N/A"; then
        MCP_SCORE_APPLICABLE=false
        TOTAL_POSSIBLE=100
        print_info "MCP Score: N/A (Docker checks informational only in this runtime)"
    else
        MCP_SCORE=$(echo "$MCP_OUTPUT" | grep -oP 'Final Score:\s*\K\d+' | head -1 || true)
        if [ -z "$MCP_SCORE" ]; then
            MCP_SCORE=$(echo "$MCP_OUTPUT" | grep -oP 'Score:\s*\K\d+' | head -1 || echo "0")
        fi
        print_success "MCP Score: $MCP_SCORE/100"
    fi
else
    print_warning "MCP scoring script not found"
fi

# Calculate combined score
TOTAL_SCORE=$((PHI_SCORE + MCP_SCORE))
if [ "$TOTAL_SCORE" -gt "$TOTAL_POSSIBLE" ]; then
    TOTAL_SCORE=$TOTAL_POSSIBLE
fi

echo ""
echo "========================================="
echo "TOTAL SYSTEM SCORE: $TOTAL_SCORE/$TOTAL_POSSIBLE"
echo "========================================="

# Determine status
if [ "$TOTAL_POSSIBLE" -eq 100 ]; then
    STATUS_SCORE=$TOTAL_SCORE
else
    STATUS_SCORE=$((TOTAL_SCORE * 100 / TOTAL_POSSIBLE))
fi

if [ "$STATUS_SCORE" -ge 90 ]; then
    print_success "Status: EXCELLENT - System operating at peak performance"
    STATUS="EXCELLENT"
elif [ "$STATUS_SCORE" -ge 75 ]; then
    print_success "Status: GOOD - System operating normally"
    STATUS="GOOD"
elif [ "$STATUS_SCORE" -ge 60 ]; then
    print_warning "Status: FAIR - Some issues detected"
    STATUS="FAIR"
else
    print_error "Status: POOR - Immediate attention required"
    STATUS="POOR"
fi

# Alert if below threshold (using MCP score for threshold check)
if { $MCP_SCORE_APPLICABLE && [ "$MCP_SCORE" -lt "$THRESHOLD" ]; } || [ "$STATUS" = "POOR" ]; then
    ALERT_TRIGGERED=true
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
            echo "Total Score: $TOTAL_SCORE/$TOTAL_POSSIBLE"
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
LOG_ENTRY="$(date '+%Y-%m-%d %H:%M:%S') | PHI: $PHI_SCORE | MCP: $([ "$MCP_SCORE_APPLICABLE" = true ] && echo "$MCP_SCORE" || echo "N/A") | Total: $TOTAL_SCORE/$TOTAL_POSSIBLE | Status: $STATUS"
echo "$LOG_ENTRY" >> "$LOG_FILE" 2>/dev/null || print_warning "Could not write to log file: $LOG_FILE"

# Create telemetry data
TELEMETRY_DIR="$PROJECT_ROOT/telemetry"
if [ -d "$TELEMETRY_DIR" ]; then
    cat > "$TELEMETRY_DIR/daily_check_$(date '+%Y%m%d').json" << EOF
{
  "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "phi_score": $PHI_SCORE,
  "mcp_score": $([ "$MCP_SCORE_APPLICABLE" = true ] && echo "$MCP_SCORE" || echo "null"),
  "mcp_score_applicable": $([ "$MCP_SCORE_APPLICABLE" = true ] && echo "true" || echo "false"),
  "total_score": $TOTAL_SCORE,
  "total_possible": $TOTAL_POSSIBLE,
  "status": "$STATUS",
  "threshold": $THRESHOLD,
  "alert_triggered": $ALERT_TRIGGERED
}
EOF
    print_success "Telemetry saved to $TELEMETRY_DIR"
fi

echo ""
print_info "Daily check complete. Next check: $(date -d 'tomorrow 9:00' '+%Y-%m-%d 09:00:00' 2>/dev/null || date '+%Y-%m-%d 09:00:00')"
echo ""

# Exit with status code based on score
if [ "$STATUS_SCORE" -ge 90 ]; then
    exit 0
elif [ "$STATUS_SCORE" -ge 60 ]; then
    exit 1
else
    exit 2
fi
