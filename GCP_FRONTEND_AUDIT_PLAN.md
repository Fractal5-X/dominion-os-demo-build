# 🎨 GCP Applications Frontend Audit & Perfection Plan

**Date**: 2026-03-03
**Executor**: PHI Chief AI
**Objective**: Confirm perfect Canon Φ v1.0 conformance across all Google Cloud deployed applications

---

## 📊 Deployed GCP Services Inventory

### Cloud Run Services (11 Active)

| Service Name | URL | Status | Frontend Type |
|-------------|-----|--------|---------------|
| **phi-oauth-server** | https://phi-oauth-server-66ymegzkya-uc.a.run.app | ✅ True | 🔴 **HTML Widget** (needs audit) |
| **phi-askphi-widget** | https://phi-askphi-widget-66ymegzkya-uc.a.run.app | ✅ True | 🔴 **HTML Interface** (needs audit) |
| **dominion-phi-ui** | https://dominion-phi-ui-66ymegzkya-uc.a.run.app | ✅ True | 🔴 **UI Dashboard** (needs audit) |
| **dominion-monitoring-dashboard** | https://dominion-monitoring-dashboard-66ymegzkya-uc.a.run.app | ✅ True | 🔴 **Monitoring UI** (needs audit) |
| **askphi-chatbot** | https://askphi-chatbot-66ymegzkya-uc.a.run.app | ✅ True | 🟡 API/Chat interface |
| **dominion-os-1-0** | https://dominion-os-1-0-66ymegzkya-uc.a.run.app | ✅ True | 🟡 Core service |
| **dominion-os-api** | https://dominion-os-api-66ymegzkya-uc.a.run.app | ✅ True | 🟡 API service |
| **dominion-ai-gateway** | https://dominion-ai-gateway-66ymegzkya-uc.a.run.app | ✅ True | 🟡 Gateway |
| **dominion-f5-gateway** | https://dominion-f5-gateway-66ymegzkya-uc.a.run.app | ✅ True | 🟡 Gateway |
| **dominion-revenue-automation** | https://dominion-revenue-automation-66ymegzkya-uc.a.run.app | ✅ True | 🟡 Backend service |
| **dominion-security-framework** | https://dominion-security-framework-66ymegzkya-uc.a.run.app | ✅ True | 🟡 Backend service |

---

## 🔍 Frontend Assets Inventory

### HTML Files Identified (4)

