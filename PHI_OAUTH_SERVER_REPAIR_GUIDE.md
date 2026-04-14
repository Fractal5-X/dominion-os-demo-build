# PHI OAuth Server Repair Guide

## Executive Summary

**Current Status**: 16 of 17 services operational (94.1% health rate)
**Issue**: `phi-oauth-server` is deployed but marked unhealthy (Status: False)
**Root Cause**: Missing `/health` endpoint and Flask development server (non-production)
**Solution Status**: ✅ Code fixes complete, ⏳ Deployment blocked by permissions

---

## Problem Analysis

### Service Health Check Failure

The Cloud Run health checks are failing for `phi-oauth-server` because:

1. **Missing Health Endpoint**: The service returns `404 Not Found` on `GET /health`
2. **Flask Dev Server**: Using Flask's built-in development server instead of production WSGI server
3. **Port Configuration**: Hardcoded port 5000 instead of Cloud Run's dynamic `${PORT}`

### Evidence from Logs

```
WARNING: This is a development server. Do not use it in a production deployment.
Use a production WSGI server instead.

GET /health HTTP/1.1 404
```

---

## Fixes Applied

### 1. Added Health Endpoint (`app.py`)

```python
@app.route("/health")
def health():
    """Health check endpoint for Cloud Run"""
    return jsonify({
        "status": "healthy",
        "service": "phi-oauth-server",
        "timestamp": datetime.utcnow().isoformat()
    }), 200
```

### 2. Added Production WSGI Server (`requirements.txt`)

```
gunicorn==21.2.0
```

### 3. Updated Dockerfile

**Before**:
```dockerfile
CMD ["python", "app.py"]
HEALTHCHECK --interval=30s --timeout=10s --start-period=40s --retries=3 \
  CMD curl -f http://localhost:5000/health || exit 1
```

**After**:
```dockerfile
CMD exec gunicorn --bind :${PORT:-8080} --workers 2 --threads 4 --worker-class gthread --timeout 300 --keep-alive 5 --log-level info --access-logfile - --error-logfile - app:app

HEALTHCHECK --interval=30s --timeout=10s --start-period=40s --retries=3 \
  CMD curl -f http://localhost:${PORT:-8080}/health || exit 1
```

---

## Deployment Issue

### Permission Errors Encountered

```
ERROR: (gcloud.run.deploy) PERMISSION_DENIED: Permission 'run.services.get' denied on resource 'namespaces/dominion-core-prod/services/phi-oauth-server'

ERROR: (gcloud.builds.submit) The user is forbidden from accessing the bucket [dominion-core-prod_cloudbuild].
Please check your organization's policy or if the user has the 'serviceusage.services.use' permission.
```

### Current User

- Email: `matthewburbidge@fractal5solutions.com`
- Missing Permissions:
  - `run.services.get`
  - `run.services.update`
  - Cloud Build bucket access
  - `serviceusage.services.use`

---

## Solution Options

### Option 1: Grant Required IAM Roles (Recommended)

**Required Roles**:
```bash
# Option A: Developer role (recommended)
gcloud projects add-iam-policy-binding dominion-core-prod \
    --member="user:matthewburbidge@fractal5solutions.com" \
    --role="roles/run.developer"

# Option B: Full admin (if broader access needed)
gcloud projects add-iam-policy-binding dominion-core-prod \
    --member="user:matthewburbidge@fractal5solutions.com" \
    --role="roles/run.admin"

# Cloud Build access
gcloud projects add-iam-policy-binding dominion-core-prod \
    --member="user:matthewburbidge@fractal5solutions.com" \
    --role="roles/cloudbuild.builds.editor"
```

**Then deploy**:
```bash
./phi_oauth_server_repair.sh
```

### Option 2: Deploy via GCP Console UI

