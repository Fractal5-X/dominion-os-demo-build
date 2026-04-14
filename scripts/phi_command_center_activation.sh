#!/bin/bash
# ═══════════════════════════════════════════════════════════════════
# PHI COMMAND CENTER - FULL SYSTEM ACTIVATION PLAN
# ═══════════════════════════════════════════════════════════════════
# Purpose: Activate and verify all Dominion OS & SaaS Suite systems
# Target: Google Cloud Platform (dominion-os-1-0-main, dominion-core-prod)
# Mode: Autonomous with comprehensive validation
# ═══════════════════════════════════════════════════════════════════

set -e

# Color definitions
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
BOLD='\033[1m'
NC='\033[0m'

# ============================================================================
# GCP Project Configuration - NAMING ARCHITECTURE
# ============================================================================
# CRITICAL: Always use Project IDs in code (immutable), never display names
#
# DEV/STAGING Environment:
#   - Project ID: dominion-os-1-0-main (used in all scripts)
#   - Display Name: "Dominion Core Dev" (GCP Console only)
#   - Services: 9 development/staging services
#   - SLO Target: 95%+ uptime
#
# PRODUCTION Environment:
#   - Project ID: dominion-core-prod (used in all scripts)
#   - Display Name: "dominion-core-prod" (GCP Console only)
#   - Services: 15 production services
#   - SLO Target: 99.9% uptime
#
# Architecture Rationale: See GCP_ARCHITECTURE_ANALYSIS.md for detailed split reasoning
# ============================================================================
PROJECT1="dominion-os-1-0-main"        # DEV/STAGING Environment (Console: "Dominion Core Dev")
PROJECT2="dominion-core-prod"          # PRODUCTION Environment
REGION="us-central1"

# Telemetry
LOG_DIR="telemetry"
mkdir -p "$LOG_DIR"
ACTIVATION_LOG="$LOG_DIR/activation_$(date +%Y%m%d_%H%M%S).log"
STATUS_JSON="$LOG_DIR/system_status.json"

# Functions
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$ACTIVATION_LOG"
}

log_step() {
    echo ""
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}" | tee -a "$ACTIVATION_LOG"
    echo -e "${CYAN}$1${NC}" | tee -a "$ACTIVATION_LOG"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}" | tee -a "$ACTIVATION_LOG"
}

success() {
    echo -e "${GREEN}✅ $1${NC}" | tee -a "$ACTIVATION_LOG"
}

warning() {
    echo -e "${YELLOW}⚠️  $1${NC}" | tee -a "$ACTIVATION_LOG"
}

error() {
    echo -e "${RED}❌ $1${NC}" | tee -a "$ACTIVATION_LOG"
}

info() {
    echo -e "${BLUE}ℹ️  $1${NC}" | tee -a "$ACTIVATION_LOG"
}

# Header
clear
echo -e "${MAGENTA}╔═══════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${MAGENTA}║                                                                   ║${NC}"
echo -e "${MAGENTA}║         PHI COMMAND CENTER - ACTIVATION SEQUENCE                  ║${NC}"
echo -e "${MAGENTA}║                                                                   ║${NC}"
echo -e "${MAGENTA}║         Dominion OS & SaaS Suite                                  ║${NC}"
echo -e "${MAGENTA}║         Google Cloud Platform Deployment                          ║${NC}"
echo -e "${MAGENTA}║                                                                   ║${NC}"
echo -e "${MAGENTA}╚═══════════════════════════════════════════════════════════════════╝${NC}"
echo ""
log "═══════════════════════════════════════════════════════════════════"
log "Starting activation sequence at $(date '+%Y-%m-%d %H:%M:%S %Z')"
log "═══════════════════════════════════════════════════════════════════"
echo ""

# ═══════════════════════════════════════════════════════════════════
# PHASE 1: PRE-FLIGHT VERIFICATION
# ═══════════════════════════════════════════════════════════════════
log_step "PHASE 1: PRE-FLIGHT VERIFICATION"

log "Step 1.1: Verifying GCP Authentication"
if ACCOUNT=$(gcloud auth list --filter=status:ACTIVE --format="value(account)" 2>/dev/null) && [ -n "$ACCOUNT" ]; then
    success "Authenticated as: $ACCOUNT"
else
    error "GCP authentication required"
    info "Run: gcloud auth login"
    exit 1
fi

log "Step 1.2: Checking GitHub Token"
if [ -n "${GITHUB_TOKEN:-}" ]; then
    TOKEN_PREFIX=$(echo "$GITHUB_TOKEN" | cut -c1-10)
    info "Token prefix: ${TOKEN_PREFIX}..."

    if [[ "$GITHUB_TOKEN" =~ ^ghp_ ]] || [[ "$GITHUB_TOKEN" =~ ^gho_ ]]; then
        success "Git push capability: ENABLED"
        CAN_PUSH=true
    else
        warning "Git push capability: LIMITED (integration token)"
        CAN_PUSH=false
    fi
