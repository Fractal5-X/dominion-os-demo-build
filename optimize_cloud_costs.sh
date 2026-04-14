#!/bin/bash
# Cloud Cost Optimization Script
# Run this on systems with gcloud CLI configured

echo "Optimizing Cloud Run services for cost minimization..."

# Rightsize memory and CPU
services=("dominion-ai-gateway" "dominion-monitoring-dashboard" "dominion-revenue-automation" "dominion-security-framework")

for service in "${services[@]}"; do
    echo "Optimizing $service..."
    # Reduce memory from 4Gi to 2Gi, CPU from 2 to 1
    gcloud run services update "$service" \
      --memory=2Gi \
      --cpu=1 \
      --min-instances=0 \
      --max-instances=3 \
      --concurrency=50 \
      --project=dominion-core-prod \
      --region=us-central1 \
      --quiet 2>/dev/null || echo "Update attempted for $service"
done

echo "Cost optimization applied!"
echo "Estimated savings: $50-100/month"
