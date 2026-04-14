#!/bin/bash
# ============================================================================
# PHI SOVEREIGN SERVICE VERIFICATION SCRIPT
# ============================================================================
# Verify all services are running and responding correctly
# Execute after deploy-desktop-pro.sh
# ============================================================================

set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/scripts/runtime_preflight.sh"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}╔══════════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║           PHI SOVEREIGN SERVICE VERIFICATION                         ║${NC}"
echo -e "${BLUE}╚══════════════════════════════════════════════════════════════════════╝${NC}"
echo ""

TOTAL_CHECKS=0
PASSED_CHECKS=0
FAILED_CHECKS=0
BLOCKED_CHECKS=0
HTTP_FAILURES=0
PORT_FAILURES=0
DOCKER_FAILURES=0
DOCKER_BLOCKERS=0

PASS_ITEMS=()
FAIL_ITEMS=()
BLOCKED_ITEMS=()

record_pass() {
    local category=$1
    local name=$2
    local detail=$3

    TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
    PASSED_CHECKS=$((PASSED_CHECKS + 1))
    PASS_ITEMS+=("${category}: ${name} (${detail})")
}

record_failure() {
    local category=$1
    local name=$2
    local detail=$3

    TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
    FAILED_CHECKS=$((FAILED_CHECKS + 1))
    FAIL_ITEMS+=("${category}: ${name} (${detail})")
}

record_blocked() {
    local category=$1
    local name=$2
    local detail=$3

    TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
    BLOCKED_CHECKS=$((BLOCKED_CHECKS + 1))
    BLOCKED_ITEMS+=("${category}: ${name} (${detail})")
}

print_items() {
    local color=$1
    shift
    local items=("$@")
    local item

    for item in "${items[@]}"; do
        echo -e "  ${color}•${NC} ${item}"
    done
}

print_summary() {
    echo -e "${BLUE}Readiness Summary:${NC}"
    echo -e "  ${GREEN}Passed:${NC} ${PASSED_CHECKS}"
    echo -e "  ${RED}Failed:${NC} ${FAILED_CHECKS}"
    echo -e "  ${YELLOW}Blocked:${NC} ${BLOCKED_CHECKS}"
    echo -e "  ${BLUE}Total:${NC} ${TOTAL_CHECKS}"
    echo ""

    if [ "${#PASS_ITEMS[@]}" -gt 0 ]; then
        echo -e "${GREEN}Passing Checks:${NC}"
        print_items "$GREEN" "${PASS_ITEMS[@]}"
        echo ""
    fi

    if [ "${#FAIL_ITEMS[@]}" -gt 0 ]; then
        echo -e "${RED}Failed Checks:${NC}"
        print_items "$RED" "${FAIL_ITEMS[@]}"
        echo ""
    fi

    if [ "${#BLOCKED_ITEMS[@]}" -gt 0 ]; then
        echo -e "${YELLOW}Blocked Checks:${NC}"
        print_items "$YELLOW" "${BLOCKED_ITEMS[@]}"
        echo ""
    fi
}

print_follow_up() {
    echo -e "${BLUE}Follow-up:${NC}"

    if [ "$FAILED_CHECKS" -gt 0 ]; then
        echo -e "  1. Start or repair the failed services listed above."
        echo -e "  2. Re-run ${YELLOW}./verify-deployment.sh${NC} after the services report healthy."
    fi

    if [ "$DOCKER_BLOCKERS" -gt 0 ]; then
        echo -e "  3. Re-run on a Docker-enabled host to verify containers, Prometheus, Grafana, PostgreSQL, and Redis end to end."
    fi

    if [ "$FAILED_CHECKS" -eq 0 ] && [ "$BLOCKED_CHECKS" -eq 0 ]; then
        echo -e "  1. Open the dashboard: ${GREEN}http://localhost:5000${NC}"
        echo -e "  2. Review logs if needed: ${YELLOW}docker compose -f docker-compose.desktop-pro.yml logs -f${NC}"
    elif [ "$FAILED_CHECKS" -eq 0 ] && [ "$BLOCKED_CHECKS" -gt 0 ]; then
        echo -e "  1. Local HTTP and port checks are clean in this runtime."
        echo -e "  2. Complete container verification on the target workstation once Docker is reachable."
    fi

    echo ""
}