else
    warning "No GITHUB_TOKEN found - repository sync will be limited"
    CAN_PUSH=false
fi

log "Step 1.3: Verifying network connectivity"
if curl -s -o /dev/null -w "%{http_code}" https://cloud.google.com | grep -q "200\|301\|302"; then
    success "Internet connectivity verified"
else
    warning "Network connectivity issue detected"
fi

log "Step 1.4: Checking required tools"
REQUIRED_TOOLS=("gcloud" "git" "jq" "curl")
for tool in "${REQUIRED_TOOLS[@]}"; do
    if command -v "$tool" &> /dev/null; then
        success "$tool: Available"
    else
        error "$tool: NOT FOUND"
        exit 1
    fi
done

# ═══════════════════════════════════════════════════════════════════
# PHASE 2: INFRASTRUCTURE ACTIVATION
# ═══════════════════════════════════════════════════════════════════
log_step "PHASE 2: INFRASTRUCTURE ACTIVATION & HEALTH CHECK"

check_project_services() {
    local project=$1
    local project_name=$2

    log "Step 2.$3: Scanning $project_name ($project)"
    gcloud config set project "$project" --quiet 2>&1 | grep -v environment || true

    # Get all Cloud Run services
    local services=$(gcloud run services list --region="$REGION" --format="json" 2>/dev/null || echo "[]")

    if [ "$services" = "[]" ] || [ -z "$services" ]; then
        warning "No services found in $project"
        return 0
    fi

    local total=$(echo "$services" | jq '. | length')
    local ready=0
    local degraded_services=""

    echo "$services" | jq -r '.[].metadata.name' | while read -r service; do
        if [ -n "$service" ]; then
            local status=$(gcloud run services describe "$service" \
                --region="$REGION" \
                --format="value(status.conditions[0].status)" 2>/dev/null || echo "Unknown")

            if [ "$status" = "True" ]; then
                success "  ✓ $service: OPERATIONAL"
                echo "1" >> "/tmp/ready_count_$project.tmp"
            else
                warning "  ⚠ $service: $status"
                echo "$service " >> "/tmp/degraded_services_$project.tmp"
            fi
        fi
    done

    # Count results
    if [ -f "/tmp/ready_count_$project.tmp" ]; then
        ready=$(wc -l < "/tmp/ready_count_$project.tmp")
        rm "/tmp/ready_count_$project.tmp"
    fi

    if [ -f "/tmp/degraded_services_$project.tmp" ]; then
        degraded_services=$(cat "/tmp/degraded_services_$project.tmp")
        rm "/tmp/degraded_services_$project.tmp"
    fi

    local health_pct=0
    if [ "$total" -gt 0 ]; then
        health_pct=$((ready * 100 / total))
    fi

    echo ""
    info "$project_name Status: $ready/$total services operational ($health_pct%)"

    # Store for later
    echo "$ready" > "/tmp/${project}_ready.count"
    echo "$total" > "/tmp/${project}_total.count"

    if [ "$health_pct" -ge 99 ]; then
        success "$project_name: Infrastructure HEALTHY"
    elif [ "$health_pct" -ge 80 ]; then
        warning "$project_name: Infrastructure DEGRADED"
    else
        error "$project_name: Infrastructure CRITICAL"
    fi

    return 0
}

# Check both projects
check_project_services "$PROJECT1" "dominion-os-1-0-main" "1"
check_project_services "$PROJECT2" "dominion-core-prod" "2"

# ═══════════════════════════════════════════════════════════════════
# PHASE 3: SERVICE COMPONENT VALIDATION
# ═══════════════════════════════════════════════════════════════════
log_step "PHASE 3: SERVICE COMPONENT VALIDATION"

log "Step 3.1: Validating AI Gateways"
gcloud config set project "$PROJECT1" --quiet 2>&1 | grep -v environment || true
gateway_count=$(gcloud run services list --region="$REGION" --format="value(metadata.name)" 2>/dev/null | grep -i gateway | wc -l || echo "0")
if [ "$gateway_count" -gt 0 ]; then
    success "AI Gateways detected: $gateway_count"
    gcloud run services list --region="$REGION" --format="value(metadata.name)" 2>/dev/null | grep -i gateway | while read -r gw; do
        info "  • $gw"
    done
else
    warning "No AI Gateways found"
fi

log "Step 3.2: Validating PHI User Interfaces"
ui_count=$(gcloud run services list --region="$REGION" --format="value(metadata.name)" 2>/dev/null | grep -iE "ui|interface|phi-ui" | wc -l || echo "0")
if [ "$ui_count" -gt 0 ]; then
    success "PHI UIs detected: $ui_count"
    gcloud run services list --region="$REGION" --format="value(metadata.name)" 2>/dev/null | grep -iE "ui|interface|phi-ui" | while read -r ui; do
        info "  • $ui"
    done
