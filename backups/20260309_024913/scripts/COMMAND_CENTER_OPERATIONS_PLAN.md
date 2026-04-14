# 🎯 PHI Command Center - System Activation & Operations Plan

**Generated:** March 1, 2026
**Target Platform:** Google Cloud Platform
**Projects:** dominion-os-1-0-main, dominion-core-prod
**Mode:** Autonomous Operations with Full Monitoring

---

## 📋 Executive Summary

This operations plan provides a comprehensive strategy for activating, monitoring, and maintaining your Dominion OS and SaaS Suite command center ecosystem running on Google Cloud. The system is designed for autonomous operation with minimal manual intervention.

### 🏗️ Architecture Overview

**Two-Environment Strategy:** Development/Staging + Production Split
**Purpose:** Risk containment, security isolation, compliance readiness
**Detailed Analysis:** See [GCP_ARCHITECTURE_ANALYSIS.md](../GCP_ARCHITECTURE_ANALYSIS.md)
**Visual Diagram:** See [GCP_ARCHITECTURE_DIAGRAM.md](../GCP_ARCHITECTURE_DIAGRAM.md)

| Environment | Project ID | Services | Purpose | SLO Target |
|-------------|------------|----------|---------|------------|
| **DEV/STAGING** | dominion-os-1-0-main | 9 | Testing, validation, ops tools | 95%+ |
| **PRODUCTION** | dominion-core-prod | 13 | Customer-facing, revenue | 99.9% |

✅ **Recommendation:** MAINTAIN current split (industry best practice)
⚠️ **Risk:** Consolidation would violate compliance and increase failure blast radius

---

## 🚀 Phase 1: Initial Activation

### Step 1: Run Full System Activation

Execute the master activation script to verify and start all systems:

```bash
cd /workspaces/dominion-os-demo-build/scripts
chmod +x phi_command_center_activation.sh
./phi_command_center_activation.sh
```

**What it does:**
- ✅ Verifies GCP authentication
- ✅ Checks GitHub token and push capabilities
- ✅ Scans all Cloud Run services across both projects
- ✅ Validates AI Gateways, PHI UIs, and Core APIs
- ✅ Checks monitoring and SLO configuration
- ✅ Validates repository synchronization
- ✅ Generates comprehensive status report (JSON + console)

**Expected Duration:** 2-3 minutes

---

## 📊 Phase 2: Monitor System Health

### View Current Status

```bash
# Quick status overview
./start_all_systems.sh

# Detailed sovereign status
./phi_sovereign_status.sh

# SLO compliance check
./phi_slo_monitoring.sh
```

### Status Telemetry

All system metrics are stored in `telemetry/system_status.json`:

```json
{
  "timestamp": "2026-03-01T...",
  "status": "operational",
  "infrastructure": {
    "total_services": 22,
    "operational_services": 22,
    "health_percentage": 100
  },
  "components": {
    "ai_gateways": 2,
    "phi_uis": 1,
    "core_apis": 2
  }
}
```

---

## 🔄 Phase 3: Enable Autonomous Operations

### Option A: Repository Sync Monitoring (Recommended)

Keep repositories synchronized automatically:

```bash
# Start continuous repository sync in background
nohup ./phi_multi_repo_sync.sh > /tmp/phi_multi_sync.log 2>&1 &
echo $! > /tmp/phi_multi_sync.pid

# Check status
tail -f /tmp/phi_multi_sync.log
```

**Features:**
- Monitors all repositories every 60 seconds
- Automatically pushes pending commits (if Classic PAT available)
- Runs indefinitely until all repos are synced
- NHITL (No Human In The Loop) capable

### Option B: Keep-Alive Monitoring

Single repository monitoring with token awareness:

```bash
# Start keep-alive monitor
nohup ./phi_sovereign_keepalive.sh > /tmp/phi_keepalive.log 2>&1 &
echo $! > /tmp/phi_keepalive.pid
```

### Option C: Extended Autonomous Operations (8 hours)

Full autopilot mode with comprehensive monitoring:

```bash
# Start 8-hour autonomous operation cycle
nohup ./autonomous_overnight.sh > /tmp/autonomous_overnight.log 2>&1 &
echo $! > /tmp/autonomous_overnight.pid

# Monitor progress
tail -f /tmp/autonomous_overnight.log
```

**Includes:**
- Infrastructure health monitoring every 15 minutes
- Service availability tracking
- Incident logging
- Cost optimization checks
- Automatic recovery attempts

---

## 🛠️ Phase 4: Configure Monitoring (If Needed)

### Setup Cloud Monitoring

If your activation report shows `0` uptime checks:

