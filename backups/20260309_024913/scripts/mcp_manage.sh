#!/bin/bash
# ═══════════════════════════════════════════════════════════════
# MCP SERVICES MANAGEMENT SCRIPT
# Quick commands for managing MCP services
# ═══════════════════════════════════════════════════════════════

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_header() {
    echo -e "\n${BLUE}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}  $1${NC}"
    echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}\n"
}

print_success() { echo -e "${GREEN}✓${NC} $1"; }
print_error() { echo -e "${RED}✗${NC} $1"; }
print_info() { echo -e "${BLUE}ℹ${NC} $1"; }

# Change to project root
cd "$(dirname "$0")/.." || exit 1

# Show usage if no arguments
if [ $# -eq 0 ]; then
    print_header "MCP Services Management"
    echo "Usage: $0 <command>"
    echo ""
    echo "Commands:"
    echo "  start       - Start all MCP services"
    echo "  stop        - Stop all MCP services"
    echo "  restart     - Restart all MCP services"
    echo "  status      - Show service status"
    echo "  logs        - Show logs (follow mode)"
    echo "  logs-tail   - Show last 50 lines of logs"
    echo "  health      - Run comprehensive health check"
    echo "  score       - Calculate live ops score"
    echo "  clean       - Stop and remove containers (keeps volumes)"
    echo "  clean-all   - Stop and remove everything (including volumes)"
    echo "  urls        - Show access URLs"
    echo ""
    exit 0
fi

COMMAND=$1

case $COMMAND in
    start)
        print_header "Starting MCP Services"
        docker-compose -f docker-compose-mcp.yml up -d
        print_success "Services started"
        print_info "Run '$0 status' to check service status"
        ;;
    
    stop)
        print_header "Stopping MCP Services"
        docker-compose -f docker-compose-mcp.yml stop
        print_success "Services stopped"
        ;;
    
    restart)
        print_header "Restarting MCP Services"
        docker-compose -f docker-compose-mcp.yml restart
        print_success "Services restarted"
        ;;
    
    status)
        print_header "MCP Services Status"
        docker-compose -f docker-compose-mcp.yml ps
        echo ""
        RUNNING=$(docker-compose -f docker-compose-mcp.yml ps | grep -c "Up" || true)
        print_info "$RUNNING services running"
        ;;
    
    logs)
        print_header "MCP Services Logs (Press Ctrl+C to exit)"
        docker-compose -f docker-compose-mcp.yml logs -f
        ;;
    
    logs-tail)
        print_header "MCP Services Logs (Last 50 Lines)"
        docker-compose -f docker-compose-mcp.yml logs --tail=50
        ;;
    
    health)
        print_header "Running Health Check"
        if [ -f "scripts/mcp_health_check.sh" ]; then
            bash scripts/mcp_health_check.sh
        else
            print_error "Health check script not found"
            exit 1
        fi
        ;;
    
    score)
        print_header "Calculating Live Ops Score"
        if [ -f "scripts/calculate_docker_live_ops_score.sh" ]; then
            bash scripts/calculate_docker_live_ops_score.sh
        else
            print_error "Score calculator not found"
            exit 1
        fi
        ;;
    
    clean)
        print_header "Cleaning Up (Preserving Volumes)"
        print_info "This will stop and remove containers, but keep data volumes"
        docker-compose -f docker-compose-mcp.yml down
        print_success "Cleanup complete"
        ;;
    
    clean-all)
        print_header "Complete Cleanup (Including Volumes)"
        print_info "WARNING: This will delete all data!"
        read -p "Are you sure? (type 'yes' to confirm): " -r
        if [ "$REPLY" = "yes" ]; then
            docker-compose -f docker-compose-mcp.yml down -v
            docker network rm mcp-network 2>/dev/null || true
            print_success "Complete cleanup done"
        else
            print_info "Cleanup cancelled"
        fi
        ;;
    
    urls)
        print_header "MCP Services Access URLs"
        echo "Monitoring:"
        echo "  • Prometheus:     http://localhost:9090"
        echo "  • Grafana:        http://localhost:3008 (admin/admin)"
        echo ""
        echo "MCP Services:"
        echo "  • Atlassian:      http://localhost:3000/health"
        echo "  • Figma:          http://localhost:3001/health"
        echo "  • Stripe:         http://localhost:3002/health"
        echo "  • GitHub:         http://localhost:3003/health"
        echo "  • Playwright:     http://localhost:3004"
        echo "  • Chrome:         http://localhost:3005"
        echo "  • Pylance:        http://localhost:3007"
        echo ""
        ;;
    
    *)
        print_error "Unknown command: $COMMAND"
        print_info "Run '$0' without arguments to see available commands"
        exit 1
        ;;
esac
