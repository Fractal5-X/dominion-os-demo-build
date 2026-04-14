#!/bin/bash
# Docker Desktop Pro Live Ops Alignment Score Calculator
# Systematic verification and scoring aligned with PHI standards

set -euo pipefail

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

SCORE=0
MAX_SCORE=100
PERF_SCORE=0

echo "═══════════════════════════════════════════════════════════════"
echo "  DOCKER DESKTOP PRO LIVE OPS ALIGNMENT SCORE CALCULATOR"
echo "  $(date)"
echo "═══════════════════════════════════════════════════════════════"
echo ""

# Check if Docker is running
if ! docker info > /dev/null 2>&1; then
    echo -e "${RED}❌ Docker daemon is not running - Score: 0/100${NC}"
    exit 1
fi

echo "📊 CALCULATING SCORE..."
echo ""

# ==============================================================================
# 1. DOCKER DESKTOP PRO LICENSE (10 points)
# ==============================================================================
echo -n "Checking Docker Desktop Pro License... "
if docker info 2>/dev/null | grep -iq "license\|subscription"; then
    LICENSE_SCORE=10
    echo -e "${GREEN}✅ +10 points${NC}"
else
    # Check version string for "Pro" indication
    if docker version 2>/dev/null | grep -iq "pro"; then
        LICENSE_SCORE=10
        echo -e "${GREEN}✅ +10 points${NC}"
    else
        LICENSE_SCORE=0
        echo -e "${YELLOW}⚠️  +0 points (Community edition or license not detected)${NC}"
    fi
fi
SCORE=$((SCORE + LICENSE_SCORE))

# ==============================================================================
# 2. RESOURCE ALLOCATION (20 points total: 10 CPU + 10 RAM)
# ==============================================================================
echo -n "Checking CPU Allocation... "
CPU_COUNT=$(docker info --format '{{.NCPU}}' 2>/dev/null || echo "0")

if [ "$CPU_COUNT" -ge 16 ]; then
    CPU_SCORE=10
    echo -e "${GREEN}✅ $CPU_COUNT cores (optimal) +10 points${NC}"
elif [ "$CPU_COUNT" -ge 8 ]; then
    CPU_SCORE=5
    echo -e "${YELLOW}⚠️  $CPU_COUNT cores (minimum met) +5 points${NC}"
else
    CPU_SCORE=0
    echo -e "${RED}❌ $CPU_COUNT cores (below minimum) +0 points${NC}"
fi
SCORE=$((SCORE + CPU_SCORE))

echo -n "Checking Memory Allocation... "
MEMORY_BYTES=$(docker info --format '{{.MemTotal}}' 2>/dev/null || echo "0")
MEMORY_GB=$(echo "$MEMORY_BYTES" | awk '{printf "%.0f", $1/1024/1024/1024}')

if [ "$MEMORY_GB" -ge 48 ]; then
    MEMORY_SCORE=10
    echo -e "${GREEN}✅ ${MEMORY_GB}GB (optimal) +10 points${NC}"
elif [ "$MEMORY_GB" -ge 16 ]; then
    MEMORY_SCORE=5
    echo -e "${YELLOW}⚠️  ${MEMORY_GB}GB (minimum met) +5 points${NC}"
else
    MEMORY_SCORE=0
    echo -e "${RED}❌ ${MEMORY_GB}GB (below minimum) +0 points${NC}"
fi
SCORE=$((SCORE + MEMORY_SCORE))

# ==============================================================================
# 3. MCP SERVICES RUNNING (30 points)
# ==============================================================================
echo -n "Checking MCP Services... "
RUNNING_CONTAINERS=$(docker ps --filter "name=mcp-" --format "{{.Names}}" 2>/dev/null | wc -l)
EXPECTED_CONTAINERS=9

if [ "$RUNNING_CONTAINERS" -eq "$EXPECTED_CONTAINERS" ]; then
    SERVICES_SCORE=30
    echo -e "${GREEN}✅ $RUNNING_CONTAINERS/$EXPECTED_CONTAINERS running +30 points${NC}"
elif [ "$RUNNING_CONTAINERS" -gt 0 ]; then
    SERVICES_SCORE=$((RUNNING_CONTAINERS * 30 / EXPECTED_CONTAINERS))
    echo -e "${YELLOW}⚠️  $RUNNING_CONTAINERS/$EXPECTED_CONTAINERS running +${SERVICES_SCORE} points${NC}"
else
    SERVICES_SCORE=0
    echo -e "${RED}❌ No MCP services running +0 points${NC}"
fi
SCORE=$((SCORE + SERVICES_SCORE))

