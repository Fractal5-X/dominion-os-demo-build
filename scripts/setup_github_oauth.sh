#!/bin/bash
# PHI Chief AI - GitHub OAuth Setup Script
# Sets up GitHub OAuth app and GCP secrets for AskPhi widget

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m' # No Color

# Configuration
GCP_PROJECT="dominion-core-prod"
OAUTH_SERVICE_NAME="phi-oauth-server"
SERVICE_ACCOUNT="447370233441-compute@developer.gserviceaccount.com"

# Logging functions
log() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')] $1${NC}"
}

success() {
    echo -e "${GREEN}✅ $1${NC}"
}

error() {
    echo -e "${RED}❌ $1${NC}" >&2
}

warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

info() {
    echo -e "${PURPLE}ℹ️  $1${NC}"
}

# Function to create GitHub OAuth secrets
create_oauth_secrets() {
    log "Setting up GitHub OAuth secrets..."

    # Check if secrets already exist
    if gcloud secrets describe github-oauth-client-id --project "$GCP_PROJECT" > /dev/null 2>&1; then
        warning "GitHub OAuth secrets already exist"
        return 0
    fi

    info "GitHub OAuth secrets not found. Please create them manually:"
    echo ""
    echo "1. Go to https://github.com/settings/applications/new"
    echo "2. Create a new OAuth App with these settings:"
    echo "   - Application name: PHI Chief AI AskPhi"
    echo "   - Homepage URL: https://phi-askphi-widget-447370233441.us-central1.run.app"
    echo "   - Authorization callback URL: https://phi-oauth-server-447370233441.us-central1.run.app/auth/callback"
    echo "3. Copy the Client ID and Client Secret"
    echo ""
    echo "4. Create the secrets:"
    echo "   echo -n 'YOUR_CLIENT_ID' | gcloud secrets create github-oauth-client-id --project $GCP_PROJECT --data-file=-"
    echo "   echo -n 'YOUR_CLIENT_SECRET' | gcloud secrets create github-oauth-client-secret --project $GCP_PROJECT --data-file=-"
    echo ""
    echo "5. Grant permissions:"
    echo "   gcloud secrets add-iam-policy-binding github-oauth-client-id --member='serviceAccount:$SERVICE_ACCOUNT' --role='roles/secretmanager.secretAccessor' --project $GCP_PROJECT"
    echo "   gcloud secrets add-iam-policy-binding github-oauth-client-secret --member='serviceAccount:$SERVICE_ACCOUNT' --role='roles/secretmanager.secretAccessor' --project $GCP_PROJECT"
    echo ""
    echo "6. Redeploy the OAuth server:"
    echo "   gcloud run services update $OAUTH_SERVICE_NAME --project $GCP_PROJECT --region us-central1"
    echo ""

    warning "Please complete the above steps, then run this script again"
    exit 1
}

# Function to grant permissions to service account
grant_secret_permissions() {
    log "Granting secret access permissions to service account..."

    # Grant access to client ID secret
    if gcloud secrets add-iam-policy-binding github-oauth-client-id \
        --member="serviceAccount:$SERVICE_ACCOUNT" \
        --role="roles/secretmanager.secretAccessor" \
        --project "$GCP_PROJECT" > /dev/null 2>&1; then
        success "Granted access to github-oauth-client-id secret"
    else
        warning "Could not grant access to github-oauth-client-id (may already have access)"
    fi

    # Grant access to client secret
    if gcloud secrets add-iam-policy-binding github-oauth-client-secret \
        --member="serviceAccount:$SERVICE_ACCOUNT" \
        --role="roles/secretmanager.secretAccessor" \
        --project "$GCP_PROJECT" > /dev/null 2>&1; then
        success "Granted access to github-oauth-client-secret secret"
    else
        warning "Could not grant access to github-oauth-client-secret (may already have access)"
    fi
}

# Function to redeploy OAuth server
redeploy_oauth_server() {
    log "Redeploying OAuth server to pick up new secrets..."

    gcloud run services update "$OAUTH_SERVICE_NAME" \
        --project "$GCP_PROJECT" \
        --region us-central1 \
        --set-secrets "GITHUB_CLIENT_ID=github-oauth-client-id:latest" \
        --set-secrets "GITHUB_CLIENT_SECRET=github-oauth-client-secret:latest"

    success "OAuth server redeployed with new secrets"
}

# Function to test OAuth server health
test_oauth_server() {
    log "Testing OAuth server health..."

    # Get service URL
    OAUTH_URL=$(gcloud run services describe "$OAUTH_SERVICE_NAME" \
        --project "$GCP_PROJECT" \
        --region us-central1 \
        --format="value(status.url)")

    # Test health endpoint
    if curl -f -s "$OAUTH_URL/health" > /dev/null 2>&1; then
        success "OAuth server is healthy"
        return 0
    else
        error "OAuth server is not healthy"
        return 1
    fi
}

# Function to display setup summary
display_summary() {
    log "GitHub OAuth setup summary:"

    echo ""
    echo "========================================="
    echo "🔐 GITHUB OAUTH CONFIGURATION COMPLETE"
    echo "========================================="
    echo ""

    OAUTH_URL=$(gcloud run services describe "$OAUTH_SERVICE_NAME" \
        --project "$GCP_PROJECT" \
        --region us-central1 \
        --format="value(status.url)")

    WIDGET_URL=$(gcloud run services describe "phi-askphi-widget" \
        --project "$GCP_PROJECT" \
        --region us-central1 \
        --format="value(status.url)")

    echo "OAuth Server URL: $OAUTH_URL"
    echo "AskPhi Widget URL: $WIDGET_URL"
    echo ""
    echo "GitHub OAuth App Settings:"
    echo "• Homepage URL: $WIDGET_URL"
    echo "• Callback URL: $OAUTH_URL/auth/callback"
    echo ""
    echo "Next Steps:"
    echo "1. Test the authentication flow at: $WIDGET_URL"
    echo "2. Verify organization access (Fractal5-Solutions)"
    echo "3. Monitor authentication logs"
    echo ""
    echo "========================================="
}

# Main execution
main() {
    log "Starting PHI Chief AI GitHub OAuth setup"

    # Create OAuth secrets (if not exist)
    create_oauth_secrets

    # Grant permissions
    grant_secret_permissions

    # Redeploy OAuth server
    redeploy_oauth_server

    # Test health
    if test_oauth_server; then
        success "OAuth setup completed successfully"
        display_summary
    else
        error "OAuth setup completed but server is not healthy"
        info "Check the GCP Cloud Run logs for the $OAUTH_SERVICE_NAME service"
        exit 1
    fi
}

# Run main function
main "$@"
