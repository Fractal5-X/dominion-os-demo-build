#!/bin/bash
# MCP Servers Health Check Script
# Verifies all MCP servers are running optimally in Docker Desktop Pro

set -euo pipefail

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo "═══════════════════════════════════════════════════════════════"
echo "  MCP SERVERS HEALTH CHECK - DOCKER DESKTOP PRO"
echo "  $(date)"
echo "═══════════════════════════════════════════════════════════════"
echo ""

# Check if Docker is running
if ! docker info > /dev/null 2>&1; then
    echo -e "${RED}❌ Docker daemon is not running${NC}"
    exit 1
fi

echo -e "${GREEN}✅ Docker daemon is running${NC}"
echo ""

# Docker info
echo "📊 DOCKER DESKTOP PRO CONFIGURATION"
echo "───────────────────────────────────────────────────────────────"
CPU_COUNT=$(docker info --format '{{.NCPU}}')
MEMORY_GB=$(docker info --format '{{.MemTotal}}' | awk '{printf "%.0f", $1/1024/1024/1024}')
DOCKER_VERSION=$(docker version --format '{{.Server.Version}}')

echo "Docker Version: $DOCKER_VERSION"
echo "Available CPUs: $CPU_COUNT"
echo "Available Memory: ${MEMORY_GB}GB"
echo ""

# Check if resources are optimal
if [ "$CPU_COUNT" -ge 16 ] && [ "$MEMORY_GB" -ge 48 ]; then
    echo -e "${GREEN}✅ Resources are optimal for all MCP servers${NC}"
elif [ "$CPU_COUNT" -ge 8 ] && [ "$MEMORY_GB" -ge 16 ]; then
    echo -e "${YELLOW}⚠️  Resources meet minimum requirements but not optimal${NC}"
    echo "   Recommended: 16+ CPUs, 48+ GB RAM"
else
    echo -e "${RED}❌ Insufficient resources for optimal MCP operations${NC}"
    echo "   Current: ${CPU_COUNT} CPUs, ${MEMORY_GB}GB RAM"
    echo "   Minimum: 8 CPUs, 16GB RAM"
    echo "   Recommended: 16+ CPUs, 48+ GB RAM"
fi
echo ""

# Check if docker-compose file exists
if [ ! -f "docker-compose-mcp.yml" ]; then
    echo -e "${YELLOW}⚠️  docker-compose-mcp.yml not found${NC}"
    echo "   Run from project root or create the file first"
    exit 1
fi

# MCP Servers to check
declare -A MCP_SERVERS=(
    ["mcp-atlassian"]="3000"
    ["mcp-figma"]="3001"
    ["mcp-stripe"]="3002"
    ["mcp-github"]="3003"
    ["mcp-playwright"]="3004"
    ["mcp-chrome"]="3005"
    ["mcp-pylance"]="3007"
    ["mcp-prometheus"]="9090"
    ["mcp-grafana"]="3008"
)

echo "🔍 MCP SERVERS STATUS"
echo "───────────────────────────────────────────────────────────────"

