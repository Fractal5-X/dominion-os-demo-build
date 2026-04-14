# MCP Servers Docker Desktop Pro - Optimal Configuration Guide
## March 7, 2026

## 🐳 Overview

This guide provides optimal Docker Desktop Pro configuration for running all MCP (Model Context Protocol) servers in containerized environments with maximum performance and reliability.

---

## 📋 Available MCP Servers in Your Environment

Based on your deferred tools, you have access to these MCP server categories:

### 1. **Atlassian MCP Server** (`mcp_atlassian`)
- Jira issue management
- Confluence page operations
- Project workflows

### 2. **Azure AKS MCP Server** (`mcp_azure_aks-mcp`)
- Kubernetes cluster management
- Azure resources monitoring
- Network diagnostics

### 3. **Figma MCP Server** (`mcp_com_figma_mcp`)
- Design system integration
- Code connect mappings
- Screenshot generation

### 4. **Stripe MCP Server** (`mcp_com_stripe_mc`)
- Payment processing
- Subscription management
- Billing operations

### 5. **Firecrawl MCP Server** (`mcp_firecrawl_fir`)
- Web scraping
- Content extraction
- Site mapping

### 6. **GitHub MCP Server** (`mcp_github_github`)
- Repository management
- Issue/PR operations
- Code search

### 7. **GitKraken MCP Server** (`mcp_gitkraken`)
- Git operations
- Branch management
- Workspace management

### 8. **Chrome Browser MCP Server** (`mcp_io_github_chr`)
- Browser automation
- Performance testing
- Screenshot capture

### 9. **Playwright MCP Server** (`mcp_microsoft_pla`)
- E2E testing
- Browser automation
- Multi-browser support

### 10. **Serena Code Intelligence** (`mcp_oraios_serena`)
- Semantic code search
- Symbol analysis
- Memory management

### 11. **Pylance Python MCP Server** (`mcp_pylance_mcp_s`)
- Python language services
- Code refactoring
- Syntax validation

### 12. **Markdown Converter** (`mcp_microsoft_mar`)
- Document conversion
- Format transformation

### 13. **Docker MCP Manager** (`mcp_mcp_docker`)
- MCP server orchestration
- Container management
- Configuration control

---

## 🔧 Docker Desktop Pro Optimal Settings

### Resource Allocation Per MCP Server Type

