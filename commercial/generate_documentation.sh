#!/bin/bash
# Documentation Generation for Commercial Products

echo "=== GENERATING COMMERCIAL DOCUMENTATION ==="

# Create installation guides
create_installation_guides() {
    echo "Creating installation guides..."

    # Google Cloud installation guide
    cat > installation_gcloud.md << 'INSTALL_EOF'
# Dominion OS 1.0 - Google Cloud Installation Guide

## Prerequisites
- Google Cloud Platform account
- Billing enabled
- Required permissions: Compute Admin, Storage Admin

## Quick Start
1. Clone the repository:
   ```bash
   git clone https://github.com/your-org/dominion-os-demo-build.git
   cd dominion-os-demo-build
   ```

2. Configure GCP project:
   ```bash
   export GCP_PROJECT_ID=your-project-id
   ./scripts/setup_gcp_project.sh
   ```

3. Deploy sovereign infrastructure:
   ```bash
   ./scripts/phi_optimal_deployment_orchestrator.sh
   ```

4. Verify deployment:
   ```bash
   ./scripts/deployment_verification.sh
   ```

## Post-Installation
- Access command center at: https://your-domain.com
- Configure monitoring dashboards
- Set up backup and disaster recovery
- Review security hardening settings

## Support
For commercial support, contact: support@dominion-os.com
INSTALL_EOF

    # Desktop PC installation guide
    cat > installation_desktop.md << 'DESKTOP_EOF'
# Dominion OS 1.0 - Desktop PC Installation Guide

## System Requirements
- Docker Desktop Pro
- 16GB RAM minimum
- 100GB free disk space
- Linux/Windows/macOS

## Installation Steps
1. Install Docker Desktop Pro:
   - Download from: https://www.docker.com/products/docker-desktop
   - Enable Kubernetes
   - Allocate sufficient resources

2. Clone repository:
   ```bash
   git clone https://github.com/your-org/dominion-os-demo-build.git
   cd dominion-os-demo-build
   ```

3. Run local deployment:
   ```bash
   bash /workspaces/dominion-command-center/scripts/live_ops_start.sh
   ```

4. Access local command center:
   - Open browser to: http://localhost:8080

## Troubleshooting
- Ensure Docker is running
- Check resource allocation
- Verify network connectivity
- Review logs in ./logs/ directory

## Community Support
- GitHub Issues: https://github.com/your-org/dominion-os-demo-build/issues
- Discord Community: https://discord.gg/dominion-os
DESKTOP_EOF
}

# Create troubleshooting guides
create_troubleshooting_guides() {
    echo "Creating troubleshooting guides..."

    cat > troubleshooting.md << 'TROUBLE_EOF'
# Dominion OS Troubleshooting Guide

## Common Issues

### Issue: Services not starting
**Symptoms:** Docker containers fail to start
**Solution:**
1. Check Docker status: `docker ps -a`
2. Review logs: `docker logs <container_id>`
3. Verify resource allocation in Docker Desktop
4. Restart Docker service

### Issue: High resource usage
**Symptoms:** System slowdown, high CPU/memory usage
**Solution:**
1. Monitor with: `docker stats`
2. Check Grafana dashboards
3. Optimize container resource limits
4. Run cleanup: `./scripts/optimize_performance.sh`

### Issue: Network connectivity issues
**Symptoms:** Services unreachable, timeout errors
**Solution:**
1. Check network configuration
2. Verify firewall settings
3. Test connectivity: `curl -v localhost:8080`
4. Review Docker network: `docker network ls`

### Issue: Security alerts
**Symptoms:** Security scan failures, vulnerability warnings
**Solution:**
1. Run security hardening: `./scripts/harden_security.sh`
2. Update all components
3. Review security logs
4. Apply latest patches

## Getting Help
- Check logs in `./logs/` directory
- Run diagnostics: `./scripts/phi_ai_continuous_improvement.sh`
- Contact support based on your plan
TROUBLE_EOF
}

# Main documentation function
main_docs() {
    create_installation_guides
    create_troubleshooting_guides
    echo "Documentation generation completed"
}

# Execute if run directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main_docs
fi