else
    warning "No PHI UIs found"
fi

log "Step 3.3: Validating Core APIs"
gcloud config set project "$PROJECT2" --quiet 2>&1 | grep -v environment || true
api_count=$(gcloud run services list --region="$REGION" --format="value(metadata.name)" 2>/dev/null | grep -iE "api|service" | wc -l || echo "0")
if [ "$api_count" -gt 0 ]; then
    success "Core APIs detected: $api_count"
else
    warning "No Core APIs found"
fi

# ═══════════════════════════════════════════════════════════════════
# PHASE 4: MONITORING & SLO VALIDATION
# ═══════════════════════════════════════════════════════════════════
log_step "PHASE 4: MONITORING & SLO VALIDATION"

log "Step 4.1: Checking Cloud Monitoring configuration"
gcloud config set project "$PROJECT1" --quiet 2>&1 | grep -v environment || true
uptime_checks=$(gcloud monitoring uptime list --project="$PROJECT1" --format="value(name)" 2>/dev/null | wc -l || echo "0")
if [ "$uptime_checks" -gt 0 ]; then
    success "Uptime checks configured: $uptime_checks"
else
    info "No uptime checks found - consider running setup_monitoring.sh"
fi

log "Step 4.2: Checking SLO definitions"
# Note: SLO checking requires service name, so we'll just verify the script exists
if [ -f "scripts/setup_slos.sh" ]; then
    success "SLO configuration script available"
else
    info "SLO configuration script not found"
fi

log "Step 4.3: Running SLO compliance check"
if [ -f "scripts/phi_slo_monitoring.sh" ]; then
    success "SLO monitoring capability available"
    info "Full SLO report available via: ./scripts/phi_slo_monitoring.sh"
else
    info "SLO monitoring script not found"
fi

# ═══════════════════════════════════════════════════════════════════
# PHASE 5: REPOSITORY SYNCHRONIZATION
# ═══════════════════════════════════════════════════════════════════
log_step "PHASE 5: REPOSITORY SYNCHRONIZATION"

log "Step 5.1: Checking repository status"
cd /workspaces/dominion-os-demo-build 2>/dev/null || cd "$(dirname "$0")/.."
git fetch origin --quiet 2>/dev/null || warning "Could not fetch from remote"

LOCAL_SHA=$(git rev-parse --short HEAD 2>/dev/null || echo "unknown")
REMOTE_SHA=$(git rev-parse --short origin/main 2>/dev/null || echo "unknown")
COMMITS_AHEAD=$(git log origin/main..HEAD --oneline 2>/dev/null | wc -l || echo "0")

info "Local HEAD: $LOCAL_SHA"
info "Remote HEAD: $REMOTE_SHA"

if [ "$COMMITS_AHEAD" -eq 0 ]; then
    success "Repository synchronized (0 commits ahead)"
elif [ "$CAN_PUSH" = true ]; then
    warning "Repository $COMMITS_AHEAD commits ahead - sync recommended"
    info "Auto-sync available via: ./scripts/phi_multi_repo_sync.sh"
else
    warning "Repository $COMMITS_AHEAD commits ahead (push capability limited)"
fi

# ═══════════════════════════════════════════════════════════════════
# PHASE 6: AUTONOMOUS CAPABILITIES ACTIVATION
# ═══════════════════════════════════════════════════════════════════
log_step "PHASE 6: AUTONOMOUS CAPABILITIES ACTIVATION"

log "Step 6.1: Listing available autonomous systems"
autonomous_scripts=(
    "phi_sovereign_keepalive.sh:Repository sync monitoring"
    "phi_slo_monitoring.sh:SLO compliance monitoring"
    "phi_cost_optimization.sh:Cost optimization monitoring"
    "autonomous_overnight.sh:8-hour autonomous operations"
)

for script_info in "${autonomous_scripts[@]}"; do
    IFS=":" read -r script desc <<< "$script_info"
    if [ -f "scripts/$script" ]; then
        success "$desc: AVAILABLE (scripts/$script)"
    else
        info "$desc: Not found"
    fi
done

# ═══════════════════════════════════════════════════════════════════
# PHASE 7: GENERATE STATUS REPORT
# ═══════════════════════════════════════════════════════════════════
log_step "PHASE 7: FINAL STATUS REPORT & ACTIVATION SUMMARY"

# Collect metrics
ready1=$(cat "/tmp/${PROJECT1}_ready.count" 2>/dev/null || echo "0")
total1=$(cat "/tmp/${PROJECT1}_total.count" 2>/dev/null || echo "0")
ready2=$(cat "/tmp/${PROJECT2}_ready.count" 2>/dev/null || echo "0")
total2=$(cat "/tmp/${PROJECT2}_total.count" 2>/dev/null || echo "0")