```bash
# Create uptime checks for critical services
./setup_monitoring.sh

# Define notification channels
./setup_notification_channels.sh

# Configure SLOs (99.9% availability targets)
./setup_slos.sh

# Enable complete uptime monitoring
./setup_complete_uptime.sh
```

### Cost Monitoring

```bash
# Setup budget alerts and cost tracking
./setup_cost_monitoring.sh

# Enable cost optimization monitoring
nohup ./phi_cost_optimization.sh > /tmp/cost_opt.log 2>&1 &
```

---

## 🔐 Phase 5: Token Management

### Check Current Token Type

```bash
echo $GITHUB_TOKEN | cut -c1-4
```

**Token Types:**
- `ghp_` = Classic PAT (✅ Full git push capability)
- `gho_` = OAuth token (✅ Full git push capability)
- `ghu_` = Integration token (❌ Limited API-only access)

### Configure Classic PAT (for full autonomy)

```bash
# Method 1: Environment configuration
./configure_pat.sh ghp_YOUR_CLASSIC_PAT_HERE

# Method 2: Codespace secrets (persistent across rebuilds)
# Add GITHUB_TOKEN secret at:
# https://github.com/settings/codespaces
```

### Post-Restart Recovery

After Codespace restarts:

```bash
./phi_post_restart.sh
```

This script:
- Checks token type
- Shows pending commits
- Auto-pushes if Classic PAT detected
- Starts keep-alive monitor if needed

---

## 📈 Phase 6: Continuous Monitoring Dashboard

### Real-Time Service Status

#### Project 1: dominion-os-1-0-main

```bash
gcloud config set project dominion-os-1-0-main
gcloud run services list --region=us-central1
```

**Critical Services:**
- `dominion-ai-gateway` (SLO: 99.9% availability)
- `dominion-f5-gateway` (SLO: 99.9% availability)
- `dominion-os-1-0` (SLO: 99.9% availability)
- `dominion-phi-ui`

#### Project 2: dominion-core-prod

```bash
gcloud config set project dominion-core-prod
gcloud run services list --region=us-central1
```

**Critical Services:**
- `dominion-api` (SLO: 99.9% availability)
- `dominion-os` (SLO: 99.9% availability)
- Core APIs and backend services

### Monitoring Queries

```bash
# Check specific service health
gcloud run services describe SERVICE_NAME \
  --project PROJECT_NAME \
  --region us-central1 \
  --format="value(status.conditions[0].status)"

# List all operational services
gcloud run services list \
  --format="table(metadata.name, status.conditions[0].status)"

# Get service URLs
gcloud run services list \
  --format="value(status.url)"
```

---

## 🎛️ Phase 7: Operations Commands Reference

### Startup & Validation

| Command | Purpose | Duration |
|---------|---------|----------|
| `./phi_command_center_activation.sh` | Full system activation & validation | 2-3 min |
| `./start_all_systems.sh` | Quick health check | 30 sec |
| `./phi_sovereign_status.sh` | Comprehensive status report | 1 min |

### Monitoring & Compliance

| Command | Purpose | Frequency |
|---------|---------|-----------|
| `./phi_slo_monitoring.sh` | SLO compliance check | Weekly |
| `./phi_cost_optimization.sh` | Cost analysis | Daily |
| `./setup_monitoring.sh` | Configure uptime checks | Once |

### Repository Management

| Command | Purpose | Mode |
|---------|---------|------|
| `./phi_multi_repo_sync.sh` | Multi-repo sync | Continuous |
| `./phi_sovereign_keepalive.sh` | Single repo monitor | Continuous |
| `./push_tier2.sh` | Manual push | On-demand |

### Autonomous Operations

| Command | Purpose | Duration |
|---------|---------|----------|
| `./autonomous_overnight.sh` | Full autopilot | 8 hours |
| `./phi_post_restart.sh` | Post-restart recovery | 30 sec |

---

## 🔧 Troubleshooting Guide

### Issue: Services showing as degraded

**Diagnosis:**
```bash
gcloud run services describe SERVICE_NAME \
  --region us-central1 \
  --format="yaml(status)"
```

**Common Causes:**
1. Cold start (service scaling from zero)
2. Deployment in progress
3. Configuration error
4. Quota exceeded

**Resolution:**
```bash
# Force new revision deployment
gcloud run deploy SERVICE_NAME --image=IMAGE_URL

# Check logs
gcloud logging read "resource.type=cloud_run_revision" \
  --limit 50 --format json
```

### Issue: Cannot push to repository

**Diagnosis:**
```bash
echo $GITHUB_TOKEN | cut -c1-4
# If shows 'ghu_', you have integration token
```

