# PHI SOVEREIGN DEPLOYMENT GUIDE - DOCKER DESKTOP PRO
## Maximum Authority Mode 9/9 | at2 Workstation Optimized

### 🎯 Hardware Configuration
- **CPU**: AMD Ryzen 5 7600X (6 cores, 12 threads @ 4.7 GHz)
- **GPU**: NVIDIA RTX 4070 (12GB GDDR6X, CUDA 8.9)
- **RAM**: 32GB DDR5
- **Platform**: Docker Desktop Pro on Windows/Linux

### 🚀 Quick Start

#### 1. Environment Setup
```bash
# Create environment file
cp .env.example .env

# Edit with your credentials
nano .env
```

#### 2. Launch Sovereign Stack
```bash
# Full stack with all services
docker-compose -f docker-compose.desktop-pro.yml up -d

# View logs
docker-compose -f docker-compose.desktop-pro.yml logs -f

# Check status
docker-compose -f docker-compose.desktop-pro.yml ps
```

#### 3. Access Services
- **PHI Dashboard**: http://localhost:5000
- **OAuth Server**: http://localhost:8080
- **AskPHI Widget**: http://localhost:8081
- **Prometheus**: http://localhost:9090
- **Grafana**: http://localhost:3000
- **PostgreSQL**: localhost:5432
- **Redis**: localhost:6379

### 📊 Service Architecture

```
┌─────────────────────────────────────────────────────────┐
│              PHI SOVEREIGN STACK (9/9)                  │
├─────────────────────────────────────────────────────────┤
│                                                         │
│  ┌──────────────┐    ┌──────────────┐                 │
│  │ PHI Core     │    │ OAuth Server │                 │
│  │ Port: 5000   │    │ Port: 8080   │                 │
│  └──────────────┘    └──────────────┘                 │
│                                                         │
│  ┌──────────────┐    ┌──────────────┐                 │
│  │ AskPHI       │    │ PostgreSQL   │                 │
│  │ Port: 8081   │    │ Port: 5432   │                 │
│  └──────────────┘    └──────────────┘                 │
│                                                         │
│  ┌──────────────┐    ┌──────────────┐                 │
│  │ Prometheus   │    │ Grafana      │                 │
│  │ Port: 9090   │    │ Port: 3000   │                 │
│  └──────────────┘    └──────────────┘                 │
│                                                         │
└─────────────────────────────────────────────────────────┘
```

### ⚡ Performance Optimization

#### Resource Allocation
- **PHI Core**: 4 CPU cores, 4GB RAM (GPU enabled)
- **Database**: 2 CPU cores, 2GB RAM
- **Redis**: 1 CPU core, 1GB RAM, 512MB cache
- **Monitoring**: 1 CPU core each, 1GB RAM

#### GPU Acceleration (NVIDIA RTX 4070)
```yaml
environment:
  - NVIDIA_VISIBLE_DEVICES=all
  - CUDA_VISIBLE_DEVICES=0
  - GPU_ENABLED=true
```

#### Network Optimization
- Custom bridge network: `phi-bridge`
- MTU: 1500 (optimal for desktop)
- Subnet: 172.28.0.0/16

### 🔒 Security Configuration

#### Sovereign Authority
- **Level**: 9/9 (Maximum)
- **Mode**: SOVEREIGN_MAX
- **Authentication**: OAuth 2.0 + JWT
- **Encryption**: TLS 1.3

#### Environment Variables
```bash
# Required
POSTGRES_PASSWORD=your_secure_password
GRAFANA_PASSWORD=your_grafana_password
PROJECT_ID=dominion-core-prod

# Optional
PHI_MODE=SOVEREIGN_MAX
AUTHORITY_LEVEL=9
CPU_CORES=6
GPU_ENABLED=true
```

### 📦 Data Persistence

#### Volume Mounts
```
./data          → /app/data     (Application data)
./logs          → /app/logs     (Service logs)
phi-db-data     → PostgreSQL persistence
phi-redis-data  → Redis persistence
prometheus-data → Metrics storage (7-day retention)
grafana-data    → Dashboard configuration
```

### 🔧 Management Commands

#### Start Services
```bash
# All services
docker-compose -f docker-compose.desktop-pro.yml up -d

# Specific service
docker-compose -f docker-compose.desktop-pro.yml up -d phi-sovereign-core

# With build
docker-compose -f docker-compose.desktop-pro.yml up -d --build
```