```yaml
# docker-compose.yml for MCP Servers
version: '3.8'

services:
  # Atlassian MCP Server
  mcp-atlassian:
    image: mcp/atlassian:latest
    container_name: mcp-atlassian
    restart: unless-stopped
    environment:
      - ATLASSIAN_API_TOKEN=${ATLASSIAN_API_TOKEN}
      - ATLASSIAN_BASE_URL=${ATLASSIAN_BASE_URL}
      - NODE_ENV=production
    resources:
      limits:
        cpus: '2'
        memory: 2G
      reservations:
        cpus: '0.5'
        memory: 512M
    networks:
      - mcp-network
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:3000/health"]
      interval: 30s
      timeout: 10s
      retries: 3

  # Azure AKS MCP Server
  mcp-azure-aks:
    image: mcp/azure-aks:latest
    container_name: mcp-azure-aks
    restart: unless-stopped
    environment:
      - AZURE_SUBSCRIPTION_ID=${AZURE_SUBSCRIPTION_ID}
      - AZURE_TENANT_ID=${AZURE_TENANT_ID}
      - AZURE_CLIENT_ID=${AZURE_CLIENT_ID}
      - AZURE_CLIENT_SECRET=${AZURE_CLIENT_SECRET}
    resources:
      limits:
        cpus: '3'
        memory: 4G
      reservations:
        cpus: '1'
        memory: 1G
    networks:
      - mcp-network
    volumes:
      - azure-aks-data:/data
    healthcheck:
      test: ["CMD", "az", "account", "show"]
      interval: 60s
      timeout: 15s
      retries: 3

  # Figma MCP Server
  mcp-figma:
    image: mcp/figma:latest
    container_name: mcp-figma
    restart: unless-stopped
    environment:
      - FIGMA_API_TOKEN=${FIGMA_API_TOKEN}
      - FIGMA_CACHE_ENABLED=true
    resources:
      limits:
        cpus: '2'
        memory: 2G
      reservations:
        cpus: '0.5'
        memory: 512M
    networks:
      - mcp-network
    volumes:
      - figma-cache:/cache
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:3001/health"]
      interval: 30s
      timeout: 10s
      retries: 3

  # Stripe MCP Server
  mcp-stripe:
    image: mcp/stripe:latest
    container_name: mcp-stripe
    restart: unless-stopped
    environment:
      - STRIPE_SECRET_KEY=${STRIPE_SECRET_KEY}
      - STRIPE_WEBHOOK_SECRET=${STRIPE_WEBHOOK_SECRET}
      - NODE_ENV=production
    resources:
      limits:
        cpus: '2'
        memory: 2G
      reservations:
        cpus: '0.5'
        memory: 512M
    networks:
      - mcp-network
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:3002/health"]
      interval: 30s
      timeout: 10s
      retries: 3

  # GitHub MCP Server
  mcp-github:
    image: mcp/github:latest
    container_name: mcp-github
    restart: unless-stopped
    environment:
      - GITHUB_TOKEN=${GITHUB_TOKEN}
      - GITHUB_API_URL=https://api.github.com
    resources:
      limits:
        cpus: '2'
        memory: 2G
      reservations:
        cpus: '0.5'
        memory: 512M
    networks:
      - mcp-network
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:3003/health"]
      interval: 30s
      timeout: 10s
      retries: 3

  # Playwright MCP Server (Browser Automation)
  mcp-playwright:
    image: mcr.microsoft.com/playwright:latest
    container_name: mcp-playwright
    restart: unless-stopped
    environment:
      - PLAYWRIGHT_BROWSERS_PATH=/ms-playwright
    resources:
      limits:
        cpus: '4'
        memory: 4G
      reservations:
        cpus: '1'
        memory: 1G
    networks:
      - mcp-network
    volumes:
      - playwright-cache:/ms-playwright
    shm_size: '2gb'
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:3004/health"]
      interval: 30s
      timeout: 10s
      retries: 3

  # Chrome Browser MCP Server
  mcp-chrome:
    image: browserless/chrome:latest
    container_name: mcp-chrome
    restart: unless-stopped
    environment:
      - MAX_CONCURRENT_SESSIONS=10
      - CONNECTION_TIMEOUT=60000
    resources:
      limits:
        cpus: '4'
        memory: 4G
      reservations:
        cpus: '1'
        memory: 1G
    networks:
      - mcp-network
    shm_size: '2gb'
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:3005/health"]
      interval: 30s
      timeout: 10s
      retries: 3

  # Pylance Python MCP Server
  mcp-pylance:
    image: mcp/pylance:latest
    container_name: mcp-pylance
    restart: unless-stopped
    environment:
      - PYTHON_VERSION=3.12
    resources:
      limits:
        cpus: '2'
        memory: 3G
      reservations:
        cpus: '0.5'
        memory: 1G
    networks:
      - mcp-network
    volumes:
      - pylance-cache:/cache
      - ${PWD}:/workspace:cached
    healthcheck:
      test: ["CMD", "python", "-c", "import sys; print(sys.version)"]
      interval: 30s
      timeout: 10s
      retries: 3

  # Serena Code Intelligence MCP Server
  mcp-serena:
    image: mcp/serena:latest
    container_name: mcp-serena
    restart: unless-stopped
    environment:
      - SERENA_MEMORY_LIMIT=2GB
    resources:
      limits:
        cpus: '3'
        memory: 4G
      reservations:
        cpus: '1'
        memory: 1G
    networks:
      - mcp-network
    volumes:
      - serena-memory:/memories
      - ${PWD}:/workspace:cached
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:3006/health"]
      interval: 30s
      timeout: 10s
      retries: 3

networks:
  mcp-network:
    driver: bridge
    ipam:
      config:
        - subnet: 172.28.0.0/16

volumes:
  azure-aks-data:
  figma-cache:
  playwright-cache:
  pylance-cache:
  serena-memory:
```

---

## ⚙️ Docker Desktop Pro Daemon Configuration

