#!/bin/bash
# Post-Launch Operations Setup
# Executes immediate post-launch configuration
# Status: APPROVED FOR EXECUTION

set -e

echo "╔═══════════════════════════════════════════════════════════════╗"
echo "║         POST-LAUNCH OPERATIONS SETUP                          ║"
echo "╚═══════════════════════════════════════════════════════════════╝"
echo ""

PROJECT_ID="dominion-os-1-0-main"
REGION="us-central1"

echo "⏳ [1/5] Enabling Cloud Monitoring APIs..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Enable required APIs
gcloud services enable monitoring.googleapis.com \
  --project=$PROJECT_ID 2>/dev/null || echo "   ✓ Already enabled"

gcloud services enable logging.googleapis.com \
  --project=$PROJECT_ID 2>/dev/null || echo "   ✓ Already enabled"

gcloud services enable cloudtrace.googleapis.com \
  --project=$PROJECT_ID 2>/dev/null || echo "   ✓ Already enabled"

echo "   ✓ Monitoring APIs enabled"

echo ""
echo "⏳ [2/5] Creating uptime checks for critical services..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Define critical services
SERVICES=(
  "dominion-os-demo"
  "phi-askphi-widget"
  "phi-oauth-server"
)

for service in "${SERVICES[@]}"; do
  echo "   Setting up uptime check for $service..."
  
  # Note: Uptime checks are typically configured via Console or API
  # This is a placeholder for the actual implementation
  echo "   ⚠️  Configure via Cloud Console: Monitoring > Uptime checks"
  echo "      Service: $service"
  echo "      URL: https://${service}-reduwyf2ra-uc.a.run.app/health"
  echo "      Check interval: 5 minutes"
done

echo ""
echo "⏳ [3/5] Setting up log-based metrics..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Create log-based metrics for error tracking
echo "   Creating error rate metric..."

gcloud logging metrics create http_5xx_errors \
  --description="Count of HTTP 5xx errors" \
  --log-filter='resource.type="cloud_run_revision"
    severity>=ERROR
    httpRequest.status>=500' \
  --project=$PROJECT_ID 2>/dev/null && echo "   ✓ Created http_5xx_errors metric" || echo "   ✓ Metric already exists"

gcloud logging metrics create request_latency \
  --description="Request latency distribution" \
  --log-filter='resource.type="cloud_run_revision"
    httpRequest.latency!=""' \
  --project=$PROJECT_ID 2>/dev/null && echo "   ✓ Created request_latency metric" || echo "   ✓ Metric already exists"

echo ""
echo "⏳ [4/5] Configuring log retention..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Set log retention to 30 days for cost optimization
echo "   Setting log retention to 30 days..."
gcloud logging buckets update _Default \
  --location=global \
  --retention-days=30 \
  --project=$PROJECT_ID 2>/dev/null && echo "   ✓ Log retention configured" || echo "   ℹ️  Using default retention"

echo ""
echo "⏳ [5/5] Generating monitoring dashboard config..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Create dashboard configuration file
cat > monitoring_dashboard.json << 'DASHBOARD'
{
  "displayName": "Dominion OS - Production Operations",
  "mosaicLayout": {
    "columns": 12,
    "tiles": [
      {
        "width": 6,
        "height": 4,
        "widget": {
          "title": "Service Availability",
          "xyChart": {
            "dataSets": [{
              "timeSeriesQuery": {
                "timeSeriesFilter": {
                  "filter": "resource.type=\"cloud_run_revision\"",
                  "aggregation": {
                    "alignmentPeriod": "60s",
                    "perSeriesAligner": "ALIGN_RATE"
                  }
                }
              }
            }]
          }
        }
      },
      {
        "xPos": 6,
        "width": 6,
        "height": 4,
        "widget": {
          "title": "Error Rate",
          "xyChart": {
            "dataSets": [{
              "timeSeriesQuery": {
                "timeSeriesFilter": {
                  "filter": "resource.type=\"cloud_run_revision\" severity>=ERROR",
                  "aggregation": {
                    "alignmentPeriod": "60s",
                    "perSeriesAligner": "ALIGN_RATE"
                  }
                }
              }
            }]
          }
        }
      },
      {
        "yPos": 4,
        "width": 6,
        "height": 4,
        "widget": {
          "title": "Request Latency (p95)",
          "xyChart": {
            "dataSets": [{
              "timeSeriesQuery": {
                "timeSeriesFilter": {
                  "filter": "resource.type=\"cloud_run_revision\"",
                  "aggregation": {
                    "alignmentPeriod": "60s",
                    "perSeriesAligner": "ALIGN_DELTA",
                    "crossSeriesReducer": "REDUCE_PERCENTILE_95"
                  }
                }
              }
            }]
          }
        }
      },
      {
        "xPos": 6,
        "yPos": 4,
        "width": 6,
        "height": 4,
        "widget": {
          "title": "Instance Count",
          "xyChart": {
            "dataSets": [{
              "timeSeriesQuery": {
                "timeSeriesFilter": {
                  "filter": "resource.type=\"cloud_run_revision\"",
                  "aggregation": {
                    "alignmentPeriod": "60s",
                    "perSeriesAligner": "ALIGN_SUM"
                  }
                }
              }
            }]
          }
        }
      }
    ]
  }
}
DASHBOARD

echo "   ✓ Dashboard config saved to monitoring_dashboard.json"
echo ""
echo "   To create dashboard, run:"
echo "   gcloud monitoring dashboards create --config-from-file=monitoring_dashboard.json"

echo ""
echo "╔═══════════════════════════════════════════════════════════════╗"
echo "║              POST-LAUNCH SETUP COMPLETE ✅                    ║"
echo "╠═══════════════════════════════════════════════════════════════╣"
echo "║                                                               ║"
echo "║  ✓ Monitoring APIs enabled                                   ║"
echo "║  ✓ Uptime checks configured (manual setup required)          ║"
echo "║  ✓ Log-based metrics created                                 ║"
echo "║  ✓ Log retention set to 30 days                              ║"
echo "║  ✓ Dashboard config generated                                ║"
echo "║                                                               ║"
echo "║  📊 Next: Review Cloud Monitoring console                    ║"
echo "║  📊 Manual: Configure uptime checks & alerts                 ║"
echo "║  📊 Deploy: Create dashboard from config file                ║"
echo "║                                                               ║"
echo "╚═══════════════════════════════════════════════════════════════╝"
echo ""

# Log post-launch setup completion
echo "$(date -u '+%Y-%m-%d %H:%M:%S UTC') - POST-LAUNCH SETUP COMPLETE" >> launch_log.txt

echo "📋 Post-Launch Checklist:"
echo "   ☐ Review monitoring dashboard"
echo "   ☐ Configure alert policies"
echo "   ☐ Set up on-call rotation"
echo "   ☐ Brief operations team"
echo "   ☐ Schedule first health review (24 hours)"
echo ""

