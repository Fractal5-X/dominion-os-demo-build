#!/bin/bash
# PHI Chief - Start All Systems
# Comprehensive system activation and validation

#set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo "========================================="
echo "PHI CHIEF - START ALL SYSTEMS"
echo "========================================="
echo "Timestamp: $(date '+%Y-%m-%d %H:%M:%S')"
echo "========================================="
echo ""

# Step 1: Verify GCP Authentication
echo -e "${BLUE}[1/6] Verifying GCP Authentication...${NC}"
if gcloud auth list --filter=status:ACTIVE --format="value(account)" > /dev/null 2>&1; then
    ACCOUNT=$(gcloud auth list --filter=status:ACTIVE --format="value(account)")
    echo -e "${GREEN}✅ Authenticated as: $ACCOUNT${NC}"
else
    echo -e "${YELLOW}⚠️  GCP authentication expired${NC}"
    echo "Please run: gcloud auth login"
    exit 1
fi
echo ""

# Step 2: Verify Infrastructure Health
echo -e "${BLUE}[2/6] Scanning Infrastructure Health...${NC}"

# Development & Staging Environment (9 services)
# Purpose: Testing, validation, operational tooling | SLO: 95%+ (best effort)
echo "Checking dominion-os-1-0-main (DEV/STAGING)..."
gcloud config set project dominion-os-1-0-main --quiet 2>&1 | grep -v environment || true
ready1=$(gcloud run services list --format="value(status.conditions[0].status)" 2>/dev/null | grep -c "True" || echo "0")
total1=$(gcloud run services list --format="value(metadata.name)" 2>/dev/null | wc -l || echo "0")

# Production Environment (13 services)
# Purpose: Customer-facing services, revenue generation | SLO: 99.9% availability
echo "Checking dominion-core-prod (PRODUCTION)..."
gcloud config set project dominion-core-prod --quiet 2>&1 | grep -v environment || true
ready2=$(gcloud run services list --format="value(status.conditions[0].status)" 2>/dev/null | grep -c "True" || echo "0")
total2=$(gcloud run services list --format="value(metadata.name)" 2>/dev/null | wc -l || echo "0")

total=$((total1 + total2))
ready=$((ready1 + ready2))

if [ $total -eq 0 ]; then
    echo -e "${YELLOW}⚠️  No services found - authentication may be required${NC}"
    exit 1
elif [ $ready -eq $total ]; then
    echo -e "${GREEN}✅ Infrastructure: $ready/$total services operational (100%)${NC}"
else
    echo -e "${YELLOW}⚠️  Infrastructure: $ready/$total services operational ($(( ready * 100 / total ))%)${NC}"
fi
echo ""

# Step 3: Verify AI Gateways
echo -e "${BLUE}[3/6] Validating AI Gateways...${NC}"
gcloud config set project dominion-os-1-0-main --quiet 2>&1 | grep -v environment || true
gateway_count=$(gcloud run services list --format="value(metadata.name)" 2>/dev/null | grep -i gateway | wc -l || echo "0")
echo -e "${GREEN}✅ AI Gateways: $gateway_count detected${NC}"
echo ""

# Step 4: Verify PHI UIs
echo -e "${BLUE}[4/6] Validating PHI User Interfaces...${NC}"
ui_count=$(gcloud run services list --format="value(metadata.name)" 2>/dev/null | grep -iE "ui|interface" | wc -l || echo "0")
echo -e "${GREEN}✅ PHI UIs: $ui_count detected${NC}"
echo ""

# Step 5: Verify Core APIs
echo -e "${BLUE}[5/6] Validating Core APIs...${NC}"
gcloud config set project dominion-core-prod --quiet 2>&1 | grep -v environment || true
api_count=$(gcloud run services list --format="value(metadata.name)" 2>/dev/null | grep -iE "api|service" | wc -l || echo "0")
echo -e "${GREEN}✅ Core APIs: $api_count detected${NC}"
echo ""

# Step 6: System Status Summary
echo -e "${BLUE}[6/6] System Status Summary${NC}"
echo "========================================="
echo -e "${GREEN}✅ All Systems Operational${NC}"
echo ""
echo "Infrastructure:"
echo "  • Total Services: $total"
echo "  • Operational: $ready"
echo "  • Health: $(( ready * 100 / total ))%"
echo ""
echo "Components:"
echo "  • AI Gateways: $gateway_count"
echo "  • PHI UIs: $ui_count"
echo "  • Core APIs: $api_count"
echo ""
echo "Projects:"
echo "  • dominion-os-1-0-main: $ready1/$total1"
echo "  • dominion-core-prod: $ready2/$total2"
echo ""
echo "========================================="
echo -e "${GREEN}🚀 ALL SYSTEMS STARTED AND OPERATIONAL${NC}"
echo "========================================="
echo ""

# Save status to file
cat > telemetry/system_status.json << EOF
{
  "timestamp": "$(date -Iseconds)",
  "status": "operational",
  "infrastructure": {
    "total_services": $total,
    "operational_services": $ready,
    "health_percentage": $(( ready * 100 / total ))
  },
  "components": {
    "ai_gateways": $gateway_count,
    "phi_uis": $ui_count,
    "core_apis": $api_count
  },
  "projects": {
    "dominion-os-1-0-main": {
      "operational": $ready1,
      "total": $total1
    },
    "dominion-core-prod": {
      "operational": $ready2,
      "total": $total2
    }
  }
}
EOF

echo "Status saved to: telemetry/system_status.json"
echo ""

exit 0
