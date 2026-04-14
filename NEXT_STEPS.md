# 🚀 NEXT STEPS: Deploy on Docker Desktop Pro

**Current Status**: All configuration complete in Codespaces ✅  
**Next Environment**: Docker Desktop Pro (Local Machine)  
**Expected Time**: 15 minutes to full operational status

---

## 📋 Prerequisites Checklist

Before deploying, ensure you have:

- [ ] **Docker Desktop Pro** installed and running
  - Download: https://www.docker.com/products/docker-desktop
  - Minimum: 8 CPU cores, 16GB RAM, 50GB disk
  - **Optimal: 16 CPU cores, 48GB RAM, 100GB disk**

- [ ] **API Credentials** (at minimum, GitHub token):
  - [ ] GitHub Token: https://github.com/settings/tokens
    - Required scopes: `repo`, `read:org`, `read:user`, `workflow`
  - [ ] Atlassian API Token: https://id.atlassian.com/manage-profile/security/api-tokens (optional)
  - [ ] Stripe Secret Key: https://dashboard.stripe.com/apikeys (optional)
  - [ ] Figma API Token: https://www.figma.com/developers/api#access-tokens (optional)

- [ ] **Repository Cloned** locally:
  ```bash
  git clone https://github.com/Fractal5-Solutions/dominion-os-demo-build.git
  cd dominion-os-demo-build
  ```

---

## 🎯 FASTEST PATH: One-Command Deployment (15 minutes)

### Step 1: Configure Environment (5 minutes)

```bash
# Copy environment template
cp .env.mcp.template .env.mcp

# Edit with your API tokens
nano .env.mcp  # or use your preferred editor
```

**At minimum, set these variables:**
```bash
GITHUB_TOKEN=ghp_your_github_personal_access_token_here
ATLASSIAN_API_TOKEN=your_atlassian_token_here  # optional
STRIPE_SECRET_KEY=sk_test_your_stripe_key_here  # optional
```

### Step 2: Run Automated Deployment (10 minutes)

```bash
bash scripts/deploy_mcp_full.sh
```

**This script will automatically:**
1. ✅ Verify Docker Desktop Pro is running
2. ✅ Check system resources (CPU/RAM)
3. ✅ Create network and volumes
4. ✅ Pull all Docker images (may take 5-10 min first time)
5. ✅ Start all 9 MCP services
6. ✅ Run health checks
7. ✅ Calculate live ops score
8. ✅ Display access URLs

**Expected Output:**
```
═══════════════════════════════════════════════════════════════
  DOCKER DESKTOP PRO LIVE OPS ALIGNMENT SCORE
═══════════════════════════════════════════════════════════════

Final Score: 95/100

Status: ✅ EXCELLENT - Perfectly Operational

Category Breakdown:
  ✓ Docker Pro License: 10/10
  ✓ CPU Allocation: 10/10
  ✓ RAM Allocation: 10/10
  ✓ Services Running: 30/30
  ✓ Health Checks: 18/20
  ✓ Monitoring: 10/10
  ✓ Performance: 7/10

🎉 All systems operational!
```

---

## 🔧 ALTERNATIVE: Manual Step-by-Step Deployment

If you prefer manual control:

### Step 1: Verify Docker Desktop Pro
```bash
docker version
docker info | grep -i license
```

### Step 2: Create Network and Volumes
```bash
docker network create --driver bridge --subnet 172.28.0.0/16 mcp-network
docker volume create playwright-cache
docker volume create pylance-cache
docker volume create figma-cache
docker volume create prometheus-data
docker volume create grafana-data
```

### Step 3: Configure Environment
```bash
cp .env.mcp.template .env.mcp
nano .env.mcp  # Add your API tokens
```

### Step 4: Deploy Services
```bash
docker-compose -f docker-compose-mcp.yml pull
docker-compose -f docker-compose-mcp.yml up -d
```

### Step 5: Verify Deployment
```bash
# Wait 30 seconds for services to start
sleep 30

# Check status
docker-compose -f docker-compose-mcp.yml ps

# Run health check
bash scripts/mcp_health_check.sh

# Calculate score
bash scripts/calculate_docker_live_ops_score.sh
```

