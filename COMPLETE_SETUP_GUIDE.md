# 🚀 PHI CHIEF AI - COMPLETE OPTIMAL SETUP GUIDE

## 📋 SETUP CHECKLIST - EXECUTE IN ORDER

**Status**: 🔄 **IN PROGRESS**
**Date**: March 2, 2026
**Environment**: Production (dominion-core-prod)

---

## ✅ COMPLETED TASKS

### **1. System Deployment** ✅
- All 16 PHI Chief AI services deployed to Google Cloud
- AskPhi widget operational at production URL
- OAuth server deployed (awaiting configuration)

### **2. Infrastructure Optimization** ✅
- VS Code environment fully optimized
- Dependencies updated across all systems
- Performance configurations applied

---

## 🔄 CURRENT TASKS (EXECUTE NOW)

### **3. GitHub OAuth Setup** 🔄

#### **Step 3.1: Create GitHub OAuth App**
Navigate to: `https://github.com/settings/applications/new`

**Required Settings:**
```
Application name: PHI Chief AI AskPhi
Homepage URL: https://phi-askphi-widget-447370233441.us-central1.run.app
Authorization callback URL: https://phi-oauth-server-447370233441.us-central1.run.app/auth/callback
```

**After creating the app:**
- ✅ Copy the **Client ID**
- ✅ Copy the **Client Secret**

#### **Step 3.2: Create GCP Secrets**
Execute these commands with your actual credentials:

```bash
# Create Client ID secret
echo -n 'YOUR_CLIENT_ID_HERE' | gcloud secrets create github-oauth-client-id \
  --project dominion-core-prod --data-file=-

# Create Client Secret secret
echo -n 'YOUR_CLIENT_SECRET_HERE' | gcloud secrets create github-oauth-client-secret \
  --project dominion-core-prod --data-file=-
```

#### **Step 3.3: Grant Permissions**
```bash
# Grant access to Client ID
gcloud secrets add-iam-policy-binding github-oauth-client-id \
  --member="serviceAccount:447370233441-compute@developer.gserviceaccount.com" \
  --role="roles/secretmanager.secretAccessor" \
  --project dominion-core-prod

# Grant access to Client Secret
gcloud secrets add-iam-policy-binding github-oauth-client-secret \
  --member="serviceAccount:447370233441-compute@developer.gserviceaccount.com" \
  --role="roles/secretmanager.secretAccessor" \
  --project dominion-core-prod
```

#### **Step 3.4: Redeploy OAuth Server**
```bash
gcloud run services update phi-oauth-server \
  --project dominion-core-prod \
  --region us-central1 \
  --set-secrets "GITHUB_CLIENT_ID=github-oauth-client-id:latest" \
  --set-secrets "GITHUB_CLIENT_SECRET=github-oauth-client-secret:latest"
```

---

## ⏳ PENDING TASKS (AFTER OAUTH)

### **4. Monitoring Setup** ⏳
```bash
# Enable monitoring APIs
gcloud services enable monitoring.googleapis.com --project dominion-core-prod
gcloud services enable logging.googleapis.com --project dominion-core-prod

# Create monitoring dashboard (script will be provided)
```

### **5. Automated Updates** ⏳
```bash
# Enable Cloud Scheduler
gcloud services enable cloudscheduler.googleapis.com --project dominion-core-prod

# Setup daily security scans and weekly updates
```

### **6. Performance Optimization** ⏳
```bash
# Optimize Cloud Run services
gcloud run services update phi-oauth-server --concurrency=100 --cpu=1 --memory=512Mi
gcloud run services update phi-askphi-widget --concurrency=100 --cpu=1 --memory=512Mi
```

### **7. Security Hardening** ⏳
```bash
# Enable advanced security services
gcloud services enable securitycenter.googleapis.com --project dominion-core-prod
gcloud services enable accesscontextmanager.googleapis.com --project dominion-core-prod
```

### **8. Final Health Check** ⏳
```bash
# Verify all systems are operational
bash /workspaces/dominion-command-center/scripts/live_ops_verify.sh
```

---

## 🎯 EXECUTION ORDER

1. **Create GitHub OAuth App** (Manual - 5 minutes)
2. **Run GCP Secret Commands** (Terminal - 2 minutes)
3. **Execute Monitoring Setup** (Automated - 3 minutes)
4. **Configure Automated Updates** (Automated - 2 minutes)
5. **Apply Performance Optimization** (Automated - 2 minutes)
6. **Enable Security Hardening** (Automated - 2 minutes)
7. **Run Final Health Check** (Automated - 1 minute)

---

## 🔗 IMPORTANT URLs

- **AskPhi Widget**: https://phi-askphi-widget-447370233441.us-central1.run.app
- **OAuth Server**: https://phi-oauth-server-447370233441.us-central1.run.app
- **GitHub OAuth Setup**: https://github.com/settings/applications/new

---

## 📞 SUPPORT

If you encounter any issues:
1. Check the terminal output for error messages
2. Verify all URLs are correct
3. Ensure GCP authentication is active
4. Review the OAuth deployment status report

---

## ✅ VERIFICATION STEPS

After completing OAuth setup:
- [ ] Widget loads without errors
- [ ] "Authenticate with GitHub" button appears
- [ ] OAuth flow redirects correctly
- [ ] Organization validation works
- [ ] Chat interface loads after authentication

---

**Ready to begin? Start with Step 3.1: Create the GitHub OAuth App!** 🔐

*Guide Generated: March 2, 2026*