### Optimal daemon.json for MCP Servers

```json
{
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "10m",
    "max-file": "3"
  },
  "storage-driver": "overlay2",
  "default-ulimits": {
    "nofile": {
      "Name": "nofile",
      "Hard": 64000,
      "Soft": 64000
    }
  },
  "max-concurrent-downloads": 10,
  "max-concurrent-uploads": 10,
  "dns": ["8.8.8.8", "8.8.4.4"],
  "features": {
    "buildkit": true
  },
  "experimental": false,
  "metrics-addr": "127.0.0.1:9323",
  "max-allowed-packets": 100000,
  "default-address-pools": [
    {
      "base": "172.28.0.0/16",
      "size": 24
    }
  ],
  "live-restore": true,
  "userland-proxy": false,
  "icc": false,
  "default-network-opts": {
    "bridge": {
      "com.docker.network.bridge.name": "mcp-bridge",
      "com.docker.network.bridge.enable_ip_masquerade": "true",
      "com.docker.network.driver.mtu": "1500"
    }
  }
}
```

---

## 📊 Resource Requirements Summary

### Per MCP Server Type

| MCP Server | Min CPU | Max CPU | Min RAM | Max RAM | Storage |
|------------|---------|---------|---------|---------|---------|
| Atlassian | 0.5 | 2 | 512MB | 2GB | 1GB |
| Azure AKS | 1 | 3 | 1GB | 4GB | 5GB |
| Figma | 0.5 | 2 | 512MB | 2GB | 2GB |
| Stripe | 0.5 | 2 | 512MB | 2GB | 500MB |
| GitHub | 0.5 | 2 | 512MB | 2GB | 1GB |
| Playwright | 1 | 4 | 1GB | 4GB | 3GB |
| Chrome | 1 | 4 | 1GB | 4GB | 2GB |
| Pylance | 0.5 | 2 | 1GB | 3GB | 2GB |
| Serena | 1 | 3 | 1GB | 4GB | 5GB |
| GitKraken | 0.5 | 2 | 512MB | 2GB | 2GB |
| Firecrawl | 0.5 | 2 | 512MB | 2GB | 1GB |

### Total System Requirements (All MCP Servers)

- **Minimum**: 8 CPU cores, 16GB RAM, 30GB disk
- **Recommended**: 16 CPU cores, 48GB RAM, 100GB disk
- **Optimal**: 32 CPU cores, 96GB RAM, 250GB disk

---

## 🚀 Environment Configuration

### .env File Template

```bash
# .env for MCP Servers
# Copy this to .env and fill in your credentials

# Atlassian
ATLASSIAN_API_TOKEN=your_atlassian_token
ATLASSIAN_BASE_URL=https://your-domain.atlassian.net

# Azure
AZURE_SUBSCRIPTION_ID=your_subscription_id
AZURE_TENANT_ID=your_tenant_id
AZURE_CLIENT_ID=your_client_id
AZURE_CLIENT_SECRET=your_client_secret

# Figma
FIGMA_API_TOKEN=your_figma_token

# Stripe
STRIPE_SECRET_KEY=sk_live_your_key
STRIPE_WEBHOOK_SECRET=whsec_your_secret

# GitHub
GITHUB_TOKEN=ghp_your_github_token

# General
NODE_ENV=production
LOG_LEVEL=info
ENABLE_METRICS=true
METRICS_PORT=9323
```

---

## 🔐 Security Best Practices

### 1. Network Isolation
```yaml
# Use dedicated networks for MCP servers
networks:
  mcp-network:
    driver: bridge
    internal: false
    ipam:
      config:
        - subnet: 172.28.0.0/16
```

### 2. Secret Management
```bash
# Use Docker secrets for sensitive data
echo "your_token" | docker secret create github_token -
```

### 3. Resource Limits
```yaml
# Always set resource limits
resources:
  limits:
    cpus: '2'
    memory: 2G
  reservations:
    cpus: '0.5'
    memory: 512M
```

---

## 📈 Monitoring Configuration

### Prometheus Metrics Endpoint