---

## 📊 Post-Deployment Verification

### Quick Verification (30 seconds)
```bash
bash scripts/calculate_docker_live_ops_score.sh
```

**Target Score**: 90-100/100 = Perfect

### Access Services

Open in your browser:

- **Monitoring Dashboards**:
  - Prometheus: http://localhost:9090
  - Grafana: http://localhost:3008 (login: admin/admin)

- **MCP Service Health Endpoints**:
  - Atlassian: http://localhost:3000/health
  - Figma: http://localhost:3001/health
  - Stripe: http://localhost:3002/health
  - GitHub: http://localhost:3003/health

---

## 🎛️ Daily Management Commands

Use the convenient management script:

```bash
# Show all available commands
bash scripts/mcp_manage.sh

# Common commands:
bash scripts/mcp_manage.sh status      # Check service status
bash scripts/mcp_manage.sh logs        # View live logs
bash scripts/mcp_manage.sh health      # Run health check
bash scripts/mcp_manage.sh score       # Calculate live ops score
bash scripts/mcp_manage.sh restart     # Restart all services
bash scripts/mcp_manage.sh stop        # Stop all services
bash scripts/mcp_manage.sh start       # Start all services
bash scripts/mcp_manage.sh urls        # Show access URLs
```

**Or use Docker Compose directly:**
```bash
# View logs
docker-compose -f docker-compose-mcp.yml logs -f

# Check status
docker-compose -f docker-compose-mcp.yml ps

# Restart a specific service
docker-compose -f docker-compose-mcp.yml restart mcp-github

# View resource usage
docker stats
```

---

## 🔍 Troubleshooting

### Services Not Starting

**Check logs:**
```bash
docker-compose -f docker-compose-mcp.yml logs [service-name]
```

**Common issues:**
- **Missing API tokens**: Edit `.env.mcp` and add required tokens
- **Port conflicts**: Stop other services using ports 3000-3008, 9090
- **Insufficient resources**: Increase Docker Desktop resources in Settings
- **Network issues**: Recreate network with `docker network rm mcp-network && docker network create mcp-network`

### Health Checks Failing

**Wait longer:**
```bash
# Services need 30-60 seconds to fully initialize
sleep 60
bash scripts/mcp_health_check.sh
```

**Check individual service:**
```bash
curl http://localhost:3000/health
curl http://localhost:9090/-/healthy
```

### Low Score (< 90/100)

**View detailed recommendations:**
```bash
bash scripts/calculate_docker_live_ops_score.sh
# Script will show specific improvements needed
```

**Common fixes:**
- Increase Docker Desktop CPU allocation (Settings → Resources → CPUs)
- Increase Docker Desktop RAM allocation (Settings → Resources → Memory)
- Restart unhealthy services: `bash scripts/mcp_manage.sh restart`

### Complete Reset

**Clean restart (keeps data):**
```bash
bash scripts/mcp_manage.sh clean
bash scripts/deploy_mcp_full.sh
```

**Full reset (deletes all data):**
```bash
bash scripts/mcp_manage.sh clean-all
bash scripts/deploy_mcp_full.sh
```

---

## 📈 Expected Results on Docker Desktop Pro

### System Configuration

| Resource | Minimum | Optimal | Your System |
|----------|---------|---------|-------------|
| CPU Cores | 8 | 16+ | ___ |
| RAM | 16GB | 48GB+ | ___ |
| Disk Space | 50GB | 100GB+ | ___ |

### Service Status (Target: 9/9)

- [ ] mcp-atlassian (port 3000)
- [ ] mcp-figma (port 3001)
- [ ] mcp-stripe (port 3002)
- [ ] mcp-github (port 3003)
- [ ] mcp-playwright (port 3004)
- [ ] mcp-chrome (port 3005)
- [ ] mcp-pylance (port 3007)
- [ ] prometheus (port 9090)
- [ ] grafana (port 3008)

### Live Ops Score Breakdown