# ==============================================================================
# 4. HEALTH CHECKS PASSING (20 points)
# ==============================================================================
echo "Checking Service Health Endpoints... "
HEALTHY_COUNT=0
TOTAL_HEALTH_CHECKS=6

# Define services and their health endpoints
declare -A HEALTH_ENDPOINTS=(
    ["Atlassian:3000"]="/health"
    ["Figma:3001"]="/health"
    ["Stripe:3002"]="/health"
    ["GitHub:3003"]="/health"
    ["Prometheus:9090"]="/-/healthy"
    ["Grafana:3008"]="/api/health"
)

for service_port in "${!HEALTH_ENDPOINTS[@]}"; do
    service=$(echo "$service_port" | cut -d: -f1)
    port=$(echo "$service_port" | cut -d: -f2)
    endpoint=${HEALTH_ENDPOINTS[$service_port]}
    
    if curl -sf "http://localhost:$port$endpoint" > /dev/null 2>&1; then
        echo -e "  ${GREEN}✅${NC} $service (port $port)"
        HEALTHY_COUNT=$((HEALTHY_COUNT + 1))
    else
        echo -e "  ${RED}❌${NC} $service (port $port)"
    fi
done

if [ "$HEALTHY_COUNT" -eq "$TOTAL_HEALTH_CHECKS" ]; then
    HEALTH_SCORE=20
    echo -e "${GREEN}All health checks passing +20 points${NC}"
elif [ "$HEALTHY_COUNT" -gt 0 ]; then
    HEALTH_SCORE=$((HEALTHY_COUNT * 20 / TOTAL_HEALTH_CHECKS))
    echo -e "${YELLOW}$HEALTHY_COUNT/$TOTAL_HEALTH_CHECKS passing +${HEALTH_SCORE} points${NC}"
else
    HEALTH_SCORE=0
    echo -e "${RED}No health checks passing +0 points${NC}"
fi
SCORE=$((SCORE + HEALTH_SCORE))

# ==============================================================================
# 5. MONITORING OPERATIONAL (10 points)
# ==============================================================================
echo -n "Checking Monitoring Stack... "
PROMETHEUS_UP=false
GRAFANA_UP=false

if curl -sf http://localhost:9090/-/healthy > /dev/null 2>&1; then
    PROMETHEUS_UP=true
fi

if curl -sf http://localhost:3008/api/health > /dev/null 2>&1; then
    GRAFANA_UP=true
fi

if $PROMETHEUS_UP && $GRAFANA_UP; then
    MONITORING_SCORE=10
    echo -e "${GREEN}✅ Prometheus & Grafana operational +10 points${NC}"
elif $PROMETHEUS_UP || $GRAFANA_UP; then
    MONITORING_SCORE=5
    echo -e "${YELLOW}⚠️  Partial monitoring (Prometheus: $PROMETHEUS_UP, Grafana: $GRAFANA_UP) +5 points${NC}"
else
    MONITORING_SCORE=0
    echo -e "${RED}❌ Monitoring not operational +0 points${NC}"
fi
SCORE=$((SCORE + MONITORING_SCORE))

# ==============================================================================
# 6. PERFORMANCE METRICS (10 points)
# ==============================================================================
echo -n "Checking Performance Metrics... "

if [ "$RUNNING_CONTAINERS" -gt 0 ]; then
    # Get average CPU usage across all MCP containers
    AVG_CPU=$(docker stats --no-stream --format "{{.CPUPerc}}" --filter "name=mcp-" 2>/dev/null | \
              awk '{gsub(/%/,"")} {sum+=$1; count++} END {if(count>0) print sum/count; else print 100}')
    
    # Use bc for floating point comparison if available, otherwise use awk
    if command -v bc &> /dev/null; then
        if (( $(echo "$AVG_CPU < 50" | bc -l 2>/dev/null || echo 0) )); then
            PERF_SCORE=10
            echo -e "${GREEN}✅ Avg CPU ${AVG_CPU}% (excellent) +10 points${NC}"
        elif (( $(echo "$AVG_CPU < 80" | bc -l 2>/dev/null || echo 0) )); then
            PERF_SCORE=5
            echo -e "${YELLOW}⚠️  Avg CPU ${AVG_CPU}% (acceptable) +5 points${NC}"
        else
            PERF_SCORE=0
            echo -e "${RED}❌ Avg CPU ${AVG_CPU}% (high usage) +0 points${NC}"
        fi
    else
        # Fallback to awk for comparison
        PERF_SCORE=$(awk -v cpu="$AVG_CPU" 'BEGIN {
            if (cpu < 50) print 10
            else if (cpu < 80) print 5
            else print 0
        }')
        if [ "$PERF_SCORE" -eq 10 ]; then
            echo -e "${GREEN}✅ Avg CPU ${AVG_CPU}% (excellent) +10 points${NC}"
        elif [ "$PERF_SCORE" -eq 5 ]; then
            echo -e "${YELLOW}⚠️  Avg CPU ${AVG_CPU}% (acceptable) +5 points${NC}"
        else
            echo -e "${RED}❌ Avg CPU ${AVG_CPU}% (high usage) +0 points${NC}"
        fi
    fi
    SCORE=$((SCORE + PERF_SCORE))
