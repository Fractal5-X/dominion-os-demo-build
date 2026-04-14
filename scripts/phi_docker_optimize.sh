#!/bin/bash
# PHI Docker Daemon & Desktop Pro Optimal Configuration
# Automatically detects and configures optimal Docker connections
# Supports Codespaces, Docker Desktop, and Docker-in-Docker modes

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m'

log() {
    echo -e "${BLUE}[DOCKER-CONFIG]${NC} $1"
}

success() {
    echo -e "${GREEN}✅ $1${NC}"
}

warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

error() {
    echo -e "${RED}❌ $1${NC}" >&2
}

# Function to check Docker daemon
check_docker_daemon() {
    log "Checking Docker daemon status..."

    if docker ps >/dev/null 2>&1; then
        success "Docker daemon is running"
        return 0
    else
        warning "Docker daemon is not running"
        return 1
    fi
}

# Function to detect environment
detect_environment() {
    if [ "$CODESPACES" = "true" ]; then
        echo "codespaces"
    elif [ -n "$REMOTE_CONTAINERS" ]; then
        echo "devcontainer"
    elif docker --version >/dev/null 2>&1 && docker context inspect desktop >/dev/null 2>&1; then
        echo "docker-desktop"
    else
        echo "unknown"
    fi
}

# Function to configure for Codespaces
configure_codespaces() {
    log "Configuring for GitHub Codespaces..."

    # Check if Docker Desktop context exists
    if docker context inspect desktop >/dev/null 2>&1; then
        success "Docker Desktop context available"

        # Try to connect to Docker Desktop
        if DOCKER_CONTEXT=desktop docker ps >/dev/null 2>&1; then
            success "Connected to Docker Desktop"
            export DOCKER_CONTEXT=desktop
            success "Docker Desktop context activated"
            return 0
        else
            warning "Cannot connect to Docker Desktop (port forwarding may be needed)"
            log "To enable Docker Desktop in Codespaces:"
            echo "  1. Start Docker Desktop on your local machine"
            echo "  2. In VS Code: Ctrl+Shift+P → 'Codespaces: Forward Port'"
            echo "  3. Forward port 2376 to localhost:2376"
            echo "  4. Run: export DOCKER_CONTEXT=desktop"
        fi
    else
        log "Creating Docker Desktop context..."
        docker context create desktop --docker "host=tcp://localhost:2376" >/dev/null 2>&1
        success "Docker Desktop context created"
    fi

    # Fallback: Try Docker-in-Docker
    if [ -S /var/run/docker.sock ]; then
        success "Docker socket available (Docker-in-Docker)"
        export DOCKER_HOST=unix:///var/run/docker.sock

        # Try to start dockerd if not running
        if ! docker ps >/dev/null 2>&1; then
            log "Attempting to start Docker daemon..."
            sudo dockerd --tls=false --host unix:///var/run/docker.sock --host tcp://0.0.0.0:2376 >/dev/null 2>&1 &
            sleep 5
        fi

        if docker ps >/dev/null 2>&1; then
            success "Docker daemon started successfully"
            return 0
        fi
    fi

    warning "No Docker connectivity available in Codespaces"
    return 1
}

# Function to configure for Docker Desktop
configure_docker_desktop() {
    log "Configuring for Docker Desktop..."

    if docker --context desktop ps >/dev/null 2>&1; then
        success "Docker Desktop connection optimal"
        export DOCKER_CONTEXT=desktop
        return 0
    else
        warning "Docker Desktop not accessible"
        return 1
    fi
}

# Function to optimize Docker settings
optimize_docker_settings() {
    log "Optimizing Docker configuration..."

    # Create optimal daemon.json if it doesn't exist
    if [ ! -f ~/.docker/daemon.json ]; then
        mkdir -p ~/.docker
        cat > ~/.docker/daemon.json << 'EOF'
{
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "10m",
    "max-file": "3"
  },
  "storage-driver": "overlay2",
  "default-ulimits": {
    "nofile": {
      "Name": "nofile",
      "Hard": 64000,
      "Soft": 64000
    }
  },
  "max-concurrent-downloads": 10,
  "max-concurrent-uploads": 10,
  "experimental": true,
  "features": {
    "buildkit": true
  }
}
EOF
        success "Created optimal daemon.json"
    fi

    # Set Docker CLI configuration
    export DOCKER_BUILDKIT=1
    export COMPOSE_DOCKER_CLI_BUILD=1

    success "Docker optimization complete"
}

# Main execution
main() {
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║     PHI DOCKER DAEMON & DESKTOP PRO OPTIMAL CONFIGURATION    ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo ""

    local env=$(detect_environment)
    log "Environment detected: $env"

    case $env in
        codespaces)
            if configure_codespaces; then
                success "Codespaces Docker configuration complete"
            fi
            ;;
        docker-desktop)
            if configure_docker_desktop; then
                success "Docker Desktop configuration complete"
            fi
            ;;
        *)
            warning "Unknown environment - using default configuration"
            ;;
    esac

    optimize_docker_settings

    # Final check
    if check_docker_daemon; then
        success "Docker daemon operational"
        docker --version
        docker compose version
    else
        warning "Docker daemon not available"
        echo ""
        echo "To enable Docker in this environment:"
        echo "• Codespaces: Set up port forwarding to local Docker Desktop"
        echo "• Local: Start Docker Desktop"
        echo "• Dev Container: Use Docker-in-Docker configuration"
    fi

    echo ""
    success "PHI Docker configuration check complete"
}

# Run main function
main "$@"