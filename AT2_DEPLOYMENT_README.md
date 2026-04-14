# PHI Sovereign Stack - AT2 Workstation Deployment

## 🎯 Quick Start (3 Commands)

```bash
git pull origin main
./deploy-desktop-pro.sh
./verify-deployment.sh
```

Then open: **http://localhost:5000** ✨

---

## 📋 System Requirements

### ✅ Your AT2 Hardware (Optimal Configuration)
- **CPU**: AMD Ryzen 5 7600X (6 cores, 12 threads @ 4.7GHz)
- **GPU**: NVIDIA RTX 4070 (12GB GDDR6X, CUDA 8.9)
- **RAM**: 32GB+ (16GB allocated to Docker Desktop Pro)
- **Storage**: 100GB+ free space (SSD recommended)
- **OS**: Windows 10/11 with WSL2 or Linux

### ✅ Software Pre-requisites
- **Docker Desktop Pro** (latest version)
- **NVIDIA Docker Runtime** (for GPU acceleration)
- **Git** (for pulling latest code)

---

## 🚀 Deployment Steps

### Step 1: Pull Latest Code
```bash
cd /path/to/dominion-os-demo-build
git pull origin main
```

### Step 2: Configure Environment (First Time Only)
The `.env` file is already created from template. Review and customize if needed:
```bash
nano .env
```

**Critical Settings:**
- `POSTGRES_PASSWORD`: Change from default `phi_sovereign_2025`
- `SECRET_KEY`: Generate unique value
- `GPU_ENABLED`: Set to `true` (already configured for RTX 4070)
- `CPU_CORES`: Set to `6` (matches your Ryzen 5 7600X)

### Step 3: Deploy Stack
```bash
./deploy-desktop-pro.sh
```

This automated script will:
1. ✓ Check Docker Desktop Pro is running
2. ✓ Validate compose file configuration
3. ✓ Pull latest container images
4. ✓ Build custom PHI images
5. ✓ Launch all services with GPU acceleration
6. ✓ Wait for health checks
7. ✓ Open PHI Dashboard in browser

**Expected Output:**
```
╔══════════════════════════════════════════════════════╗
║     PHI SOVEREIGN DESKTOP PRO DEPLOYMENT            ║
╚══════════════════════════════════════════════════════╝

[1/6] Checking Docker availability...
  ✓ Docker is running
  Docker Desktop 4.x.x

[2/6] Validating compose configuration...
  ✓ Configuration is valid

[3/6] Pulling container images...
  ✓ All images pulled successfully

[4/6] Building PHI services...
  ✓ Build completed

[5/6] Starting services...
  ✓ All services started

[6/6] Verifying service health...
  ✓ phi-sovereign-core is healthy
  ✓ phi-database is healthy
  ✓ phi-redis is healthy

╔══════════════════════════════════════════════════════╗
║           DEPLOYMENT SUCCESSFUL! 🎉                  ║
╚══════════════════════════════════════════════════════╝

🌐 PHI Dashboard: http://localhost:5000
📊 Grafana Metrics: http://localhost:3000
```

### Step 4: Verify Deployment
```bash
./verify-deployment.sh
```

This will check:
- ✅ All HTTP endpoints responding
- ✅ Database connections working
- ✅ Container health status
- ✅ GPU acceleration enabled

Expected verification outcomes:
- `0` exit code when all local and Docker-backed checks pass
- `0` exit code when local checks pass but Docker inspection is blocked by the current runtime
- non-zero exit code when any required service is down or unreachable

### Fully Provisioned Verification Checklist

Run this on the target workstation after Docker Desktop Pro is up and the stack has been deployed:

1. Confirm Docker is reachable:
   ```bash
   docker info
   docker compose -f docker-compose.desktop-pro.yml ps
   ```
2. Confirm local endpoints respond:
   ```bash
   curl -fsS http://localhost:5000 >/dev/null
   curl -fsS http://localhost:8080/health
   curl -fsS http://localhost:8081/health
   curl -fsS http://localhost:9090/-/ready
   curl -fsS http://localhost:3000/login >/dev/null
   ```
3. Confirm data services are reachable:
   ```bash
   nc -z localhost 5432
   nc -z localhost 6379
   ```
4. Run the verifier and review the readiness summary:
   ```bash
   ./verify-deployment.sh
   ```
5. If anything fails, inspect logs before retrying:
   ```bash
   docker compose -f docker-compose.desktop-pro.yml logs -f
   ```

---

## 🔧 Service Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    Docker Desktop Pro                       │
│                  (16GB RAM, 8 CPU Cores)                    │
└─────────────────────────────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────┐
│                   phi-bridge Network                        │
│                  (172.28.0.0/16, MTU 1500)                  │
└─────────────────────────────────────────────────────────────┘
                            │
        ┌───────────────────┼───────────────────┐
        ▼                   ▼                   ▼
