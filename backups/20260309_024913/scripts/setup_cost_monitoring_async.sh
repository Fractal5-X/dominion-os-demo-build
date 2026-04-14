#!/bin/bash
# PHI Chief - Cost Monitoring Dashboard Setup (Async)
# Dominion OS Infrastructure Cost Tracking
# This script runs the dashboard creation in the background to avoid blocking.

set -e

# Color codes
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

LOG_FILE="/tmp/cost_monitoring_setup.log"

echo "========================================" > $LOG_FILE
echo "PHI CHIEF - ASYNC COST MONITORING DASHBOARD" >> $LOG_FILE
echo "========================================" >> $LOG_FILE
echo "" >> $LOG_FILE

PROJECT1="dominion-os-1-0-main"
PROJECT2="dominion-core-prod"

create_dashboard() {
    local project_id=$1
    local dashboard_json_path=$2
    echo "Creating cost dashboard for $project_id..." >> $LOG_FILE
    if gcloud monitoring dashboards create --project="$project_id" --config-from-file="$dashboard_json_path" >> $LOG_FILE 2>&1; then
        echo -e "  ${GREEN}✓ Successfully initiated dashboard creation for $project_id.${NC}"
    else
        echo -e "  ${YELLOW}⚠ Failed to create dashboard for $project_id. Check logs at $LOG_FILE.${NC}"
    fi
}

# Create cost monitoring dashboard JSON
cat > /tmp/cost_dashboard.json <<'COST_EOF'
{
  "displayName": "Dominion OS - Cost & Resource Utilization",
  "mosaicLayout": {
    "columns": 12,
    "tiles": [
      {
        "width": 6,
        "height": 4,
        "widget": {
          "title": "Cloud Run CPU Utilization",
          "xyChart": {
            "dataSets": [{
              "timeSeriesQuery": {
                "timeSeriesFilter": {
                  "filter": "resource.type=\"cloud_run_revision\" metric.type=\"run.googleapis.com/container/cpu/utilizations\"",
                  "aggregation": {
                    "alignmentPeriod": "60s",
                    "perSeriesAligner": "ALIGN_MEAN",
                    "crossSeriesReducer": "REDUCE_MEAN",
                    "groupByFields": ["resource.service_name"]
                  }
                }
              }
            }],
            "timeshiftDuration": "0s"
          }
        }
      },
      {
        "width": 6,
        "height": 4,
        "widget": {
          "title": "Cloud Run Request Count",
          "xyChart": {
            "dataSets": [{
              "timeSeriesQuery": {
                "timeSeriesFilter": {
                  "filter": "resource.type=\"cloud_run_revision\" metric.type=\"run.googleapis.com/request_count\"",
                  "aggregation": {
                    "alignmentPeriod": "60s",
                    "perSeriesAligner": "ALIGN_SUM",
                    "crossSeriesReducer": "REDUCE_SUM",
                    "groupByFields": ["resource.service_name"]
                  }
                }
              }
            }],
            "timeshiftDuration": "0s"
          }
        }
      }
    ]
  }
}
COST_EOF

echo -e "${BLUE}[1/2] Initiating Cost Monitoring Dashboard creation in background...${NC}"
create_dashboard "$PROJECT1" "/tmp/cost_dashboard.json" &
create_dashboard "$PROJECT2" "/tmp/cost_dashboard.json" &

wait
echo -e "${GREEN}Finished dispatching dashboard creation jobs. See $LOG_FILE for details.${NC}"
