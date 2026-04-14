#!/usr/bin/env bash
set -euo pipefail
# Continuous AT2 machine performance monitoring

gt() {
  awk -v left="$1" -v right="$2" 'BEGIN { exit !(left > right) }'
}

while true; do
  TIMESTAMP=$(date +%s)
  CPU_USAGE=$(top -bn1 | grep "Cpu(s)" | sed "s/.*, *\([0-9.]*\)%* id.*/\1/" | awk '{print 100 - $1}')
  MEM_USAGE=$(free | grep Mem | awk '{printf "%.1f", $3/$2 * 100.0}')
  if command -v nvidia-smi >/dev/null 2>&1; then
    GPU_USAGE=$(nvidia-smi --query-gpu=utilization.gpu --format=csv,noheader,nounits 2>/dev/null | awk '{sum+=$1} END{if(NR==0) print 0; else printf "%.1f", sum/NR}')
  else
    GPU_USAGE=0
  fi

  # Check for anomalies
  if gt "$CPU_USAGE" "95"; then
    echo "$TIMESTAMP: CPU_ANOMALY: $CPU_USAGE%" >> "/workspaces/dominion-os-demo-build/scripts/logs/performance_anomalies.log"
  fi

  if gt "$MEM_USAGE" "90"; then
    echo "$TIMESTAMP: MEM_ANOMALY: $MEM_USAGE%" >> "/workspaces/dominion-os-demo-build/scripts/logs/performance_anomalies.log"
  fi

  if gt "$GPU_USAGE" "95"; then
    echo "$TIMESTAMP: GPU_ANOMALY: $GPU_USAGE%" >> "/workspaces/dominion-os-demo-build/scripts/logs/performance_anomalies.log"
  fi

  sleep 30
done