┌────────────────┐  ┌────────────────┐  ┌────────────────┐
│  PHI Core      │  │  PostgreSQL 15 │  │   Redis 7      │
│  :5000         │  │  :5432         │  │   :6379        │
│  4 CPU, 4GB    │  │  2 CPU, 2GB    │  │   1 CPU, 1GB   │
│  GPU Accel ✓   │  │  Persistent    │  │   512MB Cache  │
└────────────────┘  └────────────────┘  └────────────────┘
        │                                       │
        ▼                                       ▼
┌────────────────┐                    ┌────────────────┐
│  OAuth Server  │                    │   Grafana      │
│  :8080         │                    │   :3000        │
│  2 CPU, 1GB    │                    │   1 CPU, 1GB   │
└────────────────┘                    └────────────────┘
        │
        ▼
┌────────────────┐
│  AskPHI Widget │
│  :8081         │
│  1 CPU, 512MB  │
└────────────────┘
```

---

## 📊 Resource Allocation

| Service | CPU Cores | RAM | Storage | GPU |
|---------|-----------|-----|---------|-----|
| PHI Core | 4 | 4GB | 10GB | RTX 4070 |
| PostgreSQL | 2 | 2GB | 5GB | - |
| Redis | 1 | 1GB (512MB cache) | 1GB | - |
| OAuth Server | 2 | 1GB | 1GB | - |
| AskPHI Widget | 1 | 512MB | 500MB | - |
| Prometheus | 2 | 2GB | 10GB (7-day retention) | - |
| Grafana | 1 | 1GB | 2GB | - |
| **Total** | **13/12** | **11.5GB/32GB** | **29.5GB** | **12GB** |

**Performance Optimizations:**
- GPU acceleration for AI/ML workloads
- Redis LRU caching with maxmemory-policy
- PostgreSQL shared_buffers tuned for 2GB RAM
- Prometheus 7-day retention with local storage
- Custom bridge network with MTU 1500
- Health checks with 30s intervals

---

## 🛠️ Management Commands

### View Running Services
```bash
docker compose -f docker-compose.desktop-pro.yml ps
```

### View Logs (All Services)
```bash
docker compose -f docker-compose.desktop-pro.yml logs -f
```

### View Logs (Specific Service)
```bash
docker compose -f docker-compose.desktop-pro.yml logs -f phi-sovereign-core
docker compose -f docker-compose.desktop-pro.yml logs -f phi-database
```

### Restart Services
```bash
docker compose -f docker-compose.desktop-pro.yml restart
```

### Stop All Services
```bash
docker compose -f docker-compose.desktop-pro.yml down
```

### Stop and Remove Volumes (Clean Slate)
```bash
docker compose -f docker-compose.desktop-pro.yml down -v
```

### Check Container Health
```bash
docker inspect --format='{{.State.Health.Status}}' phi-sovereign-core
```

### Check GPU Availability
```bash
docker run --rm --gpus all nvidia/cuda:12.2.0-base-ubuntu22.04 nvidia-smi
```

---

## 🌐 Service Endpoints

| Service | URL | Credentials |
|---------|-----|-------------|
| **PHI Dashboard** | http://localhost:5000 | - |
| **OAuth Server** | http://localhost:8080 | - |
| **AskPHI Widget** | http://localhost:8081 | - |
| **Grafana** | http://localhost:3000 | admin / sovereign_admin |
| **Prometheus** | http://localhost:9090 | - |
| **PostgreSQL** | localhost:5432 | postgres / (see .env) |
| **Redis** | localhost:6379 | - |

---

## 📈 Monitoring & Observability

### Grafana Dashboards
1. Navigate to http://localhost:3000
2. Login: `admin` / `sovereign_admin`
3. Pre-configured dashboards:
   - **PHI System Overview**: CPU, RAM, GPU metrics
   - **Database Performance**: PostgreSQL queries, connections
   - **Cache Performance**: Redis hit/miss rates
   - **Container Health**: Docker metrics

### Prometheus Metrics
- Navigate to http://localhost:9090
- Query examples:
  ```promql
  # CPU usage by container
  rate(container_cpu_usage_seconds_total[5m])

  # Memory usage
  container_memory_usage_bytes

  # HTTP request rate
  rate(phi_http_requests_total[5m])
  ```

### Health Checks
All services have automated health checks:
- **Interval**: 30 seconds
- **Timeout**: 10 seconds
- **Retries**: 3 attempts
- **Start Period**: 40 seconds

---

## 🐛 Troubleshooting

### Issue: Docker daemon not running
```bash
# Windows: Start Docker Desktop
# Linux: sudo systemctl start docker
```

### Issue: Port already in use
```bash
# Find process using port
lsof -i :5000
# or
netstat -ano | findstr :5000

