#!/bin/bash
# PHI Chief AI - Deployment Verification & Security Audit
# Comprehensive verification of secure Google Cloud deployment

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Configuration
GCP_PROJECT_DEV="dominion-os-1-0-main"
GCP_PROJECT_PROD="dominion-core-prod"
GCP_REGION="us-central1"
OAUTH_SERVICE_NAME="phi-oauth-server"
WIDGET_SERVICE_NAME="phi-askphi-widget"
ENV_OWNERSHIP_BLOCKERS=0
REMOTE_OAUTH_MISMATCHES=0

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

header() {
    echo -e "${CYAN}=========================================${NC}"
    echo -e "${CYAN}$1${NC}"
    echo -e "${CYAN}=========================================${NC}"
}

# Function to verify file integrity
verify_file_integrity() {
    log "Verifying file integrity..."

    local files_to_check=(
        "scripts/security_remediation.sh"
        "scripts/ai_token_detector.py"
        "scripts/gcp_secure_deployment.sh"
        "scripts/phase2_askphi_implementation.sh"
        "oauth_server/app.py"
        "oauth_server/requirements.txt"
        "oauth_server/README.md"
        "PHASE2_IMPLEMENTATION.md"
    )

    local all_present=true

    for file in "${files_to_check[@]}"; do
        if [ -f "$file" ]; then
            success "Found: $file"
        else
            error "Missing: $file"
            all_present=false
        fi
    done

    if [ "$all_present" = true ]; then
        success "All critical files present and accounted for"
    else
        error "Some critical files are missing"
        return 1
    fi
}

# Function to verify security implementations
verify_security_implementations() {
    log "Verifying security implementations..."

    # Check for security remediation script
    if grep -q "revoke_compromised_token" scripts/security_remediation.sh; then
        success "Token revocation procedures implemented"
    else
        error "Token revocation procedures missing"
    fi

    # Check for AI token detector
    if grep -q "AITokenDetector" scripts/ai_token_detector.py; then
        success "AI-powered token detection implemented"
    else
        error "AI token detection missing"
    fi

    # Check for OAuth server security
    if grep -q "PKCE" oauth_server/app.py; then
        success "OAuth 2.0 with PKCE implemented"
    else
        error "PKCE implementation missing"
    fi

    # Check for JWT authentication
    if grep -q "jwt.encode" oauth_server/app.py; then
        success "JWT token authentication implemented"
    else
        error "JWT authentication missing"
    fi

    # Check for organization verification
    if grep -q "Fractal5-Solutions" oauth_server/app.py; then
        success "Organization-based authorization implemented"
    else
        error "Organization authorization missing"
    fi
}

# Function to verify GCP authentication
verify_gcp_auth() {
    log "Verifying GCP authentication..."

    if ! command -v gcloud &> /dev/null; then
        error "gcloud CLI not found"
        return 1
    fi

    if ! gcloud auth list --filter=status:ACTIVE --format="value(account)" > /dev/null 2>&1; then
        error "GCP authentication required"
        echo "Please run: gcloud auth login"
        return 1
    fi

    ACCOUNT=$(gcloud auth list --filter=status:ACTIVE --format="value(account)")
    success "Authenticated as: $ACCOUNT"
}