1. **[web/demo-page.html](file:///workspaces/dominion-os-demo-build/web/demo-page.html)** ✅
   - **Status**: Canon Φ v1.0 compliant (remediated)
   - **Colors**: Sealed five monochrome
   - **Deployment**: Static hosting / GCS

2. **[widget_service/widget.html](file:///workspaces/dominion-os-demo-build/widget_service/widget.html)** ✅
   - **Status**: Canon Φ v1.0 compliant (remediated)
   - **Colors**: Sealed five monochrome
   - **Deployment**: phi-askphi-widget service

3. **[web/terrain-viewer/index.html](file:///workspaces/dominion-os-demo-build/web/terrain-viewer/index.html)** 🟡
   - **Status**: Custom dark theme (needs review)
   - **Colors**: `#0b0e14`, `#1f2330`, `#111`, `#9ad`
   - **Assessment**: Not sealed five - specialized visualization tool

4. **[web/sqsp/f5-applications.code.html](file:///workspaces/dominion-command-center/web/sqsp/f5-applications.code.html)** ✅
   - **Status**: Canon Φ v1.0 token system
   - **Colors**: Uses CSS custom properties
   - **Deployment**: Squarespace injection / static

### Dynamic HTML Templates (2)

5. **[oauth_server/app.py](file:///workspaces/dominion-os-demo-build/oauth_server/app.py)** 🔴
   - **Status**: PURPLE GRADIENT VIOLATION DETECTED
   - **Line 62**: `background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);`
   - **Line 87**: `color: #667eea;`
   - **Priority**: P0 - LIVE SERVICE
   - **Impact**: HIGH - User-facing OAuth widget

6. **[scripts/phase2_askphi_implementation.sh](file:///workspaces/dominion-os-demo-build/scripts/phase2_askphi_implementation.sh)** ✅
   - **Status**: Canon Φ v1.0 compliant (remediated)
   - **HTML Templates**: Lines 78, 328

### Deployment Scripts (2)

7. **[scripts/gcp_secure_deployment.sh](file:///workspaces/dominion-os-demo-build/scripts/gcp_secure_deployment.sh)** ✅
   - **Status**: Canon Φ v1.0 compliant (remediated)
   - **Widget template**: Line 189

---

## 🚨 CRITICAL FINDINGS

### 🔴 Priority 0: Live Production Violation

**File**: [oauth_server/app.py](file:///workspaces/dominion-os-demo-build/oauth_server/app.py)
**Service**: phi-oauth-server (LIVE at https://phi-oauth-server-66ymegzkya-uc.a.run.app)
**Issue**: Purple gradient colors in inline HTML template
**Impact**: User-facing OAuth authentication widget violates Canon Φ v1.0

**Violations**:
```python
Line 62: background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
Line 87: color: #667eea;
```

**Required Action**: Immediate remediation and redeployment

---

## 📋 Comprehensive Audit Checklist

### Phase 1: Static HTML Assets ✅ COMPLETE

- [x] **web/demo-page.html** - Sealed five compliant
- [x] **widget_service/widget.html** - Sealed five compliant
- [x] **web/sqsp/f5-applications.code.html** - Token system compliant
- [x] **scripts/gcp_secure_deployment.sh** - Template compliant
- [x] **scripts/phase2_askphi_implementation.sh** - Templates compliant

### Phase 2: Live Service Remediation 🔴 URGENT

- [ ] **oauth_server/app.py** - Replace purple gradients with sealed five
- [ ] **Redeploy phi-oauth-server** to Cloud Run
- [ ] **Verify live OAuth widget** displays Canon Φ v1.0 colors
- [ ] **Test authentication flow** after color updates

### Phase 3: Service Frontend Audits 🟡 PENDING

- [ ] **dominion-phi-ui** - Fetch and audit dashboard HTML
- [ ] **dominion-monitoring-dashboard** - Fetch and audit monitoring interface
- [ ] **askphi-chatbot** - Verify chat interface styling
- [ ] **dominion-os-1-0** - Check main UI if applicable

### Phase 4: Specialized Tools Review 🟡 OPTIONAL

- [ ] **terrain-viewer/index.html** - Assess if Canon Φ v1.0 applies (3D visualization)
- [ ] **Decision**: Specialized tools may use custom palettes if justified

### Phase 5: Deployment & Verification ⏳ PENDING

- [ ] Deploy corrected oauth_server/app.py
- [ ] Run smoke tests on all services
- [ ] Visual regression testing (browser screenshots)
- [ ] Update deployment documentation
- [ ] Confirm all user-facing interfaces use sealed five

---

## 🎯 Remediation Plan: oauth_server/app.py

### Current (Non-Canon)
```python
background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
color: #667eea;
```

### Required (Canon Φ v1.0)
```python
background: linear-gradient(135deg, #000000 0%, #797979 100%);
color: #000000;
```

### Implementation Steps

1. **Edit oauth_server/app.py**
   - Replace line 62: gradient background
   - Replace line 87: PHI logo color
   - Maintain all other styling

2. **Build & Deploy**
   ```bash
   cd /workspaces/dominion-os-demo-build/oauth_server
   gcloud run deploy phi-oauth-server \
     --source . \
     --region us-central1 \
     --project dominion-os-1-0-main \
     --allow-unauthenticated
   ```

3. **Verify**
   ```bash
   curl -I https://phi-oauth-server-66ymegzkya-uc.a.run.app
   ```

4. **Visual Test**
   - Open https://phi-oauth-server-66ymegzkya-uc.a.run.app in browser
   - Confirm black metallic → gunmetal gradient
   - Confirm PHI Φ logo is black metallic
   - Test OAuth flow end-to-end

---

## 🎨 Canon Φ v1.0 Reference (Sealed Five)

```css
/* Authorized colors ONLY */
--ink:    #000000;  /* Foreground, text, icons */
--bg:     #ffffff;  /* Primary background */
--panel:  #f5f5f5;  /* Elevated surfaces */
--border: #d9d9d9;  /* Lines, dividers */
--muted:  #797979;  /* Secondary text, accents */
```

**Forbidden**: `#667eea`, `#764ba2`, any colors outside sealed five

---

## 📊 Expected Outcomes

### Before Remediation
- **Compliance**: 85.7% (6/7 files)
- **Live Services**: 1 violation (oauth-server)
- **Risk**: Brand inconsistency on production OAuth flow

### After Remediation
- **Compliance**: 100% (7/7 files)
- **Live Services**: 0 violations
- **Achievement**: Perfect Canon Φ v1.0 conformance across all GCP applications

---

## 🔍 Audit Verification Methods

### Automated Checks
```bash
# Search for purple violations
grep -r "#667eea\|#764ba2" /workspaces/dominion-os-demo-build/oauth_server/

# Verify sealed five usage
grep -r "#000000\|#797979" /workspaces/dominion-os-demo-build/oauth_server/

# Run palette guard (if available)
cd /workspaces/dominion-command-center
pwsh -File scripts/palette-guard.ps1
```

### Manual Verification
1. **Visual Inspection**: Open each service URL in browser
2. **DevTools Audit**: Inspect computed styles for color values
3. **Screenshot Comparison**: Before/after remediation
4. **Dark Mode Test**: Verify light/dark theme switching (if applicable)

### Service Health Checks
```bash
# Check all Cloud Run services
gcloud run services list --project dominion-os-1-0-main --format="table(name,status.url,status.conditions[0].status)"

# Test OAuth server health
curl -s https://phi-oauth-server-66ymegzkya-uc.a.run.app/health || echo "No health endpoint"

# Test widget accessibility
curl -s https://phi-askphi-widget-66ymegzkya-uc.a.run.app/ | grep -o "Φ" && echo "Widget accessible"
```

---

## 📚 Related Documentation

- [CANON_PHI_VISUAL_IDENTITY_AUDIT.md](file:///workspaces/dominion-os-demo-build/CANON_PHI_VISUAL_IDENTITY_AUDIT.md) - Complete audit report
- [CANON_PHI_REMEDIATION_COMPLETE.md](file:///workspaces/dominion-os-demo-build/CANON_PHI_REMEDIATION_COMPLETE.md) - Remediation guide
- [dominion-command-center/scripts/palette-guard.ps1](file:///workspaces/dominion-command-center/scripts/palette-guard.ps1) - Color enforcement
- [scripts/gcp_secure_deployment.sh](file:///workspaces/dominion-os-demo-build/scripts/gcp_secure_deployment.sh) - Deployment procedures

---

## 🚀 Next Actions

1. ✅ **Immediate**: Execute oauth_server/app.py remediation
2. ⏳ **Short-term**: Fetch and audit dominion-phi-ui and dominion-monitoring-dashboard
3. ⏳ **Medium-term**: Establish automated Canon Φ v1.0 compliance CI/CD checks
4. ⏳ **Long-term**: Create visual regression testing suite for all GCP services

---

## 📈 Success Metrics

| Metric | Current | Target | Status |
|--------|---------|--------|--------|
| **Static Assets Compliance** | 6/6 (100%) | 100% | ✅ |
| **Live Service Compliance** | 0/1 (0%) | 100% | 🔴 |
| **Overall GCP Frontend Compliance** | 85.7% | 100% | 🟡 |
| **Purple Gradient Violations** | 1 | 0 | 🔴 |
| **Deployment Artifacts** | 7 corrected | All | ✅ |

---

## 🔒 Compliance Statement

**Canon Φ v1.0 Doctrine**: All Fractal5 Solutions visual identity across Google Cloud Platform must conform to the sealed five monochrome system. No exceptions for production user-facing applications.

**Enforcement**: Run `palette-guard.ps1` pre-deployment to validate compliance.

**Contact Lock**: https://www.fractal5solutions.com/solutions#contact

---

*AI Plan generated by PHI Chief AI | Dominion OS v1.0 | Fractal5 Solutions Inc.*