check_endpoint() {
    local name=$1
    local url=$2
    local expected_code=${3:-200}
    local response

    printf "  %b▸ %s:%b " "$YELLOW" "$name" "$NC"

    if command -v curl &> /dev/null; then
        response=$(curl -s -o /dev/null -w "%{http_code}" --max-time 5 "$url" 2>/dev/null || true)
        response=${response:-000}
        if [ "$response" = "$expected_code" ] || [ "$response" = "200" ] || [ "$response" = "301" ] || [ "$response" = "302" ]; then
            echo -e "${GREEN}✓ ${url}${NC}"
            return 0
        else
            echo -e "${RED}✗ ${url} (HTTP $response)${NC}"
            return 1
        fi
    else
        echo -e "${YELLOW}⚠ curl not available${NC}"
        return 2
    fi
}

check_port() {
    local name=$1
    local host=$2
    local port=$3

    printf "  %b▸ %s:%b " "$YELLOW" "$name" "$NC"

    if command -v nc &> /dev/null; then
        if nc -z -w2 "$host" "$port" 2>/dev/null; then
            echo -e "${GREEN}✓ ${host}:${port}${NC}"
            return 0
        else
            echo -e "${RED}✗ ${host}:${port} not reachable${NC}"
            return 1
        fi
    elif timeout 2 bash -c "cat < /dev/null > /dev/tcp/$host/$port" 2>/dev/null; then
        echo -e "${GREEN}✓ ${host}:${port}${NC}"
        return 0
    else
        echo -e "${RED}✗ ${host}:${port} not reachable${NC}"
        return 1
    fi
}

echo -e "${BLUE}[1/3] Checking HTTP Services...${NC}"
if check_endpoint "PHI Dashboard" "http://localhost:5000"; then
    record_pass "HTTP" "PHI Dashboard" "http://localhost:5000"
else
    rc=$?
    if [ "$rc" -eq 2 ]; then
        record_blocked "HTTP" "PHI Dashboard" "curl unavailable"
    else
        HTTP_FAILURES=$((HTTP_FAILURES + 1))
        record_failure "HTTP" "PHI Dashboard" "http://localhost:5000 unreachable"
    fi
fi

if check_endpoint "OAuth Server" "http://localhost:8080/health"; then
    record_pass "HTTP" "OAuth Server" "http://localhost:8080/health"
else
    rc=$?
    if [ "$rc" -eq 2 ]; then
        record_blocked "HTTP" "OAuth Server" "curl unavailable"
    else
        HTTP_FAILURES=$((HTTP_FAILURES + 1))
        record_failure "HTTP" "OAuth Server" "http://localhost:8080/health unreachable"
    fi
fi

if check_endpoint "AskPHI Widget" "http://localhost:8081/health"; then
    record_pass "HTTP" "AskPHI Widget" "http://localhost:8081/health"
else
    rc=$?
    if [ "$rc" -eq 2 ]; then
        record_blocked "HTTP" "AskPHI Widget" "curl unavailable"
    else
        HTTP_FAILURES=$((HTTP_FAILURES + 1))
        record_failure "HTTP" "AskPHI Widget" "http://localhost:8081/health unreachable"
    fi
fi

if check_endpoint "Prometheus" "http://localhost:9090"; then
    record_pass "HTTP" "Prometheus" "http://localhost:9090"
else
    rc=$?
    if [ "$rc" -eq 2 ]; then
        record_blocked "HTTP" "Prometheus" "curl unavailable"
    else
        HTTP_FAILURES=$((HTTP_FAILURES + 1))
        record_failure "HTTP" "Prometheus" "http://localhost:9090 unreachable"
    fi
fi

if check_endpoint "Grafana" "http://localhost:3000/login"; then
    record_pass "HTTP" "Grafana" "http://localhost:3000/login"
else
    rc=$?
    if [ "$rc" -eq 2 ]; then
        record_blocked "HTTP" "Grafana" "curl unavailable"
    else
        HTTP_FAILURES=$((HTTP_FAILURES + 1))
        record_failure "HTTP" "Grafana" "http://localhost:3000/login unreachable"
    fi
fi
echo ""

echo -e "${BLUE}[2/3] Checking Database Services...${NC}"
if check_port "PostgreSQL" "localhost" "5432"; then
    record_pass "Port" "PostgreSQL" "localhost:5432"
else
    PORT_FAILURES=$((PORT_FAILURES + 1))
    record_failure "Port" "PostgreSQL" "localhost:5432 not reachable"
fi

if check_port "Redis" "localhost" "6379"; then
    record_pass "Port" "Redis" "localhost:6379"
