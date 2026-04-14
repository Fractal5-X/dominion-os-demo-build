#!/bin/bash
# ============================================================================
# PHI SOVEREIGN DEPLOYMENT SCRIPT - DOCKER DESKTOP PRO
# Execute on at2 workstation (AMD Ryzen 5 7600X + RTX 4070)
# ============================================================================
# Sovereign Authority Level: 9/9
# ============================================================================

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Banner
echo -e "${BLUE}╔══════════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║          PHI SOVEREIGN DEPLOYMENT - DOCKER DESKTOP PRO               ║${NC}"
echo -e "${BLUE}║              Authority Level 9/9 - Maximum Power                     ║${NC}"
echo -e "${BLUE}╚══════════════════════════════════════════════════════════════════════╝${NC}"
echo ""

# Check Docker is available
echo -e "${YELLOW}[1/6] Checking Docker availability...${NC}"
if ! command -v docker &> /dev/null; then
    echo -e "${RED}✗ Docker not found. Please install Docker Desktop Pro.${NC}"
    exit 1
fi

if ! docker info &> /dev/null; then
    echo -e "${RED}✗ Docker daemon not running. Please start Docker Desktop.${NC}"
    exit 1
fi
echo -e "${GREEN}✓ Docker Desktop available and running${NC}"
echo ""

# Check Docker Compose
echo -e "${YELLOW}[2/6] Checking Docker Compose...${NC}"
if docker compose version &> /dev/null; then
    COMPOSE_CMD="docker compose"
elif command -v docker-compose &> /dev/null; then
    COMPOSE_CMD="docker-compose"
else
    echo -e "${RED}✗ Docker Compose not found.${NC}"
    exit 1
fi
echo -e "${GREEN}✓ Docker Compose available${NC}"
echo ""

# Check environment file
echo -e "${YELLOW}[3/6] Configuring environment...${NC}"
if [ ! -f .env ]; then
    if [ -f .env.desktop-pro ]; then
        echo -e "${GREEN}✓ Copying .env.desktop-pro to .env${NC}"
        cp .env.desktop-pro .env
    else
        echo -e "${RED}✗ .env.desktop-pro template not found${NC}"
        exit 1
    fi
else
    echo -e "${GREEN}✓ .env already exists${NC}"
fi
echo ""

# Create required directories
echo -e "${YELLOW}[4/6] Creating data directories...${NC}"
mkdir -p data logs scripts/data scripts/logs
echo -e "${GREEN}✓ Directories created${NC}"
echo ""

# Deploy stack
echo -e "${YELLOW}[5/6] Deploying PHI Sovereign Stack...${NC}"
echo -e "${BLUE}Command: ${COMPOSE_CMD} -f docker-compose.desktop-pro.yml up -d${NC}"
$COMPOSE_CMD -f docker-compose.desktop-pro.yml up -d

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ Deployment successful${NC}"
else
    echo -e "${RED}✗ Deployment failed${NC}"
    exit 1
fi
echo ""

# Wait for services to be healthy
echo -e "${YELLOW}[6/6] Waiting for services to be healthy...${NC}"
sleep 5

# Check service status
echo -e "${BLUE}╔══════════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║                        SERVICE STATUS                                ║${NC}"
echo -e "${BLUE}╚══════════════════════════════════════════════════════════════════════╝${NC}"
$COMPOSE_CMD -f docker-compose.desktop-pro.yml ps
echo ""

# Display access URLs
echo -e "${GREEN}╔══════════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║                   DEPLOYMENT COMPLETE ✓                              ║${NC}"
echo -e "${GREEN}╚══════════════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${BLUE}📊 Access Points:${NC}"
echo -e "  ${GREEN}▸ PHI Dashboard:${NC}    http://localhost:5000"
echo -e "  ${GREEN}▸ OAuth Server:${NC}     http://localhost:8080"
echo -e "  ${GREEN}▸ AskPHI Widget:${NC}    http://localhost:8081"
echo -e "  ${GREEN}▸ Prometheus:${NC}       http://localhost:9090"
echo -e "  ${GREEN}▸ Grafana:${NC}          http://localhost:3000 (admin/sovereign_admin)"
echo -e "  ${GREEN}▸ PostgreSQL:${NC}       localhost:5432"
echo -e "  ${GREEN}▸ Redis:${NC}            localhost:6379"
echo ""
echo -e "${BLUE}📋 Management Commands:${NC}"
echo -e "  ${YELLOW}▸ View logs:${NC}        $COMPOSE_CMD -f docker-compose.desktop-pro.yml logs -f"
echo -e "  ${YELLOW}▸ Stop services:${NC}    $COMPOSE_CMD -f docker-compose.desktop-pro.yml down"
echo -e "  ${YELLOW}▸ Restart:${NC}          $COMPOSE_CMD -f docker-compose.desktop-pro.yml restart"
echo -e "  ${YELLOW}▸ Status:${NC}           $COMPOSE_CMD -f docker-compose.desktop-pro.yml ps"
echo ""
echo -e "${GREEN}🛡️  Sovereign Authority Level: 9/9 - Maximum Power Confirmed${NC}"
echo ""

# Open browser (optional)
if command -v xdg-open &> /dev/null; then
    echo -e "${YELLOW}Opening PHI Dashboard in browser...${NC}"
    xdg-open http://localhost:5000 2>/dev/null &
elif command -v open &> /dev/null; then
    echo -e "${YELLOW}Opening PHI Dashboard in browser...${NC}"
    open http://localhost:5000 2>/dev/null &
fi

exit 0
