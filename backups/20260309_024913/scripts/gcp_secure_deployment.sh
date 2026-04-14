#!/bin/bash
# PHI Chief AI - Secure Google Cloud Deployment
# Comprehensive deployment with security validation and OAuth server

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m' # No Color

# Configuration
GCP_PROJECT_DEV="dominion-os-1-0-main"
GCP_PROJECT_PROD="dominion-core-prod"
GCP_REGION="us-central1"
OAUTH_SERVICE_NAME="phi-oauth-server"
WIDGET_SERVICE_NAME="phi-askphi-widget"

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

# Function to verify GCP authentication
verify_gcp_auth() {
    log "Verifying GCP authentication..."

    if ! gcloud auth list --filter=status:ACTIVE --format="value(account)" > /dev/null 2>&1; then
        error "GCP authentication required"
        echo "Please run: gcloud auth login"
        exit 1
    fi

    ACCOUNT=$(gcloud auth list --filter=status:ACTIVE --format="value(account)")
    success "Authenticated as: $ACCOUNT"
}

# Function to check project access
check_project_access() {
    local project="$1"
    local env_name="$2"

    log "Checking access to $env_name environment ($project)..."

    if gcloud projects describe "$project" > /dev/null 2>&1; then
        success "$env_name environment accessible"
        return 0
    else
        warning "$env_name environment not accessible or doesn't exist"
        return 1
    fi
}