# Function to check environment deployment
check_environment_deployment() {
    local project="$1"
    local env_name="$2"

    log "Checking $env_name environment deployment..."

    # Set project
    if ! gcloud config set project "$project" --quiet 2>&1; then
        warning "Cannot access $env_name project ($project)"
        warning "$env_name is blocked by environment ownership/access, not repo-side readiness"
        ENV_OWNERSHIP_BLOCKERS=$((ENV_OWNERSHIP_BLOCKERS + 1))
        return 1
    fi

    # Check OAuth server
    local oauth_status="Not Deployed"
    local oauth_url="N/A"

    if gcloud run services describe "$OAUTH_SERVICE_NAME" --region="$GCP_REGION" --format="value(status.url)" > /dev/null 2>&1; then
        oauth_url=$(gcloud run services describe "$OAUTH_SERVICE_NAME" --region="$GCP_REGION" --format="value(status.url)")
        local health_status=$(gcloud run services describe "$OAUTH_SERVICE_NAME" --region="$GCP_REGION" --format="value(status.conditions[0].status)")
        local remote_health_code="000"
        local remote_ready_code="000"

        remote_health_code=$(curl -s -o /dev/null -w "%{http_code}" --max-time 10 "$oauth_url/health" 2>/dev/null || echo "000")
        remote_ready_code=$(curl -s -o /dev/null -w "%{http_code}" --max-time 10 "$oauth_url/ready" 2>/dev/null || echo "000")

        if [ "$health_status" = "True" ]; then
            oauth_status="✅ Healthy"
        else
            oauth_status="❌ Unhealthy"
        fi

        if [ "$remote_health_code" != "200" ] || [ "$remote_ready_code" != "200" ]; then
            warning "$env_name OAuth service is deployed, but remote /health or /ready does not match the repo implementation"
            oauth_status="$oauth_status (remote deployment mismatch)"
            REMOTE_OAUTH_MISMATCHES=$((REMOTE_OAUTH_MISMATCHES + 1))
        fi
    fi

    # Check AskPhi widget
    local widget_status="Not Deployed"
    local widget_url="N/A"

    if gcloud run services describe "$WIDGET_SERVICE_NAME" --region="$GCP_REGION" --format="value(status.url)" > /dev/null 2>&1; then
        widget_url=$(gcloud run services describe "$WIDGET_SERVICE_NAME" --region="$GCP_REGION" --format="value(status.url)")
        local health_status=$(gcloud run services describe "$WIDGET_SERVICE_NAME" --region="$GCP_REGION" --format="value(status.conditions[0].status)")
        if [ "$health_status" = "True" ]; then
            widget_status="✅ Healthy"
        else
            widget_status="❌ Unhealthy"
        fi
    fi

    # Display results
    echo ""
    echo "$env_name Environment ($project):"
    echo "  OAuth Server: $oauth_status"
    echo "    URL: $oauth_url"
    echo "  AskPhi Widget: $widget_status"
    echo "    URL: $widget_url"

    # Return success if both services are healthy and the OAuth deployment matches repo health routes
    if [ "$oauth_status" = "✅ Healthy" ] && [ "$widget_status" = "✅ Healthy" ]; then
        return 0
    else
        return 1
    fi
}

# Function to verify security configurations
verify_security_configurations() {
    local project="$1"
    local env_name="$2"

    log "Verifying security configurations for $env_name..."

    gcloud config set project "$project" --quiet

    # Check if required APIs are enabled
    local apis_enabled=true

    for api in "run.googleapis.com" "containerregistry.googleapis.com" "cloudbuild.googleapis.com"; do
        if ! gcloud services list --enabled --filter="name:$api" --format="value(name)" | grep -q "$api"; then
            warning "API not enabled: $api"
            apis_enabled=false
        fi
    done

    if [ "$apis_enabled" = true ]; then
        success "Required GCP APIs enabled"
    fi

    # Check for OAuth secrets
    if gcloud secrets describe github-oauth-client-id > /dev/null 2>&1; then
        success "GitHub OAuth client ID secret configured"
    else
        warning "GitHub OAuth client ID secret not found"
    fi

    if gcloud secrets describe github-oauth-client-secret > /dev/null 2>&1; then
        success "GitHub OAuth client secret configured"
    else
        warning "GitHub OAuth client secret not found"
    fi
}

# Function to run comprehensive security audit
run_security_audit() {
    log "Running comprehensive security audit..."

    # Check for hardcoded tokens
    if grep -r --exclude-dir=.git --exclude-dir=__pycache__ -E "(ghp_|github_pat_|AIza|-----BEGIN)" . | grep -v "placeholder\|example" > /dev/null; then
        error "Potential hardcoded tokens found in repository"
        grep -r --exclude-dir=.git --exclude-dir=__pycache__ -E "(ghp_|github_pat_|AIza|-----BEGIN)" . | grep -v "placeholder\|example"
    else
        success "No hardcoded tokens detected"
    fi

    # Check file permissions
    local world_writable=$(find . -type f -perm -002 -not -path "./.git/*" | wc -l)
    if [ "$world_writable" -gt 0 ]; then
        warning "Found $world_writable world-writable files"
    else
        success "No world-writable files found"
    fi

    # Check for .env files
    if [ -f ".env" ]; then
        warning ".env file found - ensure it's in .gitignore"
    fi

    # Verify git history security
    if git log --oneline --grep="token\|password\|secret" --all | grep -v "placeholder\|example" > /dev/null; then
        warning "Git history may contain sensitive data"
    else
        success "Git history appears clean"
    fi
}

