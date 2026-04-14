#!/bin/bash
# PHI Complete System Status - March 7, 2026

echo "════════════════════════════════════════════════════════════"
echo "  PHI COMPLETE SYSTEM STATUS & LIVE OPS VERIFICATION"
echo "════════════════════════════════════════════════════════════"
echo ""
date
echo ""

echo "━━━ SYSTEM RESOURCES ━━━"
echo "CPU: $(nproc) cores - $(grep "model name" /proc/cpuinfo | head -1 | cut -d: -f2 | xargs)"
echo "Memory: $(free -h | awk '/^Mem:/ {print $2}') total, $(free -h | awk '/^Mem:/ {print $7}') available"
echo "Disk: $(df -h / | awk 'NR==2 {print $2}') total, $(df -h / | awk 'NR==2 {print $4}') available"
echo ""

echo "━━━ PHI WEB SERVICES ━━━"
lsof -ti:5000 > /dev/null 2>&1 && echo "✓ Command Center (BIMS) - Port 5000 - http://localhost:5000" || echo "✗ Command Center - Not Running"
lsof -ti:5001 > /dev/null 2>&1 && echo "✓ Billing Service - Port 5001 - http://localhost:5001" || echo "✗ Billing Service - Not Running"  
lsof -ti:8080 > /dev/null 2>&1 && echo "✓ OAuth Server - Port 8080 - http://localhost:8080" || echo "✗ OAuth Server - Not Running"
lsof -ti:8081 > /dev/null 2>&1 && echo "✓ AskPHI Widget - Port 8081 - http://localhost:8081" || echo "✗ AskPHI Widget - Not Running"
echo ""

echo "━━━ DOCKER STATUS ━━━"
echo "Docker Version: $(docker --version)"
echo "Docker Compose: $(docker-compose --version)"
if docker info > /dev/null 2>&1; then
    echo "✓ Docker Daemon: RUNNING"
    docker ps --format "{{.Names}} - {{.Status}}" | sed 's/^/  /' || echo "  No containers"
else
    echo "⚠ Docker Daemon: NOT RUNNING (normal in Codespaces)"
fi
echo ""

echo "━━━ RUNNING PROCESSES ━━━"
echo "Python Services: $(ps aux | grep 'python3 app.py' | grep -v grep | wc -l)"
ps aux | grep 'python3 app.py' | grep -v grep | awk '{print "  PID " $2 ": " $11 " " $12}'
echo ""

echo "━━━ LIVE OPS SCORE ━━━"
SERVICES=$(lsof -ti:5000,5001,8080,8081 2>/dev/null | wc -l)
echo "Active Services: $SERVICES/4"

SCORE=$((SERVICES * 25))
echo "Overall Score: $SCORE/100"

if [ $SCORE -ge 75 ]; then
    echo "Status: ✅ EXCELLENT - Core systems operational"
elif [ $SCORE -ge 50 ]; then
    echo "Status: ✓ GOOD - Majority operational"
else
    echo "Status: ⚠ NEEDS ATTENTION"
fi
echo ""

echo "════════════════════════════════════════════════════════════"
echo "  DOCKER DESKTOP PRO OPTIMAL CONFIGURATION"
echo "════════════════════════════════════════════════════════════"
echo ""
echo "Recommended Settings:"
echo "  • CPUs: 16 cores (all available)"
echo "  • Memory: 48 GB"
echo "  • Swap: 4 GB"
echo "  • Disk: 100 GB (dynamic)"
echo "  • Storage Driver: overlay2"
echo ""
echo "Optimal daemon.json:"
cat << 'DOCKERJSON'
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
  "max-concurrent-uploads": 10
}
DOCKERJSON
echo ""
echo "════════════════════════════════════════════════════════════"