HEALTHY_COUNT=0
TOTAL_COUNT=${#MCP_SERVERS[@]}

for server in "${!MCP_SERVERS[@]}"; do
    port=${MCP_SERVERS[$server]}
    
    # Check if container is running
    if docker ps --format '{{.Names}}' | grep -q "^${server}$"; then
        # Get container status
        status=$(docker inspect --format='{{.State.Status}}' "$server" 2>/dev/null || echo "unknown")
        health=$(docker inspect --format='{{.State.Health.Status}}' "$server" 2>/dev/null || echo "none")
        
        if [ "$status" = "running" ]; then
            if [ "$health" = "healthy" ] || [ "$health" = "none" ]; then
                echo -e "${GREEN}✅${NC} $server - Running on port $port - Status: $status"
                HEALTHY_COUNT=$((HEALTHY_COUNT + 1))
            else
                echo -e "${YELLOW}⚠️${NC}  $server - Running but unhealthy - Health: $health"
            fi
        else
            echo -e "${RED}❌${NC} $server - Not running - Status: $status"
        fi
    else
        echo -e "${RED}❌${NC} $server - Container not found"
    fi
done

echo ""
echo "───────────────────────────────────────────────────────────────"
echo "Health Score: $HEALTHY_COUNT/$TOTAL_COUNT servers operational"

if [ "$HEALTHY_COUNT" -eq "$TOTAL_COUNT" ]; then
    echo -e "${GREEN}✅ ALL MCP SERVERS OPERATIONAL${NC}"
    SCORE=100
elif [ "$HEALTHY_COUNT" -ge $((TOTAL_COUNT * 3 / 4)) ]; then
    echo -e "${YELLOW}⚠️  MOST SERVERS OPERATIONAL${NC}"
    SCORE=$((HEALTHY_COUNT * 100 / TOTAL_COUNT))
elif [ "$HEALTHY_COUNT" -gt 0 ]; then
    echo -e "${YELLOW}⚠️  SOME SERVERS OPERATIONAL${NC}"
    SCORE=$((HEALTHY_COUNT * 100 / TOTAL_COUNT))
else
    echo -e "${RED}❌ NO SERVERS OPERATIONAL${NC}"
    SCORE=0
fi

echo "Overall Score: $SCORE/100"
echo ""

# Check network
echo "🌐 NETWORK STATUS"
echo "───────────────────────────────────────────────────────────────"
if docker network ls | grep -q "mcp-network"; then
    echo -e "${GREEN}✅${NC} mcp-network configured"
else
    echo -e "${RED}❌${NC} mcp-network not found"
fi
echo ""

# Check volumes
echo "💾 VOLUME STATUS"
echo "───────────────────────────────────────────────────────────────"
VOLUMES=("playwright-cache" "pylance-cache" "figma-cache" "prometheus-data" "grafana-data")
for vol in "${VOLUMES[@]}"; do
    if docker volume ls | grep -q "$vol"; then
        size=$(docker volume inspect "$vol" --format '{{.Mountpoint}}' 2>/dev/null | xargs du -sh 2>/dev/null | cut -f1 || echo "unknown")
        echo -e "${GREEN}✅${NC} $vol - Size: $size"
    else
        echo -e "${YELLOW}⚠️${NC}  $vol - Not found"
    fi
done
echo ""

# Resource usage by containers
echo "📈 CONTAINER RESOURCE USAGE"
echo "───────────────────────────────────────────────────────────────"
docker stats --no-stream --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.NetIO}}" --filter "name=mcp-" 2>/dev/null || echo "No MCP containers running"
echo ""

# Quick URLs
echo "🔗 ACCESS URLs"
echo "───────────────────────────────────────────────────────────────"
echo "Grafana Dashboard:  http://localhost:3008 (admin/admin)"
echo "Prometheus:         http://localhost:9090"
echo "Atlassian MCP:      http://localhost:3000"
echo "Figma MCP:          http://localhost:3001"
echo "Stripe MCP:         http://localhost:3002"
echo "GitHub MCP:         http://localhost:3003"
echo "Playwright MCP:     http://localhost:3004"
echo "Chrome MCP:         http://localhost:3005"
echo "Pylance MCP:        http://localhost:3007"
echo ""

# Management commands
echo "🛠️  QUICK COMMANDS"
echo "───────────────────────────────────────────────────────────────"
echo "Start all:    docker-compose -f docker-compose-mcp.yml up -d"
echo "Stop all:     docker-compose -f docker-compose-mcp.yml down"
echo "View logs:    docker-compose -f docker-compose-mcp.yml logs -f"
echo "Restart:      docker-compose -f docker-compose-mcp.yml restart"
echo ""

echo "═══════════════════════════════════════════════════════════════"
echo "  Health Check Complete"
echo "═══════════════════════════════════════════════════════════════"

exit 0