**Resolution:**
1. Create Classic PAT: https://github.com/settings/tokens
2. Grant `repo` and `workflow` scopes
3. Configure: `./configure_pat.sh ghp_YOUR_TOKEN`
4. Or add to Codespace secrets for persistence

### Issue: Monitoring not showing data

**Diagnosis:**
```bash
gcloud monitoring uptime list --project=dominion-os-1-0-main
# If empty, monitoring not configured
```

**Resolution:**
```bash
./setup_monitoring.sh
./setup_slos.sh
```

### Issue: High costs detected

**Diagnosis:**
```bash
gcloud billing accounts list
gcloud billing projects describe PROJECT_ID
```

**Resolution:**
```bash
# Enable cost monitoring
./setup_cost_monitoring.sh

# Run optimization analysis
./phi_cost_optimization.sh

# Check for unused services
gcloud run services list --format="value(metadata.name)" | \
  xargs -I {} gcloud run services describe {} --format="value(status.traffic[0].percent)"
```

---

## 📊 Success Criteria

### ✅ System is OPTIMAL when:

1. **Infrastructure Health**: ≥ 95% services operational
2. **SLO Compliance**: All critical services meeting 99.9% SLO
3. **Repository Sync**: 0 commits ahead (all synced)
4. **Monitoring**: Uptime checks configured for all critical services
5. **Autonomous Systems**: At least one monitoring script running
6. **Cost**: Within budget thresholds

### ⚠️  Action Required if:

1. **Infrastructure Health**: < 95%
   - Investigate degraded services immediately
   - Check recent deployments
   - Review error logs

2. **SLO Breach**: Any service below 99.9%
   - Run `./phi_slo_monitoring.sh` for details
   - Check Cloud Monitoring dashboards
   - Consider scaling adjustments

3. **Repository Drift**: > 10 commits ahead
   - Run `./phi_multi_repo_sync.sh`
   - Or configure Classic PAT for auto-sync

4. **Cost Anomaly**: > 20% budget increase
   - Run `./phi_cost_optimization.sh`
   - Review service traffic patterns
   - Consider resource optimization

---

## 🎯 Recommended Daily Routine

### Morning (Start of Business Day)

```bash
# 1. Run full activation to verify overnight operations
./phi_command_center_activation.sh

# 2. Review any incidents from overnight
cat telemetry/incidents.log

# 3. Check cost status
./phi_cost_optimization.sh
```

### During Business Hours

```bash
# Keep one monitoring script running
nohup ./phi_multi_repo_sync.sh > /tmp/sync.log 2>&1 &
```

### Evening (End of Business Day)

```bash
# 1. Quick status check
./phi_sovereign_status.sh

# 2. Optional: Start 8-hour autonomous operations
./autonomous_overnight.sh &

# 3. Review day's telemetry
cat telemetry/activation_*.log | tail -100
```

---

## 📁 Key Files & Directories

### Configuration
- `scripts/` - All operational scripts
- `telemetry/` - Logs and status reports
- `.git/` - Repository version control

### Status Files
- `telemetry/system_status.json` - Current system state
- `telemetry/activation_*.log` - Activation history
- `telemetry/overnight_health.log` - Overnight monitoring data
- `telemetry/incidents.log` - Incident tracking

### Control Files
- `telemetry/STOP_AUTONOMOUS` - Create this to stop autonomous operations
- `/tmp/phi_*.pid` - Process IDs of running monitors

---

## 🚀 Quick Start Checklist

- [ ] Run `./phi_command_center_activation.sh`
- [ ] Verify all services show as operational
- [ ] Check repository is synchronized (0 commits ahead)
- [ ] Start autonomous sync: `./phi_multi_repo_sync.sh &`
- [ ] Verify monitoring is configured
- [ ] Set up daily routine (morning check + evening review)
- [ ] Configure alerts and notification channels
- [ ] Test incident response procedures
- [ ] Document any custom configurations
- [ ] Schedule weekly SLO compliance reviews

---

## 📞 Support & Escalation

### Self-Service Diagnostics

1. Run activation script: `./phi_command_center_activation.sh`
2. Check status report: `telemetry/system_status.json`
3. Review logs: `telemetry/*.log`
4. Consult troubleshooting section above

### Escalation Path

1. **Level 1**: Service degradation < 95% health
2. **Level 2**: SLO breach on critical services
3. **Level 3**: Complete outage or data integrity issues

---

## 🎉 You're All Set!

Your Dominion OS Command Center is now ready for autonomous operations. The PHI AI system will handle continuous monitoring, synchronization, and health checks with minimal manual intervention.

**Next Step:** Run the activation script and watch your command center come online!

```bash
./phi_command_center_activation.sh
```

---

*Generated by PHI Chief AI - Autonomous Operations System*
*Last Updated: March 1, 2026*