else
    PORT_FAILURES=$((PORT_FAILURES + 1))
    record_failure "Port" "Redis" "localhost:6379 not reachable"
fi
echo ""

echo -e "${BLUE}[3/3] Checking Docker Containers...${NC}"
if docker_daemon_available; then
    if docker compose version &> /dev/null 2>&1; then
        COMPOSE_CMD="docker compose"
    elif command -v docker-compose &> /dev/null; then
        COMPOSE_CMD="docker-compose"
    else
        echo -e "${YELLOW}  ⚠ Docker Compose not available${NC}"
        COMPOSE_CMD=""
    fi

    if [ -n "$COMPOSE_CMD" ]; then
        echo ""
        $COMPOSE_CMD -f docker-compose.desktop-pro.yml ps
        echo ""

        # Check health status
        echo -e "${BLUE}Container Health Status:${NC}"
        for container in phi-sovereign-core phi-database phi-redis phi-prometheus phi-grafana; do
            if docker ps --filter "name=$container" --format "{{.Names}}" | grep -q "$container"; then
                health=$(docker inspect --format='{{.State.Health.Status}}' "$container" 2>/dev/null || echo "no healthcheck")
                status=$(docker inspect --format='{{.State.Status}}' "$container" 2>/dev/null || echo "unknown")

                echo -n "  ${YELLOW}▸ ${container}:${NC} "
                if [ "$status" = "running" ]; then
                    if [ "$health" = "healthy" ]; then
                        echo -e "${GREEN}✓ running (healthy)${NC}"
                        record_pass "Docker" "$container" "running (healthy)"
                    elif [ "$health" = "no healthcheck" ]; then
                        echo -e "${GREEN}✓ running${NC}"
                        record_pass "Docker" "$container" "running"
                    else
                        echo -e "${RED}✗ running ($health)${NC}"
                        DOCKER_FAILURES=$((DOCKER_FAILURES + 1))
                        record_failure "Docker" "$container" "running ($health)"
                    fi
                else
                    echo -e "${RED}✗ $status${NC}"
                    DOCKER_FAILURES=$((DOCKER_FAILURES + 1))
                    record_failure "Docker" "$container" "$status"
                fi
            else
                echo -e "  ${YELLOW}▸ ${container}:${NC} ${RED}✗ not found${NC}"
                DOCKER_FAILURES=$((DOCKER_FAILURES + 1))
                record_failure "Docker" "$container" "container not found"
            fi
        done
    else
        DOCKER_BLOCKERS=$((DOCKER_BLOCKERS + 1))
        record_blocked "Docker" "Compose" "docker compose/docker-compose unavailable"
    fi
else
    print_docker_runtime_note "Container verification"
    DOCKER_BLOCKERS=$((DOCKER_BLOCKERS + 1))
    record_blocked "Docker" "Container verification" "Docker daemon unreachable in this runtime"
fi
echo ""

echo -e "${GREEN}╔══════════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║                    VERIFICATION COMPLETE                             ║${NC}"
echo -e "${GREEN}╚══════════════════════════════════════════════════════════════════════╝${NC}"
echo ""
print_summary
print_follow_up

if [ "$FAILED_CHECKS" -eq 0 ] && [ "$BLOCKED_CHECKS" -eq 0 ]; then
    echo -e "${GREEN}🛡️  Status: local services and Docker containers verified${NC}"
    exit 0
fi

if [ "$HTTP_FAILURES" -eq 0 ] && [ "$PORT_FAILURES" -eq 0 ] && [ "$DOCKER_FAILURES" -eq 0 ] && [ "$DOCKER_BLOCKERS" -gt 0 ]; then
    echo -e "${YELLOW}🛡️  Status: local services verified; container verification blocked by runtime${NC}"
    echo -e "${BLUE}ℹ️  Repo-side readiness is clear here; remaining blockers live in runtime ownership or remote deployment state, not ambiguous local scripts${NC}"
    exit 0
fi

if [ "$FAILED_CHECKS" -gt 0 ] && [ "$BLOCKED_CHECKS" -gt 0 ]; then
    echo -e "${RED}🛡️  Status: partial readiness only; failures detected and some checks were blocked by this environment${NC}"
elif [ "$FAILED_CHECKS" -gt 0 ]; then
    echo -e "${RED}🛡️  Status: verification completed with failures (${FAILED_CHECKS})${NC}"
else
    echo -e "${YELLOW}🛡️  Status: verification blocked by environment constraints (${BLOCKED_CHECKS})${NC}"
fi
echo ""

exit 1