| Category | Points | Expected |
|----------|--------|----------|
| Docker Pro License | 10 | ✅ 10/10 |
| CPU Allocation | 10 | ✅ 10/10 |
| RAM Allocation | 10 | ✅ 10/10 |
| MCP Services | 30 | ✅ 30/30 |
| Health Checks | 20 | ✅ 18-20/20 |
| Monitoring | 10 | ✅ 10/10 |
| Performance | 10 | ✅ 8-10/10 |
| **TOTAL** | **100** | **✅ 90-100/100** |

---

## 🔄 Continuous Operations

### Daily Verification (30 seconds)
```bash
bash scripts/calculate_docker_live_ops_score.sh
```

### Weekly Health Check (2 minutes)
```bash
bash scripts/mcp_health_check.sh
```

### Monthly Full Verification (45 minutes)
```bash
# Follow complete verification plan
cat AI_PLAN_DOCKER_DESKTOP_PRO_VERIFICATION.md
```

### Monitoring Setup

**Configure Grafana Dashboards:**
1. Open http://localhost:3008
2. Login: admin/admin (change password on first login)
3. Add Prometheus datasource:
   - URL: http://prometheus:9090
   - Access: Server (default)
4. Import dashboards for MCP services

**Key Metrics to Monitor:**
- Container health status
- CPU/Memory usage per service
- API request rates
- Error rates
- Response times

---

## 🎉 Success Criteria

You've successfully deployed when:

- ✅ Score: 90-100/100 (Excellent)
- ✅ All 9 services showing "Up" status
- ✅ All health endpoints responding
- ✅ Prometheus collecting metrics
- ✅ Grafana accessible
- ✅ No containers in crash loop

---

## 📞 Quick Reference

### Essential Files
```
dominion-os-demo-build/
├── .env.mcp                    # Your API credentials (edit this!)
├── docker-compose-mcp.yml      # Service orchestration
├── prometheus.yml              # Monitoring config
├── scripts/
│   ├── deploy_mcp_full.sh     # Full automated deployment
│   ├── mcp_manage.sh          # Daily management
│   ├── mcp_health_check.sh    # Health verification
│   └── calculate_docker_live_ops_score.sh  # Scoring
└── AI_PLAN_DOCKER_DESKTOP_PRO_VERIFICATION.md  # Full plan
```

### Key Commands Cheat Sheet
```bash
# Deploy everything
bash scripts/deploy_mcp_full.sh

# Quick score check
bash scripts/calculate_docker_live_ops_score.sh

# Service management
bash scripts/mcp_manage.sh [command]

# View logs
docker-compose -f docker-compose-mcp.yml logs -f

# Restart services
docker-compose -f docker-compose-mcp.yml restart
```

---

## 🎯 Current vs Target State

### Current State (Codespaces)
```
✅ PHI Services:     4/4  operational (100/100)
🔶 MCP Services:     0/9  configured (ready)
🔶 Verification:     Framework complete
```

### Target State (Docker Desktop Pro)
```
✅ PHI Services:     4/4  operational (100/100)
✅ MCP Services:     9/9  operational (90-100/100)
✅ Verification:     Automated daily checks
✅ Total Excellence: 190-200/200
```

---

## 📞 Support Resources

- **Configuration Guide**: [MCP_DOCKER_DESKTOP_PRO_CONFIGURATION.md](MCP_DOCKER_DESKTOP_PRO_CONFIGURATION.md)
- **Verification Plan**: [AI_PLAN_DOCKER_DESKTOP_PRO_VERIFICATION.md](AI_PLAN_DOCKER_DESKTOP_PRO_VERIFICATION.md)
- **Quick Start**: [DOCKER_VERIFICATION_QUICK_START.md](DOCKER_VERIFICATION_QUICK_START.md)
- **Execution Report**: [EXECUTION_STATUS_REPORT.md](EXECUTION_STATUS_REPORT.md)

---

**Ready to Deploy?** Run: `bash scripts/deploy_mcp_full.sh`

**Questions?** Review the comprehensive guides above or check the troubleshooting section.

**Target Achievement**: 90-100/100 score = Perfect operational status! 🎯