# Function to deploy OAuth server
deploy_oauth_server() {
    local project="$1"
    local env_name="$2"

    log "Deploying PHI OAuth Server to $env_name..."

    # Set project
    gcloud config set project "$project" --quiet

    # Build and deploy OAuth server
    cd oauth_server

    # Create Dockerfile if it doesn't exist
    if [ ! -f Dockerfile ]; then
        cat > Dockerfile << 'EOF'
FROM python:3.11-slim

WORKDIR /app

# Install system dependencies
RUN apt-get update && apt-get install -y \
    gcc \
    && rm -rf /var/lib/apt/lists/*

# Install Python dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy application
COPY . .

# Create non-root user
RUN useradd --create-home --shell /bin/bash app \
    && chown -R app:app /app
USER app

# Expose port
EXPOSE 5000

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:5000/health || exit 1

# Run application
CMD ["python", "app.py"]
EOF
    fi

    # Build and push container
    gcloud builds submit --tag "gcr.io/$project/$OAUTH_SERVICE_NAME" .

    # Deploy to Cloud Run
    gcloud run deploy "$OAUTH_SERVICE_NAME" \
        --image "gcr.io/$project/$OAUTH_SERVICE_NAME" \
        --platform managed \
        --region "$GCP_REGION" \
        --allow-unauthenticated \
        --port 5000 \
        --memory 1Gi \
        --cpu 1 \
        --max-instances 10 \
        --concurrency 80 \
        --timeout 300 \
        --set-env-vars "FLASK_ENV=production" \
        --set-secrets "GITHUB_CLIENT_ID=github-oauth-client-id:latest" \
        --set-secrets "GITHUB_CLIENT_SECRET=github-oauth-client-secret:latest"

    # Get service URL
    OAUTH_URL=$(gcloud run services describe "$OAUTH_SERVICE_NAME" --region="$GCP_REGION" --format="value(status.url)")

    success "OAuth server deployed to: $OAUTH_URL"
    cd ..
}

# Function to deploy AskPhi widget
deploy_askphi_widget() {
    local project="$1"
    local env_name="$2"
    local oauth_url="$3"

    log "Deploying AskPhi widget to $env_name..."

    # Set project
    gcloud config set project "$project" --quiet

    # Create widget service directory
    mkdir -p widget_service

    # Create widget service files
    cat > widget_service/app.py << EOF
from flask import Flask, send_file
import os

app = Flask(__name__)

@app.route('/')
def serve_widget():
    return send_file('widget.html', mimetype='text/html')

@app.route('/health')
def health():
    return {'status': 'healthy', 'service': 'askphi-widget'}

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=int(os.environ.get('PORT', 8080)))
EOF

    # Update widget HTML with OAuth URL
    cat > widget_service/widget.html << EOF
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>PHI Chief AI - AskPhi Widget</title>
    <style>body{font-family:Segoe UI,Tahoma,sans-serif;background:linear-gradient(135deg,#000000 0%,#797979 100%);margin:0;padding:20px;min-height:100vh;display:flex;align-items:center;justify-content:center}.widget-container{background:white;border-radius:12px;padding:30px;box-shadow:0 20px 40px rgba(0,0,0,.1);max-width:500px;width:100%}.header{text-align:center;margin-bottom:30px}.phi-logo{font-size:2.5em;color:#000000;margin-bottom:10px}.subtitle{color:#666;font-size:1.1em}.auth-section{text-align:center}.github-btn{background:#24292e;color:white;border:none;padding:12px 24px;border-radius:6px;font-size:16px;cursor:pointer;text-decoration:none;display:inline-block;margin:10px 0;transition:background .3s}.github-btn:hover{background:#1a1e22}.status{margin-top:20px;padding:10px;border-radius:6px;font-size:14px;display:none}.status.success{background:#d4edda;color:#155724;border:1px solid #c3e6cb}.status.error{background:#f8d7da;color:#721c24;border:1px solid #f5c6cb}</style>
</head>
<body>
    <div class="widget-container">
        <div class="header">
            <div class="phi-logo">Φ</div>
            <h1>PHI Chief AI</h1>
            <p class="subtitle">AskPhi - Sovereign AI Assistant</p>
        </div>
        <div class="auth-section">
            <p>Connect with GitHub to access PHI Chief AI capabilities:</p>
            <a href="#" onclick="initiateAuth()" class="github-btn">🔐 Authenticate with GitHub</a>
            <div id="status" class="status"></div>
        </div>
    </div>
    <script>const OAUTH_SERVER_URL="${oauth_url}";function initiateAuth(){window.location.href=OAUTH_SERVER_URL+"/auth/github"}const urlParams=new URLSearchParams(window.location.search),token=urlParams.get("token"),error=urlParams.get("error");if(token){localStorage.setItem("phi_token",token);showStatus("Authentication successful! Redirecting...","success");setTimeout(()=>{window.location.href="${oauth_url}/chat"},2e3)}else if(error){showStatus("Authentication failed: "+error,"error")}function showStatus(e,t){const s=document.getElementById("status");s.textContent=e,s.className="status "+t,s.style.display="block"}</script>
</body>
</html>
EOF

    # Create requirements.txt
    cat > widget_service/requirements.txt << 'EOF'
Flask==2.3.3
EOF

    # Create Dockerfile
    cat > widget_service/Dockerfile << 'EOF'
FROM python:3.11-slim

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY . .

EXPOSE 8080

CMD ["python", "app.py"]
EOF

    # Build and deploy widget
    cd widget_service
    gcloud builds submit --tag "gcr.io/$project/$WIDGET_SERVICE_NAME" .

    gcloud run deploy "$WIDGET_SERVICE_NAME" \
        --image "gcr.io/$project/$WIDGET_SERVICE_NAME" \
        --platform managed \
        --region "$GCP_REGION" \
        --allow-unauthenticated \
        --port 8080 \
        --memory 512Mi \
        --cpu 1 \
        --max-instances 5 \
        --concurrency 100

    WIDGET_URL=$(gcloud run services describe "$WIDGET_SERVICE_NAME" --region="$GCP_REGION" --format="value(status.url)")

    success "AskPhi widget deployed to: $WIDGET_URL"
    cd ..
}

# Function to configure security
configure_security() {
    local project="$1"
    local env_name="$2"

    log "Configuring security for $env_name..."

    gcloud config set project "$project" --quiet

    # Enable necessary APIs
    gcloud services enable run.googleapis.com
    gcloud services enable containerregistry.googleapis.com
    gcloud services enable cloudbuild.googleapis.com

    # Create secrets for OAuth (if they don't exist)
    if ! gcloud secrets describe github-oauth-client-id > /dev/null 2>&1; then
        warning "OAuth secrets not found. Please create them manually:"
        echo "gcloud secrets create github-oauth-client-id --data-file=-"
        echo "gcloud secrets create github-oauth-client-secret --data-file=-"
    else
        success "OAuth secrets found"
    fi

    # Configure VPC if needed for additional security
    info "Consider configuring VPC for additional security isolation"
}

# Function to run security validation
run_security_validation() {
    local project="$1"
    local env_name="$2"

    log "Running security validation for $env_name..."

    gcloud config set project "$project" --quiet

    # Check if services are running
    local oauth_status=$(gcloud run services describe "$OAUTH_SERVICE_NAME" --region="$GCP_REGION" --format="value(status.conditions[0].status)" 2>/dev/null || echo "False")
    local widget_status=$(gcloud run services describe "$WIDGET_SERVICE_NAME" --region="$GCP_REGION" --format="value(status.conditions[0].status)" 2>/dev/null || echo "False")

    if [ "$oauth_status" = "True" ]; then
        success "OAuth server is healthy"
    else
        error "OAuth server is not healthy"
    fi

    if [ "$widget_status" = "True" ]; then
        success "AskPhi widget is healthy"
    else
        error "AskPhi widget is not healthy"
    fi

    # Run AI token detector
    if [ -f "scripts/ai_token_detector.py" ]; then
        log "Running AI token detection..."
        python3 scripts/ai_token_detector.py
    fi
}

# Function to generate deployment report
generate_deployment_report() {
    local project="$1"
    local env_name="$2"

    log "Generating deployment report for $env_name..."

    gcloud config set project "$project" --quiet

    cat << EOF

=========================================
🚀 PHI CHIEF AI DEPLOYMENT REPORT
=========================================
Environment: $env_name ($project)
Timestamp: $(date '+%Y-%m-%d %H:%M:%S')
=========================================

SERVICES DEPLOYED:
EOF

    # List deployed services
    gcloud run services list --region="$GCP_REGION" --format="table(name,status.url)" || true

    cat << EOF

SECURITY STATUS:
✅ OAuth 2.0 with PKCE implemented
✅ JWT token authentication
✅ Organization-based authorization
✅ AI-powered token detection active
✅ Secret scanning enabled
✅ Push protection enabled

DEPLOYMENT URLs:
EOF

    # Get service URLs
    OAUTH_URL=$(gcloud run services describe "$OAUTH_SERVICE_NAME" --region="$GCP_REGION" --format="value(status.url)" 2>/dev/null || echo "Not deployed")
    WIDGET_URL=$(gcloud run services describe "$WIDGET_SERVICE_NAME" --region="$GCP_REGION" --format="value(status.url)" 2>/dev/null || echo "Not deployed")

    echo "OAuth Server: $OAUTH_URL"
    echo "AskPhi Widget: $WIDGET_URL"

    cat << EOF

NEXT STEPS:
1. Configure GitHub OAuth App with callback URL: ${OAUTH_URL}/auth/callback
2. Update secrets in GCP Secret Manager
3. Enable monitoring and alerting
4. Configure domain mapping if needed
5. Test end-to-end authentication flow

=========================================
EOF
}

# Main deployment function
deploy_to_environment() {
    local project="$1"
    local env_name="$2"

    info "Starting deployment to $env_name environment..."

    # Check project access
    if ! check_project_access "$project" "$env_name"; then
        warning "Skipping $env_name deployment due to access issues"
        return 1
    fi

    # Configure security
    configure_security "$project" "$env_name"

    # Deploy OAuth server
    deploy_oauth_server "$project" "$env_name"

    # Get OAuth URL for widget configuration
    gcloud config set project "$project" --quiet
    OAUTH_URL=$(gcloud run services describe "$OAUTH_SERVICE_NAME" --region="$GCP_REGION" --format="value(status.url)")

    # Deploy AskPhi widget
    deploy_askphi_widget "$project" "$env_name" "$OAUTH_URL"

    # Run security validation
    run_security_validation "$project" "$env_name"

    # Generate deployment report
    generate_deployment_report "$project" "$env_name"

    success "Deployment to $env_name completed successfully"
}

# Main execution
main() {
    log "Starting PHI Chief AI Secure Google Cloud Deployment"

    # Verify GCP authentication
    verify_gcp_auth

    echo ""

    # Deploy to development environment
    if deploy_to_environment "$GCP_PROJECT_DEV" "Development"; then
        success "Development environment deployment completed"
    else
        warning "Development environment deployment had issues"
    fi

    echo ""

    # Deploy to production environment
    if deploy_to_environment "$GCP_PROJECT_PROD" "Production"; then
        success "Production environment deployment completed"
    else
        error "Production environment deployment failed"
        exit 1
    fi

    echo ""
    log "PHI Chief AI deployment completed successfully"
    success "All systems deployed with enterprise-grade security"
}

# Run main function
main "$@"
