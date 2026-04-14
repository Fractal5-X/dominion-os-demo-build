#!/bin/bash
# Continuous AT2 machine performance monitoring

while true; do
  TIMESTAMP=$(date +%s)
  CPU_USAGE=$(top -bn1 | grep "Cpu(s)" | sed "s/.*, *\([0-9.]*\)%* id.*/\1/" | awk '{print 100 - $1}')
  MEM_USAGE=$(free | grep Mem | awk '{printf "%.1f", $3/$2 * 100.0}')
  GPU_USAGE=$(nvidia-smi --query-gpu=utilization.gpu --format=csv,noheader,nounits 2>/dev/null || echo "25.0")

  # Check for anomalies
  if (( $(echo "$CPU_USAGE > 95" | bc -l) )); then
    echo "$TIMESTAMP: CPU_ANOMALY: $CPU_USAGE%" >> logs/performance_anomalies.log
  fi

  if (( $(echo "$MEM_USAGE > 90" | bc -l) )); then
    echo "$TIMESTAMP: MEM_ANOMALY: $MEM_USAGE%" >> logs/performance_anomalies.log
  fi

  if (( $(echo "$GPU_USAGE > 95" | bc -l) )); then
    echo "$TIMESTAMP: GPU_ANOMALY: $GPU_USAGE%" >> logs/performance_anomalies.log
  fi

  sleep 30
done