# Kill process or change port in .env
```

### Issue: Services won't start
```bash
# Check logs
docker compose -f docker-compose.desktop-pro.yml logs

# Restart Docker Desktop
# Or restart Docker daemon: sudo systemctl restart docker
```

### Issue: GPU not detected
```bash
# Verify NVIDIA Docker runtime
docker run --rm --gpus all nvidia/cuda:12.2.0-base-ubuntu22.04 nvidia-smi

# If fails, install nvidia-docker2:
# https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/install-guide.html
```

### Issue: Database connection errors
```bash
# Check PostgreSQL logs
docker compose -f docker-compose.desktop-pro.yml logs phi-database

# Verify credentials in .env match docker-compose.desktop-pro.yml
grep POSTGRES .env

# Reset database
docker compose -f docker-compose.desktop-pro.yml down -v
docker compose -f docker-compose.desktop-pro.yml up -d
```

### Issue: Performance degradation
```bash
# Check resource usage
docker stats

# Increase Docker Desktop resources:
# Docker Desktop → Settings → Resources
# Recommended: 16GB RAM, 8 CPU cores

# Check disk space
docker system df
docker system prune -a  # Clean up unused images/containers
```

---

## 🔐 Security Checklist

- [ ] Changed default `POSTGRES_PASSWORD` in .env
- [ ] Generated unique `SECRET_KEY` in .env
- [ ] Changed Grafana admin password from default
- [ ] Reviewed firewall rules (ports 5000, 3000, 8080, 8081)
- [ ] Configured OAuth providers if using external auth
- [ ] Set `DEBUG=false` for production use
- [ ] Enabled HTTPS with reverse proxy (optional)

---

## 📦 Data Persistence

All persistent data is stored in Docker volumes:

| Volume | Mount Point | Purpose |
|--------|-------------|---------|
| `phi_postgres_data` | `/var/lib/postgresql/data` | Database tables |
| `phi_redis_data` | `/data` | Cache persistence |
| `phi_prometheus_data` | `/prometheus` | Metrics storage |
| `phi_grafana_data` | `/var/lib/grafana` | Dashboards & users |
| `./data/phi` | `/app/data` | PHI application data |
| `./logs/phi` | `/app/logs` | Application logs |

**Backup Commands:**
```bash
# Backup PostgreSQL
docker exec phi-database pg_dump -U postgres phi_db > backup.sql

# Backup volumes
docker run --rm -v phi_postgres_data:/data -v $(pwd):/backup alpine tar czf /backup/postgres-backup.tar.gz /data

# Restore volumes
docker run --rm -v phi_postgres_data:/data -v $(pwd):/backup alpine tar xzf /backup/postgres-backup.tar.gz -C /
```

---

## 🚀 Next Steps

1. **Access PHI Dashboard**: http://localhost:5000
2. **Configure Grafana alerts**: http://localhost:3000
3. **Review deployment logs**: `docker compose logs -f`
4. **Run verification**: `./verify-deployment.sh`
5. **Monitor GPU usage**: `watch -n 1 nvidia-smi`

---

## 📚 Additional Resources

- [Docker Desktop Pro Documentation](https://docs.docker.com/desktop/pro/)
- [NVIDIA Container Toolkit](https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/)
- [PostgreSQL Docker](https://hub.docker.com/_/postgres)
- [Redis Docker](https://hub.docker.com/_/redis)
- [Grafana Documentation](https://grafana.com/docs/)
- [Prometheus Documentation](https://prometheus.io/docs/)

---

## 🛡️ PHI Sovereign Authority Level

**Current Status**: 9/9 - All Systems Operational

Deployed with Docker Desktop Pro optimization for AT2 workstation:
- ✅ GPU acceleration (NVIDIA RTX 4070)
- ✅ Resource-optimized containers
- ✅ Production-grade monitoring
- ✅ Health checks & auto-restart
- ✅ Persistent data volumes
- ✅ Custom network isolation
- ✅ Security hardening
- ✅ Performance tuning
- ✅ Zero-change sync ready

**Deployment ID**: `AT2-DESKTOP-PRO-v1.0`
**Deployment Date**: 2025-03-05
**Architecture**: AMD Ryzen 5 7600X + NVIDIA RTX 4070
**Mode**: SOVEREIGN_MAX with GPU acceleration

---

*For support or questions, refer to DOCKER_DESKTOP_PRO_DEPLOYMENT.md*
