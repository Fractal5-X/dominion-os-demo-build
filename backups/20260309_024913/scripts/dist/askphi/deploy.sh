#!/bin/bash
# PHI Chief AI - AskPhi Artifact Deployment Script

set -euo pipefail

# Configuration
OAUTH_SERVER_URL="${OAUTH_SERVER_URL:-https://phi-oauth.fractal5.solutions}"
WIDGET_URL="${WIDGET_URL:-https://askphi.fractal5.solutions}"

log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $1"
}

# Update widget with server URLs
update_widget_urls() {
    log "Updating widget with server URLs..."

    sed -i "s|https://your-oauth-server.com|${OAUTH_SERVER_URL}|g" widget.html
    sed -i "s|/chat|${WIDGET_URL}/chat|g" widget.html

    log "Widget URLs updated"
}

# Create deployment package
create_deployment_package() {
    log "Creating deployment package..."

    # Create checksums for integrity verification
    sha256sum widget.html > widget.html.sha256
    sha256sum deploy.sh > deploy.sh.sha256

    # Create deployment manifest
    cat > manifest.json << MANIFEST_EOF
{
    "name": "PHI Chief AI - AskPhi Widget",
    "version": "2.0.0",
    "description": "Secure OAuth-based PHI Chief AI widget",
    "files": [
        "widget.html",
        "widget.html.sha256",
        "deploy.sh",
        "deploy.sh.sha256",
        "manifest.json"
    ],
    "oauth_server": "${OAUTH_SERVER_URL}",
    "widget_url": "${WIDGET_URL}",
    "security": {
        "oauth_flow": "authorization_code_pkce",
        "token_type": "jwt",
        "authorization": "organization_based"
    },
    "deployment_date": "$(date -u +'%Y-%m-%dT%H:%M:%SZ')",
    "checksum_algorithm": "sha256"
}
MANIFEST_EOF

    log "Deployment package created"
}

# Verify deployment integrity
verify_integrity() {
    log "Verifying deployment integrity..."

    if sha256sum -c widget.html.sha256 && sha256sum -c deploy.sh.sha256; then
        log "✅ Integrity verification passed"
    else
        log "❌ Integrity verification failed"
        exit 1
    fi
}

# Deploy to target location
deploy_to_target() {
    local target_dir="${1:-/var/www/html/askphi}"

    log "Deploying to ${target_dir}..."

    sudo mkdir -p "${target_dir}"
    sudo cp widget.html manifest.json "${target_dir}/"
    sudo chown -R www-data:www-data "${target_dir}"
    sudo chmod 644 "${target_dir}"/*.html "${target_dir}"/*.json

    log "Deployment completed successfully"
}

# Main deployment
main() {
    log "Starting AskPhi widget deployment..."

    update_widget_urls
    create_deployment_package
    verify_integrity

    if [ "${1:-}" = "--deploy" ]; then
        deploy_to_target "${2:-}"
    else
        log "Dry run completed. Use --deploy to perform actual deployment."
        log "Example: ./deploy.sh --deploy /var/www/html/askphi"
    fi

    log "AskPhi widget deployment ready"
}

main "$@"