1. Navigate to [Cloud Run Console](https://console.cloud.google.com/run?project=dominion-core-prod)
2. Click on `phi-oauth-server` service
3. Click **EDIT & DEPLOY NEW REVISION**
4. Click **Upload Code**:
   - Upload contents of `/workspaces/dominion-os-demo-build/oauth_server/`
   - Files: `app.py`, `Dockerfile`, `requirements.txt`, etc.
5. Ensure these settings:
   - **Container port**: 8080
   - **Memory**: 2 GiB
   - **CPU**: 1
   - **Min instances**: 1
   - **Max instances**: 10
   - **Concurrency**: 100
   - **Timeout**: 300s
   - **Execution environment**: gen2
   - **Service account**: `dominion-runtime@dominion-core-prod.iam.gserviceaccount.com`
6. Click **DEPLOY**

### Option 3: Use Different Service Account

**Create deployment service account with sufficient permissions**:

```bash
# Create service account
gcloud iam service-accounts create phi-deployer \
    --display-name="PHI OAuth Server Deployer" \
    --project=dominion-core-prod

# Grant Cloud Run Admin role
gcloud projects add-iam-policy-binding dominion-core-prod \
    --member="serviceAccount:phi-deployer@dominion-core-prod.iam.gserviceaccount.com" \
    --role="roles/run.admin"

# Grant Cloud Build Editor role
gcloud projects add-iam-policy-binding dominion-core-prod \
    --member="serviceAccount:phi-deployer@dominion-core-prod.iam.gserviceaccount.com" \
    --role="roles/cloudbuild.builds.editor"

# Grant Storage Admin (for Cloud Build bucket)
gcloud projects add-iam-policy-binding dominion-core-prod \
    --member="serviceAccount:phi-deployer@dominion-core-prod.iam.gserviceaccount.com" \
    --role="roles/storage.admin"

# Impersonate service account for deployment
gcloud run deploy phi-oauth-server \
    --source=./oauth_server \
    --region=us-central1 \
    --project=dominion-core-prod \
    --impersonate-service-account=phi-deployer@dominion-core-prod.iam.gserviceaccount.com
```

### Option 4: Manual Docker Build & Push

**If you have Docker access but not Cloud Build**:

```bash
cd /workspaces/dominion-os-demo-build/oauth_server

# Build locally
docker build -t phi-oauth-server:latest .

# Tag for Artifact Registry
docker tag phi-oauth-server:latest \
    us-central1-docker.pkg.dev/dominion-core-prod/dominion-artifacts/phi-oauth-server:latest

# Authenticate Docker
gcloud auth configure-docker us-central1-docker.pkg.dev

# Push to registry
docker push us-central1-docker.pkg.dev/dominion-core-prod/dominion-artifacts/phi-oauth-server:latest

# Deploy the image
gcloud run deploy phi-oauth-server \
    --image=us-central1-docker.pkg.dev/dominion-core-prod/dominion-artifacts/phi-oauth-server:latest \
    --region=us-central1 \
    --project=dominion-core-prod \
    --platform=managed \
    --allow-unauthenticated \
    --service-account=dominion-runtime@dominion-core-prod.iam.gserviceaccount.com \
    --memory=2Gi \
    --cpu=1 \
    --min-instances=1 \
    --max-instances=10
```

---

## Verification Commands

### After Deployment

**1. Check Service Status**:
```bash
gcloud run services describe phi-oauth-server \
    --region=us-central1 \
    --project=dominion-core-prod \
    --format='table(status.url,status.conditions[0].status)'
```

**Expected Output**:
```
URL                                                STATUS
https://phi-oauth-server-reduwyf2ra-uc.a.run.app  True
```

**2. Test Health Endpoint**:
```bash
curl -s https://phi-oauth-server-reduwyf2ra-uc.a.run.app/health | jq
```

**Expected Response**:
```json
{
  "status": "healthy",
  "service": "phi-oauth-server",
  "timestamp": "2026-03-03T10:30:45.123456"
}
```

**3. Verify All Services**:
```bash
gcloud run services list \
    --region=us-central1 \
    --project=dominion-core-prod \
    --format='table(name,status.conditions[0].status)' \
    | grep -c "True"
```

**Expected**: `17` (100% operational)

**4. Check Service Logs**:
```bash
gcloud logging read \
    "resource.type=cloud_run_revision AND resource.labels.service_name=phi-oauth-server" \
    --limit=20 \
    --project=dominion-core-prod \
    --format="table(timestamp,severity,textPayload)"
```

**Expected**: Should see gunicorn startup logs, successful health checks, no Flask dev server warnings

---

## Files Modified

### `/workspaces/dominion-os-demo-build/oauth_server/app.py`
- ✅ Added `/health` endpoint at line ~45
- Returns JSON with status, service name, timestamp

### `/workspaces/dominion-os-demo-build/oauth_server/requirements.txt`
- ✅ Added `gunicorn==21.2.0`

### `/workspaces/dominion-os-demo-build/oauth_server/Dockerfile`
- ✅ Changed CMD to use gunicorn
- ✅ Updated HEALTHCHECK to use dynamic port
- Configuration: 2 workers, 4 threads, gthread worker-class, 300s timeout

---

## Production Readiness Checklist

### Current Status (94.1%)

- [x] **16 Services Operational**: ✅
  - dominion-gateway: True
  - dominion-api: True
  - dominion-demo-service: True
  - phi-command-center: True
  - phi-cost-optimizer: True
  - phi-leverage-engine: True
  - phi-relationship-mapper: True
  - phi-apollo-crm: True
  - phi-bims-integration: True
  - phi-notification-service: True
  - phi-monitoring-dashboard: True
  - phi-slo-monitor: True
  - phi-security-scanner: True
  - phi-deployment-orchestrator: True
  - phi-github-oauth: True
  - phi-askphi-widget: True

- [ ] **phi-oauth-server**: ⏳ Pending deployment (code fixed)

### After Repair (100%)

- [x] All 17 services operational
- [x] Production WSGI servers (gunicorn)
- [x] Health endpoints responding
- [x] Cloud Armor WAF active
- [x] Binary Authorization enforced
- [x] Secret Manager configured (12 secrets)
- [x] Monitoring & alerting operational
- [x] Auto-scaling configured (1-100 instances)
- [x] Non-root containers
- [x] Service accounts with least privilege

---

## Support Information

### Service Details

- **Name**: phi-oauth-server
- **Region**: us-central1
- **Project**: dominion-core-prod (447370233441)
- **URL**: https://phi-oauth-server-reduwyf2ra-uc.a.run.app
- **Service Account**: dominion-runtime@dominion-core-prod.iam.gserviceaccount.com
- **Source Code**: `/workspaces/dominion-os-demo-build/oauth_server/`

### Deployment Script

**Automated repair script created**: [phi_oauth_server_repair.sh](phi_oauth_server_repair.sh)

**Usage**:
```bash
./phi_oauth_server_repair.sh
```

This script:
1. Verifies all fixes are applied
2. Deploys to Cloud Run with proper configuration
3. Tests health endpoint
4. Reports service status

### GCP Console Links

- [Cloud Run Services](https://console.cloud.google.com/run?project=dominion-core-prod)
- [OAuth Service Details](https://console.cloud.google.com/run/detail/us-central1/phi-oauth-server?project=dominion-core-prod)
- [Service Logs](https://console.cloud.google.com/logs/query;query=resource.type%3D%22cloud_run_revision%22%0Aresource.labels.service_name%3D%22phi-oauth-server%22?project=dominion-core-prod)
- [IAM & Admin](https://console.cloud.google.com/iam-admin/iam?project=dominion-core-prod)
- [Artifact Registry](https://console.cloud.google.com/artifacts/docker/dominion-core-prod/us-central1/dominion-artifacts?project=dominion-core-prod)

---

## Technical Notes

### Gunicorn Configuration

```
--bind :${PORT:-8080}           # Dynamic port from Cloud Run
--workers 2                     # Process workers
--threads 4                     # Threads per worker (8 concurrent requests)
--worker-class gthread          # Threaded worker for I/O-bound tasks
--timeout 300                   # Request timeout (5 minutes)
--keep-alive 5                  # Connection keep-alive
--log-level info                # Logging verbosity
--access-logfile -              # Log to stdout
--error-logfile -               # Errors to stdout
app:app                         # Flask application object
```

### Health Check Behavior

- **Interval**: 30 seconds
- **Timeout**: 10 seconds
- **Start Period**: 40 seconds (grace period for startup)
- **Retries**: 3 failures before marking unhealthy
- **Endpoint**: `GET /health`
- **Expected Response**: HTTP 200 with JSON payload

### OAuth Flow

The service provides OAuth 2.0 with PKCE for:
- GitHub authentication
- AskPhi AI widget integration
- JWT token management
- CORS-enabled API

**Main Routes**:
- `GET /` - AskPhi widget HTML
- `GET /auth/github` - Initiate OAuth flow
- `GET /auth/callback` - OAuth callback handler
- `POST /api/chat` - AI chat endpoint
- `GET /health` - Health check (NEW)

---

## Next Steps

1. **Choose one of the deployment options above** (Option 1 recommended)
2. **Execute deployment** using automated script or manual method
3. **Verify service health** with provided verification commands
4. **Update production readiness document** to reflect 17/17 operational status
5. **Monitor service** for 24 hours to ensure stability

## Success Criteria

✅ **Service Status**: True (healthy)
✅ **Health Endpoint**: Returns HTTP 200
✅ **Production Server**: Gunicorn (not Flask dev server)
✅ **Logs**: No warnings about development server
✅ **Overall Health Rate**: 17/17 services (100%)

---

**Document Version**: 1.0
**Date**: 2026-03-03
**Status**: Ready for deployment (code complete, permissions required)