#### Stop Services
```bash
# All services
docker-compose -f docker-compose.desktop-pro.yml down

# With volume cleanup
docker-compose -f docker-compose.desktop-pro.yml down -v
```

#### Logs & Monitoring
```bash
# Follow all logs
docker-compose -f docker-compose.desktop-pro.yml logs -f

# Specific service
docker-compose -f docker-compose.desktop-pro.yml logs -f phi-sovereign-core

# Last 100 lines
docker-compose -f docker-compose.desktop-pro.yml logs --tail=100
```

#### Health Checks
```bash
# Service status
docker-compose -f docker-compose.desktop-pro.yml ps

# Container health
docker inspect phi-sovereign-core --format='{{.State.Health.Status}}'

# Full diagnostics
docker stats
```

### 🔄 Update & Maintenance

#### Rolling Updates
```bash
# Pull latest images
docker-compose -f docker-compose.desktop-pro.yml pull

# Recreate containers
docker-compose -f docker-compose.desktop-pro.yml up -d --force-recreate

# Zero-downtime update (one service at a time)
docker-compose -f docker-compose.desktop-pro.yml up -d --no-deps phi-sovereign-core
```

#### Backup Database
```bash
# PostgreSQL backup
docker exec phi-database pg_dump -U phi_admin phi_dominion > backup_$(date +%Y%m%d).sql

# Restore
docker exec -i phi-database psql -U phi_admin phi_dominion < backup_20260305.sql
```

#### Clean Up
```bash
# Remove stopped containers
docker-compose -f docker-compose.desktop-pro.yml rm -f

# Prune system (careful!)
docker system prune -af --volumes
```

### 📈 Monitoring & Metrics

#### Prometheus Targets
- PHI Core: http://phi-sovereign-core:5000/metrics
- OAuth Server: http://phi-oauth-server:8080/metrics
- Database: PostgreSQL exporter
- Redis: Redis exporter

#### Grafana Dashboards
1. **PHI Sovereign Overview**: System health, request rates
2. **Resource Utilization**: CPU, memory, GPU usage
3. **Database Performance**: Queries, connections, latency
4. **Business Metrics**: Revenue, customers, transactions

Access Grafana: http://localhost:3000 (admin/sovereign_admin)

### 🐛 Troubleshooting

#### Container Won't Start
```bash
# Check logs
docker-compose -f docker-compose.desktop-pro.yml logs service-name

# Verify configuration
docker-compose -f docker-compose.desktop-pro.yml config

# Test image
docker run --rm service-image-name test
```

#### Database Connection Issues
```bash
# Check database is running
docker exec phi-database pg_isready -U phi_admin

# Connect directly
docker exec -it phi-database psql -U phi_admin -d phi_dominion

# Reset database
docker-compose -f docker-compose.desktop-pro.yml down -v
docker-compose -f docker-compose.desktop-pro.yml up -d phi-database
```

#### GPU Not Detected
```bash
# Verify NVIDIA runtime
docker run --rm --gpus all nvidia/cuda:11.8.0-base-ubuntu22.04 nvidia-smi

# Check Docker Desktop settings
# Settings → Resources → Enable GPU

# Verify in container
docker exec phi-sovereign-core nvidia-smi
```

### 🎯 Production Deployment

#### Pre-deployment Checklist
- [ ] Environment variables configured
- [ ] SSL certificates installed
- [ ] Backup strategy in place
- [ ] Monitoring alerts configured
- [ ] Resource limits verified
- [ ] Security audit completed

#### Deploy to Production
```bash
# Build production images
docker-compose -f docker-compose.desktop-pro.yml build --no-cache

# Start with production env
FLASK_ENV=production docker-compose -f docker-compose.desktop-pro.yml up -d

# Verify all services healthy
docker-compose -f docker-compose.desktop-pro.yml ps
```

### 📞 Support & Documentation

- **PHI Documentation**: `/docs`
- **API Reference**: http://localhost:5000/api/docs
- **Health Endpoint**: http://localhost:5000/health
- **Metrics**: http://localhost:5000/metrics

---

**Sovereign Authority Level**: 9/9
**Platform**: Docker Desktop Pro
**Hardware**: AMD Ryzen 5 7600X + NVIDIA RTX 4070
**Status**: Production Ready ✅