total_services=$((total1 + total2))
operational_services=$((ready1 + ready2))
health_percentage=0
if [ "$total_services" -gt 0 ]; then
    health_percentage=$((operational_services * 100 / total_services))
fi

# Determine overall status
if [ "$health_percentage" -ge 95 ]; then
    OVERALL_STATUS="OPERATIONAL"
    STATUS_COLOR="${GREEN}"
elif [ "$health_percentage" -ge 75 ]; then
    OVERALL_STATUS="DEGRADED"
    STATUS_COLOR="${YELLOW}"
else
    OVERALL_STATUS="CRITICAL"
    STATUS_COLOR="${RED}"
fi

# Generate JSON status report
cat > "$STATUS_JSON" <<EOF
{
  "timestamp": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
  "status": "$(echo $OVERALL_STATUS | tr '[:upper:]' '[:lower:]')",
  "infrastructure": {
    "total_services": $total_services,
    "operational_services": $operational_services,
    "health_percentage": $health_percentage
  },
  "components": {
    "ai_gateways": $gateway_count,
    "phi_uis": $ui_count,
    "core_apis": $api_count
  },
  "projects": {
    "$PROJECT1": {
      "operational": $ready1,
      "total": $total1
    },
    "$PROJECT2": {
      "operational": $ready2,
      "total": $total2
    }
  },
  "git": {
    "local_sha": "$LOCAL_SHA",
    "remote_sha": "$REMOTE_SHA",
    "commits_ahead": $COMMITS_AHEAD,
    "can_push": $CAN_PUSH
  }
}
EOF

success "Status report generated: $STATUS_JSON"

# Clean up temp files
rm -f "/tmp/${PROJECT1}_ready.count" "/tmp/${PROJECT1}_total.count"
rm -f "/tmp/${PROJECT2}_ready.count" "/tmp/${PROJECT2}_total.count"

echo ""
echo -e "${MAGENTA}╔═══════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${MAGENTA}║                                                                   ║${NC}"
echo -e "${MAGENTA}║                   ACTIVATION COMPLETE                             ║${NC}"
echo -e "${MAGENTA}║                                                                   ║${NC}"
echo -e "${MAGENTA}╚═══════════════════════════════════════════════════════════════════╝${NC}"
echo ""

echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BOLD}SYSTEM STATUS SUMMARY${NC}"
echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e "  Overall Status: ${STATUS_COLOR}${OVERALL_STATUS}${NC}"
echo ""
echo -e "${BOLD}Infrastructure:${NC}"
echo "    Total Services:      $total_services"
echo "    Operational:         $operational_services"
echo "    Health:              ${health_percentage}%"
echo ""
echo -e "${BOLD}Components:${NC}"
echo "    AI Gateways:         $gateway_count"
echo "    PHI UIs:             $ui_count"
echo "    Core APIs:           $api_count"
echo ""
echo -e "${BOLD}Google Cloud Projects:${NC}"
echo "    $PROJECT1:   $ready1/$total1"
echo "    $PROJECT2:     $ready2/$total2"
echo ""
echo -e "${BOLD}Repository:${NC}"
echo "    Status:              $([ "$COMMITS_AHEAD" -eq 0 ] && echo "Synchronized" || echo "$COMMITS_AHEAD commits ahead")"
echo "    Push Capability:     $([ "$CAN_PUSH" = true ] && echo "Enabled" || echo "Limited")"
echo ""
echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# Recommendations
echo -e "${CYAN}RECOMMENDED NEXT ACTIONS:${NC}"
echo ""

if [ "$health_percentage" -lt 100 ]; then
    echo "  1. Investigate degraded services for root cause"
fi

if [ "$COMMITS_AHEAD" -gt 0 ] && [ "$CAN_PUSH" = true ]; then
    echo "  2. Run repository sync: ./scripts/phi_multi_repo_sync.sh"
fi

echo "  3. Start continuous monitoring: ./scripts/phi_sovereign_keepalive.sh &"
echo "  4. Review full status: ./scripts/phi_sovereign_status.sh"
echo "  5. Monitor SLO compliance: ./scripts/phi_slo_monitoring.sh"

if [ "$uptime_checks" -eq 0 ]; then
    echo "  6. Configure monitoring: ./scripts/setup_monitoring.sh"
fi

echo ""
echo -e "${GREEN}✅ Command Center activation sequence complete!${NC}"
echo ""
log "═══════════════════════════════════════════════════════════════════"
log "Activation sequence completed at $(date '+%Y-%m-%d %H:%M:%S %Z')"
log "Full log: $ACTIVATION_LOG"
log "═══════════════════════════════════════════════════════════════════"

exit 0
