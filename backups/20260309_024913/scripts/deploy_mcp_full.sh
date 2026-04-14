#!/bin/bash
# ═══════════════════════════════════════════════════════════════
# MCP SERVICES FULL DEPLOYMENT SCRIPT
# Automates complete deployment and verification on Docker Desktop Pro
# ═══════════════════════════════════════════════════════════════

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Helper functions
print_header() {
    echo -e "\n${BLUE}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}  $1${NC}"
    echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}\n"
}

print_success() {
    echo -e "${GREEN}✓${NC} $1"
}

print_error() {
    echo -e "${RED}✗${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

print_info() {
    echo -e "${BLUE}ℹ${NC} $1"
}

# Change to project root
cd "$(dirname "$0")/.." || exit 1

print_header "MCP SERVICES DEPLOYMENT - Docker Desktop Pro"
echo "Started: $(date)"
echo ""

# ═══════════════════════════════════════════════════════════════
# PHASE 1: PRE-FLIGHT CHECKS
# ═══════════════════════════════════════════════════════════════

print_header "Phase 1: Pre-flight Checks"

# Check Docker daemon
print_info "Checking Docker daemon..."
if ! docker info > /dev/null 2>&1; then
    print_error "Docker daemon is not running"
    print_warning "Please start Docker Desktop and try again"
    exit 1
fi
print_success "Docker daemon is running"

# Check Docker version
DOCKER_VERSION=$(docker version --format '{{.Server.Version}}')
print_success "Docker version: $DOCKER_VERSION"

# Check Docker Compose
if ! docker-compose version > /dev/null 2>&1; then
    print_error "Docker Compose not found"
    exit 1
fi
COMPOSE_VERSION=$(docker-compose version --short)
print_success "Docker Compose version: $COMPOSE_VERSION"

# Check system resources
CPU_COUNT=$(docker info --format '{{.NCPU}}')
MEMORY_GB=$(docker info --format '{{.MemTotal}}' | awk '{print int($1/1024/1024/1024)}')
print_success "System resources: ${CPU_COUNT} CPUs, ${MEMORY_GB}GB RAM"

if [ "$CPU_COUNT" -lt 8 ]; then
    print_warning "CPU count ($CPU_COUNT) is below minimum (8). Performance may be affected."
fi

if [ "$MEMORY_GB" -lt 16 ]; then
    print_warning "Memory ($MEMORY_GB GB) is below minimum (16GB). Deployment may fail."
fi

# Check for required files
print_info "Checking required files..."
REQUIRED_FILES=(
    "docker-compose-mcp.yml"
    ".env.mcp"
    "prometheus.yml"
)

for file in "${REQUIRED_FILES[@]}"; do
    if [ ! -f "$file" ]; then
        print_error "Required file not found: $file"
        exit 1
    fi
    print_success "Found: $file"
done

# Check .env.mcp configuration
print_info "Checking .env.mcp configuration..."
if grep -q "your_token_here" .env.mcp 2>/dev/null || grep -q "your-.*-here" .env.mcp 2>/dev/null; then
    print_warning ".env.mcp contains placeholder values"
    print_warning "Some services may not function without proper API tokens"
    echo ""
    echo "Required tokens:"
    echo "  • GITHUB_TOKEN - Get from: https://github.com/settings/tokens"
    echo "  • ATLASSIAN_API_TOKEN - Get from: https://id.atlassian.com/manage-profile/security/api-tokens"
    echo "  • STRIPE_SECRET_KEY - Get from: https://dashboard.stripe.com/apikeys"
    echo "  • FIGMA_API_TOKEN - Get from: https://www.figma.com/developers/api#access-tokens"
    echo ""
    read -p "Continue anyway? (y/N) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        print_info "Edit .env.mcp with your API tokens, then run this script again"
        exit 0
    fi
fi

print_success "Pre-flight checks complete"

# ═══════════════════════════════════════════════════════════════
# PHASE 2: NETWORK AND VOLUME SETUP
# ═══════════════════════════════════════════════════════════════

print_header "Phase 2: Network and Volume Setup"

# Create network if it doesn't exist
print_info "Setting up Docker network..."
if docker network inspect mcp-network > /dev/null 2>&1; then
    print_success "Network 'mcp-network' already exists"
else
    docker network create --driver bridge --subnet 172.28.0.0/16 mcp-network
    print_success "Created network 'mcp-network'"
fi

# Create volumes
print_info "Creating persistent volumes..."
VOLUMES=(
    "playwright-cache"
    "pylance-cache"
    "figma-cache"
    "prometheus-data"
    "grafana-data"
)

for volume in "${VOLUMES[@]}"; do
    if docker volume inspect "$volume" > /dev/null 2>&1; then
        print_success "Volume '$volume' already exists"
    else
        docker volume create "$volume" > /dev/null
        print_success "Created volume '$volume'"
    fi
done

# ═══════════════════════════════════════════════════════════════
# PHASE 3: PULL IMAGES
# ═══════════════════════════════════════════════════════════════

print_header "Phase 3: Pulling Docker Images"

print_info "This may take several minutes on first run..."
if docker-compose -f docker-compose-mcp.yml pull; then
    print_success "All images pulled successfully"
else
    print_error "Failed to pull some images"
    exit 1
fi

# ═══════════════════════════════════════════════════════════════
# PHASE 4: DEPLOY SERVICES
# ═══════════════════════════════════════════════════════════════

print_header "Phase 4: Deploying MCP Services"

print_info "Starting all services..."
if docker-compose -f docker-compose-mcp.yml up -d; then
    print_success "Services started successfully"
else
    print_error "Failed to start services"
    exit 1
fi

# Wait for services to initialize
print_info "Waiting for services to initialize (30 seconds)..."
sleep 30

# ═══════════════════════════════════════════════════════════════
# PHASE 5: VERIFICATION
# ═══════════════════════════════════════════════════════════════

print_header "Phase 5: Deployment Verification"

# Check container status
print_info "Checking container status..."
RUNNING_COUNT=$(docker-compose -f docker-compose-mcp.yml ps | grep -c "Up" || true)
print_success "$RUNNING_COUNT services are running"

# List services
echo ""
echo "Service Status:"
docker-compose -f docker-compose-mcp.yml ps

# Run health check
echo ""
print_info "Running comprehensive health check..."
if [ -f "scripts/mcp_health_check.sh" ]; then
    bash scripts/mcp_health_check.sh
else
    print_warning "Health check script not found, skipping detailed checks"
fi

# ═══════════════════════════════════════════════════════════════
# PHASE 6: LIVE OPS SCORING
# ═══════════════════════════════════════════════════════════════

print_header "Phase 6: Live Ops Score Calculation"

if [ -f "scripts/calculate_docker_live_ops_score.sh" ]; then
    bash scripts/calculate_docker_live_ops_score.sh
else
    print_warning "Score calculator not found, skipping scoring"
fi

# ═══════════════════════════════════════════════════════════════
# COMPLETION SUMMARY
# ═══════════════════════════════════════════════════════════════

print_header "Deployment Complete"

echo "Access URLs:"
echo "  • Prometheus:     http://localhost:9090"
echo "  • Grafana:        http://localhost:3008 (admin/admin)"
echo "  • Atlassian MCP:  http://localhost:3000"
echo "  • Figma MCP:      http://localhost:3001"
echo "  • Stripe MCP:     http://localhost:3002"
echo "  • GitHub MCP:     http://localhost:3003"
echo "  • Playwright MCP: http://localhost:3004"
echo "  • Chrome MCP:     http://localhost:3005"
echo "  • Pylance MCP:    http://localhost:3007"
echo ""
echo "Management Commands:"
echo "  • View logs:      docker-compose -f docker-compose-mcp.yml logs -f"
echo "  • Stop services:  docker-compose -f docker-compose-mcp.yml down"
echo "  • Restart all:    docker-compose -f docker-compose-mcp.yml restart"
echo "  • Check status:   bash scripts/calculate_docker_live_ops_score.sh"
echo ""
print_success "All systems deployed successfully!"
echo "Completed: $(date)"