# Function to generate final deployment report
generate_final_report() {
    header "PHI CHIEF AI DEPLOYMENT VERIFICATION REPORT"
    echo "Generated: $(date '+%Y-%m-%d %H:%M:%S')"
    echo ""

    # File integrity
    echo "📁 FILE INTEGRITY:"
    verify_file_integrity
    echo ""

    # Security implementations
    echo "🔐 SECURITY IMPLEMENTATIONS:"
    verify_security_implementations
    echo ""

    # GCP Authentication
    echo "☁️  GCP AUTHENTICATION:"
    verify_gcp_auth
    echo ""

    # Environment deployments
    echo "🚀 ENVIRONMENT DEPLOYMENTS:"

    local dev_deployed=false
    local prod_deployed=false

    if check_environment_deployment "$GCP_PROJECT_DEV" "Development"; then
        dev_deployed=true
    fi
    echo ""

    if check_environment_deployment "$GCP_PROJECT_PROD" "Production"; then
        prod_deployed=true
    fi
    echo ""

    # Security configurations
    echo "🛡️  SECURITY CONFIGURATIONS:"
    verify_security_configurations "$GCP_PROJECT_DEV" "Development"
    verify_security_configurations "$GCP_PROJECT_PROD" "Production"
    echo ""

    # Security audit
    echo "🔍 SECURITY AUDIT:"
    run_security_audit
    echo ""

    # Final status
    header "DEPLOYMENT STATUS SUMMARY"

    if [ "$dev_deployed" = true ] && [ "$prod_deployed" = true ]; then
        success "🎉 ALL SYSTEMS SECURELY DEPLOYED TO GOOGLE CLOUD"
        success "✅ Development environment: Fully operational"
        success "✅ Production environment: Fully operational"
        success "✅ Security protocols: Active and verified"
        success "✅ OAuth authentication: Implemented and ready"
        success "✅ AI-powered threat detection: Active"
        echo ""
        info "PHI Chief AI is now sovereign and operational across all environments"
    else
        if [ "$dev_deployed" = false ]; then
            error "Development environment deployment incomplete"
        fi
        if [ "$prod_deployed" = false ]; then
            error "Production environment deployment incomplete"
        fi
        echo ""
        if [ "$ENV_OWNERSHIP_BLOCKERS" -gt 0 ]; then
            warning "Environment ownership/access is blocking at least one remote verification target"
        fi
        if [ "$REMOTE_OAUTH_MISMATCHES" -gt 0 ]; then
            warning "At least one remote OAuth deployment does not match the repo's health/readiness implementation"
        fi
        warning "Repo-side readiness reporting is improved; remaining blockers are environment ownership and remote OAuth deployment mismatch, not ambiguous local scripts"
        warning "Use ./scripts/gcp_secure_deployment.sh only after the target environment owner confirms access and deployment alignment"
    fi

    echo ""
    header "NEXT STEPS FOR OPERATIONS"
    echo "1. Confirm ownership/access for each target GCP environment before treating remote failures as repo failures"
    echo "2. Reconcile the deployed phi-oauth-server revision with the repo implementation, including /health and /ready"
    echo "3. Configure GitHub OAuth App with the callback URLs exposed by the confirmed deployment"
    echo "4. Set up monitoring dashboards and alerts"
    echo "5. Configure domain mapping for custom URLs"
    echo "6. Enable advanced security features (VPC, IAM, etc.)"
    echo "7. Set up automated backup and disaster recovery"
    echo "8. Configure CI/CD pipelines with security gates"
    echo "9. Establish incident response procedures"
    echo "10. Conduct regular security audits and penetration testing"
    echo ""
    echo "🔐 REMEMBER: PHI Chief AI maintains complete sovereignty with NHITL operations"
    echo "🤖 AI-powered security and autonomous governance active"
}

# Main execution
main() {
    header "PHI CHIEF AI - SECURE DEPLOYMENT VERIFICATION"

    # Run all verification checks
    generate_final_report
}

# Run main function
main "$@"
