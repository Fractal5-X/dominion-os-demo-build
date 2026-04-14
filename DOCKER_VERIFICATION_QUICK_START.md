# QUICK START: Docker Desktop Pro Perfect Operational Verification
**5-Minute Quick Reference Card**

## 🎯 Objective
Systematically verify Docker Desktop Pro is perfectly operational and aligned with PHI live ops standards (target: 90-100/100 score).

---

## 🚀 FASTEST PATH TO VERIFICATION

### Option 1: Automated Score Calculator (30 seconds)
```bash
cd /workspaces/dominion-os-demo-build
bash scripts/calculate_docker_live_ops_score.sh
```

**Instant Results:**
- ✅ Overall score (0-100)
- ✅ Breakdown by category
- ✅ Specific recommendations
- ✅ Next actions

---

### Option 2: Full Health Check (2 minutes)
```bash
cd /workspaces/dominion-os-demo-build
bash scripts/mcp_health_check.sh
```

**Comprehensive Output:**
- All MCP services status
- Resource utilization
- Docker configuration
- Network & volumes
- Quick access URLs

---

### Option 3: Complete Verification Plan (45 minutes)
See full plan: [AI_PLAN_DOCKER_DESKTOP_PRO_VERIFICATION.md](AI_PLAN_DOCKER_DESKTOP_PRO_VERIFICATION.md)

**5 Phases:**
1. Pre-flight Checks (5 min)
2. MCP Deployment (15 min)
3. Live Ops Alignment (10 min)
4. Performance Validation (10 min)
5. Final Validation (5 min)

---

## 📊 SCORING SYSTEM

| Component | Points | Requirement |
|-----------|--------|-------------|
| **Docker Desktop Pro License** | 10 | Active Pro license |
| **CPU Allocation** | 10 | 16+ cores (min 8) |
| **Memory Allocation** | 10 | 48+ GB (min 16GB) |
| **MCP Services Running** | 30 | 9/9 containers up |
| **Health Checks Passing** | 20 | All endpoints respond |
| **Monitoring Operational** | 10 | Prometheus + Grafana |
| **Performance Metrics** | 10 | CPU < 50% avg |
| **TOTAL** | **100** | **90+ = Perfect** |

---

## ✅ SUCCESS CRITERIA

**90-100 Points**: ✅ EXCELLENT - Perfectly Operational  
**75-89 Points**: ✅ GOOD - Minor optimizations possible  
**50-74 Points**: ⚠️ FAIR - Needs attention  
**0-49 Points**: ❌ POOR - Critical issues  

---

## 🔧 COMMON QUICK FIXES

### If Services Not Running:
```bash
docker-compose -f docker-compose-mcp.yml up -d
```

### If Health Checks Failing:
```bash
docker-compose -f docker-compose-mcp.yml restart
docker-compose -f docker-compose-mcp.yml logs --tail=50
```

### If Resources Insufficient:
1. Open Docker Desktop
2. Settings → Resources
3. Set: 16 CPUs, 48GB RAM, 100GB Disk
4. Apply & Restart

### If Monitoring Down:
```bash
docker-compose -f docker-compose-mcp.yml restart prometheus grafana
```

---

## 📁 KEY FILES

| File | Purpose |
|------|---------|
| `AI_PLAN_DOCKER_DESKTOP_PRO_VERIFICATION.md` | Full 45-min verification plan |
| `scripts/calculate_docker_live_ops_score.sh` | Instant score calculator |
| `scripts/mcp_health_check.sh` | Comprehensive health check |
| `docker-compose-mcp.yml` | MCP services configuration |
| `.env.mcp.template` | Environment variables template |

---

## 🔗 SERVICE URLS (When Running)

- **Grafana Dashboard**: http://localhost:3008 (admin/admin)
- **Prometheus**: http://localhost:9090
- **Atlassian MCP**: http://localhost:3000
- **Figma MCP**: http://localhost:3001
- **Stripe MCP**: http://localhost:3002
- **GitHub MCP**: http://localhost:3003
- **Playwright MCP**: http://localhost:3004
- **Chrome MCP**: http://localhost:3005
- **Pylance MCP**: http://localhost:3007

---

## 🎯 EXECUTION FLOW

```
START
  ↓
Run: calculate_docker_live_ops_score.sh
  ↓
Score >= 90? ──YES→ ✅ DONE (Perfect!)
  ↓ NO
Review Recommendations
  ↓
Apply Quick Fixes
  ↓
Re-run Score Calculator
  ↓
Score >= 90? ──YES→ ✅ DONE
  ↓ NO
Run Full Verification Plan
  ↓
✅ DONE
```

---

## 🆘 TROUBLESHOOTING

### Docker Daemon Not Running
```bash
# Check Docker Desktop is running
docker info
# If fails, start Docker Desktop application
```

### Containers Won't Start
```bash
# Check logs
docker-compose -f docker-compose-mcp.yml logs [service-name]

# Remove and recreate
docker-compose -f docker-compose-mcp.yml down
docker-compose -f docker-compose-mcp.yml up -d
```

### Network Issues
```bash
# Recreate network
docker network rm mcp-network
docker network create mcp-network
docker-compose -f docker-compose-mcp.yml up -d
```

### Environment Variables Missing
```bash
# Copy template and edit
cp .env.mcp.template .env.mcp
nano .env.mcp  # Add your API tokens
```

---

## 📞 QUICK REFERENCE COMMANDS

### Status Check
```bash
docker ps --filter "name=mcp-"
```

### Resource Usage
```bash
docker stats --filter "name=mcp-"
```

### View All Logs
```bash
docker-compose -f docker-compose-mcp.yml logs -f
```

### Restart Everything
```bash
docker-compose -f docker-compose-mcp.yml restart
```

### Stop Everything
```bash
docker-compose -f docker-compose-mcp.yml down
```

### Clean Restart
```bash
docker-compose -f docker-compose-mcp.yml down -v
docker-compose -f docker-compose-mcp.yml up -d
```

---

## 🎓 ALIGNMENT WITH PHI STANDARDS

This verification aligns with established PHI live ops standards:
- ✅ 100/100 scoring methodology
- ✅ Comprehensive health checks
- ✅ Resource optimization focus
- ✅ Monitoring stack (Prometheus + Grafana)
- ✅ Automated verification scripts
- ✅ Clear documentation standards

---

## ⏱️ TIME ESTIMATES

| Action | Duration | When to Use |
|--------|----------|-------------|
| **Score Calculator** | 30 sec | Quick verification |
| **Health Check** | 2 min | Detailed status |
| **Full Verification** | 45 min | Initial setup or monthly audit |
| **Quick Fix** | 5-10 min | After score < 90 |

---

## 🎯 RECOMMENDED SCHEDULE

- **Daily**: Score calculator (30 sec)
- **Weekly**: Full health check (2 min)
- **Monthly**: Complete verification plan (45 min)
- **Quarterly**: Configuration audit & optimization

---

**Last Updated**: March 7, 2026  
**Version**: 1.0  
**Status**: ✅ READY FOR EXECUTION