else
    echo -e "${YELLOW}⚠️  No containers to measure +0 points${NC}"
    PERF_SCORE=0
fi

# ==============================================================================
# FINAL SCORE AND ASSESSMENT
# ==============================================================================
echo ""
echo "═══════════════════════════════════════════════════════════════"
echo "               LIVE OPS ALIGNMENT SCORE"
echo "═══════════════════════════════════════════════════════════════"
echo ""
echo -e "${BLUE}Final Score: $SCORE / $MAX_SCORE${NC}"
echo ""

# Score breakdown
echo "Score Breakdown:"
echo "  Docker Desktop Pro License:  $LICENSE_SCORE/10"
echo "  CPU Allocation:              $CPU_SCORE/10"
echo "  Memory Allocation:           $MEMORY_SCORE/10"
echo "  MCP Services Running:        $SERVICES_SCORE/30"
echo "  Health Checks:               $HEALTH_SCORE/20"
echo "  Monitoring Stack:            $MONITORING_SCORE/10"
echo "  Performance Metrics:         $PERF_SCORE/10"
echo ""

# Status assessment
if [ "$SCORE" -ge 90 ]; then
    echo -e "${GREEN}Status: ✅ EXCELLENT - Perfectly Operational${NC}"
    echo "Docker Desktop Pro is perfectly configured and aligned with live ops standards."
    EXIT_CODE=0
elif [ "$SCORE" -ge 75 ]; then
    echo -e "${YELLOW}Status: ✅ GOOD - Operational with Minor Optimizations Possible${NC}"
    echo "Docker Desktop Pro is operational but could benefit from optimization."
    EXIT_CODE=0
elif [ "$SCORE" -ge 50 ]; then
    echo -e "${YELLOW}Status: ⚠️  FAIR - Operational but Needs Attention${NC}"
    echo "Docker Desktop Pro is running but requires attention to meet standards."
    EXIT_CODE=1
else
    echo -e "${RED}Status: ❌ POOR - Significant Issues Require Attention${NC}"
    echo "Docker Desktop Pro has critical issues that need immediate attention."
    EXIT_CODE=2
fi

echo ""
echo "═══════════════════════════════════════════════════════════════"
echo ""

# Recommendations based on score
if [ "$SCORE" -lt 90 ]; then
    echo "🔧 RECOMMENDATIONS:"
    
    if [ "$LICENSE_SCORE" -lt 10 ]; then
        echo "  • Verify Docker Desktop Pro license is active"
    fi
    
    if [ "$CPU_SCORE" -lt 10 ]; then
        echo "  • Increase CPU allocation to 16+ cores in Docker Desktop settings"
    fi
    
    if [ "$MEMORY_SCORE" -lt 10 ]; then
        echo "  • Increase memory allocation to 48GB+ in Docker Desktop settings"
    fi
    
    if [ "$SERVICES_SCORE" -lt 30 ]; then
        echo "  • Start missing MCP services: docker-compose -f docker-compose-mcp.yml up -d"
    fi
    
    if [ "$HEALTH_SCORE" -lt 20 ]; then
        echo "  • Review container logs for services failing health checks"
        echo "    docker-compose -f docker-compose-mcp.yml logs"
    fi
    
    if [ "$MONITORING_SCORE" -lt 10 ]; then
        echo "  • Ensure Prometheus and Grafana containers are running"
        echo "    docker-compose -f docker-compose-mcp.yml restart prometheus grafana"
    fi
    
    if [ "$PERF_SCORE" -lt 10 ]; then
        echo "  • Review container resource usage and consider scaling"
        echo "    docker stats --filter 'name=mcp-'"
    fi
    
    echo ""
fi

echo "Next Steps:"
echo "  • Review detailed verification plan: AI_PLAN_DOCKER_DESKTOP_PRO_VERIFICATION.md"
echo "  • Run full health check: bash scripts/mcp_health_check.sh"
echo "  • View monitoring: http://localhost:3008 (Grafana)"
echo ""

exit $EXIT_CODE