```yaml
# prometheus.yml
global:
  scrape_interval: 15s

scrape_configs:
  - job_name: 'docker'
    static_configs:
      - targets: ['localhost:9323']
  
  - job_name: 'mcp-servers'
    static_configs:
      - targets:
        - 'mcp-atlassian:3000'
        - 'mcp-figma:3001'
        - 'mcp-stripe:3002'
        - 'mcp-github:3003'
        - 'mcp-playwright:3004'
        - 'mcp-chrome:3005'
        - 'mcp-serena:3006'
```

### Grafana Dashboard

```json
{
  "dashboard": {
    "title": "MCP Servers Dashboard",
    "panels": [
      {
        "title": "Container CPU Usage",
        "targets": [
          {
            "expr": "rate(container_cpu_usage_seconds_total{name=~\"mcp-.*\"}[5m])"
          }
        ]
      },
      {
        "title": "Container Memory Usage",
        "targets": [
          {
            "expr": "container_memory_usage_bytes{name=~\"mcp-.*\"}"
          }
        ]
      }
    ]
  }
}
```

---

## 🛠️ Management Commands

### Start All MCP Servers
```bash
cd /workspaces/dominion-os-demo-build
docker-compose -f docker-compose-mcp.yml up -d
```

### Check Status
```bash
docker ps --filter "name=mcp-" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
```

### View Logs
```bash
# All MCP servers
docker-compose logs -f

# Specific server
docker logs -f mcp-github
```

### Health Check All Servers
```bash
#!/bin/bash
# health_check_mcp.sh

MCP_SERVERS=(
  "mcp-atlassian:3000"
  "mcp-figma:3001"
  "mcp-stripe:3002"
  "mcp-github:3003"
  "mcp-playwright:3004"
  "mcp-chrome:3005"
  "mcp-serena:3006"
)

for server in "${MCP_SERVERS[@]}"; do
  name=$(echo $server | cut -d: -f1)
  port=$(echo $server | cut -d: -f2)
  
  if curl -sf http://localhost:$port/health > /dev/null; then
    echo "✅ $name - HEALTHY"
  else
    echo "❌ $name - DOWN"
  fi
done
```

### Stop All MCP Servers
```bash
docker-compose -f docker-compose-mcp.yml down
```

### Update All MCP Servers
```bash
docker-compose -f docker-compose-mcp.yml pull
docker-compose -f docker-compose-mcp.yml up -d
```

---

## 🔄 Auto-Restart Configuration

### Systemd Service (Linux)

```ini
# /etc/systemd/system/mcp-servers.service
[Unit]
Description=MCP Servers Docker Compose
Requires=docker.service
After=docker.service

[Service]
Type=oneshot
RemainAfterExit=yes
WorkingDirectory=/workspaces/dominion-os-demo-build
ExecStart=/usr/bin/docker-compose -f docker-compose-mcp.yml up -d
ExecStop=/usr/bin/docker-compose -f docker-compose-mcp.yml down
TimeoutStartSec=0

[Install]
WantedBy=multi-user.target
```

Enable:
```bash
sudo systemctl enable mcp-servers.service
sudo systemctl start mcp-servers.service
```

---

## 🎯 Performance Optimization

### 1. Enable BuildKit
```bash
export DOCKER_BUILDKIT=1
export COMPOSE_DOCKER_CLI_BUILD=1
```

### 2. Use Layer Caching
```dockerfile
# Example Dockerfile optimization
FROM node:18-alpine AS base
WORKDIR /app

# Copy package files first (cached layer)
COPY package*.json ./
RUN npm ci --only=production

# Copy application code (changes more frequently)
COPY . .

CMD ["node", "server.js"]
```

### 3. Multi-Stage Builds
```dockerfile
# Build stage
FROM node:18 AS builder
WORKDIR /app
COPY . .
RUN npm ci && npm run build

# Production stage
FROM node:18-alpine
WORKDIR /app
COPY --from=builder /app/dist ./dist
COPY --from=builder /app/node_modules ./node_modules
CMD ["node", "dist/server.js"]
```

---

## 📱 Docker Desktop Pro Features to Enable

### Essential Features
- ✅ **Resource Saver** - Auto-pause unused containers
- ✅ **Enhanced Container Isolation** - Security
- ✅ **BuildKit** - Faster builds
- ✅ **Dev Environments** - Consistent dev setup
- ✅ **Docker Extensions** - Additional tools
- ✅ **Vulnerability Scanning** - Security checks

### Dashboard Settings
```
Settings → Resources:
  ├─ CPUs: 16 cores (for all MCP servers)
  ├─ Memory: 48 GB
  ├─ Swap: 4 GB
  ├─ Disk: 100 GB
  └─ File Sharing: /workspaces

Settings → Docker Engine:
  └─ Apply daemon.json configuration above

Settings → Features in Development:
  ├─ Enable BuildKit: ✅
  ├─ Use containerd for pulling: ✅
  └─ Enable host networking: ✅
```

---

## 🧪 Testing Configuration

### Test Script
```bash
#!/bin/bash
# test_mcp_configuration.sh

echo "🧪 Testing MCP Docker Desktop Pro Configuration..."

# Test Docker daemon
if docker info > /dev/null 2>&1; then
  echo "✅ Docker daemon running"
else
  echo "❌ Docker daemon not running"
  exit 1
fi

# Test Docker Compose
if docker-compose version > /dev/null 2>&1; then
  echo "✅ Docker Compose available"
else
  echo "❌ Docker Compose not available"
  exit 1
fi

# Test resource limits
CPU_COUNT=$(docker info --format '{{.NCPU}}')
MEMORY_GB=$(docker info --format '{{.MemTotal}}' | awk '{print int($1/1024/1024/1024)}')

echo "📊 Available Resources:"
echo "  - CPUs: $CPU_COUNT"
echo "  - Memory: ${MEMORY_GB}GB"

if [ "$CPU_COUNT" -ge 16 ] && [ "$MEMORY_GB" -ge 48 ]; then
  echo "✅ Resources optimal for all MCP servers"
else
  echo "⚠️  Resources below recommended (16 CPUs, 48GB RAM)"
fi

# Test network
if docker network ls | grep -q mcp-network; then
  echo "✅ MCP network configured"
else
  echo "⚠️  MCP network not found"
fi

echo "✅ Configuration test complete!"
```

---

## 📚 Quick Reference

### Port Mapping
| Service | Internal Port | External Port | Protocol |
|---------|---------------|---------------|----------|
| Atlassian | 3000 | 3000 | HTTP |
| Figma | 3001 | 3001 | HTTP |
| Stripe | 3002 | 3002 | HTTP |
| GitHub | 3003 | 3003 | HTTP |
| Playwright | 3004 | 3004 | HTTP |
| Chrome | 3005 | 3005 | HTTP |
| Serena | 3006 | 3006 | HTTP |
| Prometheus | 9090 | 9090 | HTTP |
| Grafana | 3007 | 3007 | HTTP |

### Environment Variables
- `NODE_ENV=production` - Production mode
- `LOG_LEVEL=info` - Logging level
- `ENABLE_METRICS=true` - Enable Prometheus metrics
- `MAX_CONCURRENT_SESSIONS=10` - Browser automation limit

---

## ✅ Verification Checklist

- [ ] Docker Desktop Pro installed and activated
- [ ] daemon.json configured with optimal settings
- [ ] Resources allocated (16 CPUs, 48GB RAM minimum)
- [ ] docker-compose-mcp.yml created
- [ ] .env file configured with all credentials
- [ ] MCP network created
- [ ] All volumes created
- [ ] Health checks configured
- [ ] Monitoring (Prometheus/Grafana) set up
- [ ] Auto-restart configured
- [ ] Security best practices applied
- [ ] Test script executed successfully

---

## 🎯 Next Steps

1. **Copy docker-compose-mcp.yml** to your Docker Desktop Pro environment
2. **Configure .env** with your API credentials
3. **Start services**: `docker-compose up -d`
4. **Verify health**: Run health check script
5. **Monitor**: Access Grafana at http://localhost:3007
6. **Test**: Execute test_mcp_configuration.sh

---

**Configuration Created**: March 7, 2026  
**Status**: ✅ OPTIMAL CONFIGURATION READY  
**Next Update**: As needed for new MCP servers

