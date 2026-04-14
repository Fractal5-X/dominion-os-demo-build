#!/bin/bash
# PHI Chief - BIMS (Business Intelligence Management System) Optimization
# Purpose: Optimize Dominion OS Google Cloud BIMS with Apollo data integration
# Target: Real-time business intelligence dashboards and analytics

set -e

echo "📊 PHI CHIEF - BIMS OPTIMIZATION"
echo "==============================="
echo "Optimizing Dominion OS Google Cloud BIMS with Apollo data"
echo "Timestamp: $(date)"
echo ""

# Configuration
PROJECT1="dominion-os-1-0-main"
PROJECT2="dominion-core-prod"
REGION="us-central1"
DATASET="dominion_bims"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

# Function to setup BigQuery dataset
setup_bigquery_dataset() {
    echo -e "${BLUE}[1/5] Setting up BigQuery dataset...${NC}"

    # Create dataset if it doesn't exist
    bq --project_id="$PROJECT1" mk --dataset "$DATASET" 2>/dev/null || true

    echo -e "${GREEN}✅ BigQuery dataset ready: $DATASET${NC}"
}

# Function to create BIMS data tables
create_bims_tables() {
    echo -e "${BLUE}[2/5] Creating BIMS data tables...${NC}"

    # CRM Accounts table
    bq --project_id="$PROJECT1" mk --table \
        "$DATASET.crm_accounts" \
        "id:STRING,name:STRING,domain:STRING,industry:STRING,headcount:INTEGER,revenue_range:STRING,location:STRING,apollo_score:FLOAT,last_updated:TIMESTAMP,crm_status:STRING" \
        2>/dev/null || true

    # Sales pipeline table
    bq --project_id="$PROJECT1" mk --table \
        "$DATASET.sales_pipeline" \
        "id:STRING,account_id:STRING,opportunity_name:STRING,value:FLOAT,stage:STRING,close_date:DATE,probability:FLOAT,owner:STRING" \
        2>/dev/null || true

    # Business metrics table
    bq --project_id="$PROJECT1" mk --table \
        "$DATASET.business_metrics" \
        "date:DATE,metric_name:STRING,value:FLOAT,category:STRING,target:FLOAT,variance:FLOAT" \
        2>/dev/null || true

    echo -e "${GREEN}✅ BIMS tables created${NC}"
}

# Function to load Apollo CRM data
load_apollo_data() {
    echo -e "${BLUE}[3/5] Loading Apollo CRM data into BIMS...${NC}"

    if [ -f "data/apollo_crm/crm_accounts.json" ]; then
        # Convert JSON to CSV for BigQuery
        python3 -c "
import json
import csv
import sys

try:
    with open('data/apollo_crm/crm_accounts.json', 'r') as f:
        accounts = json.load(f)

    if accounts:
        # Write CSV header
        fieldnames = ['id', 'name', 'domain', 'industry', 'headcount', 'revenue_range', 'location', 'apollo_score', 'last_updated', 'crm_status']
        with open('data/apollo_crm/crm_accounts.csv', 'w', newline='') as csvfile:
            writer = csv.DictWriter(csvfile, fieldnames=fieldnames)
            writer.writeheader()
            for account in accounts:
                writer.writerow({
                    'id': account.get('id', ''),
                    'name': account.get('name', ''),
                    'domain': account.get('domain', ''),
                    'industry': account.get('industry', ''),
                    'headcount': account.get('headcount', 0),
                    'revenue_range': account.get('revenue_range', ''),
                    'location': account.get('location', ''),
                    'apollo_score': account.get('apollo_score', 0.0),
                    'last_updated': account.get('last_updated', ''),
                    'crm_status': account.get('crm_status', 'prospect')
                })

        print('✅ CRM data converted to CSV')

except Exception as e:
    print(f'❌ Error converting data: {e}')
    sys.exit(1)
"

        # Load CSV into BigQuery
        bq --project_id="$PROJECT1" load \
            --source_format=CSV \
            --skip_leading_rows=1 \
            "$DATASET.crm_accounts" \
            "data/apollo_crm/crm_accounts.csv"

        echo -e "${GREEN}✅ Apollo CRM data loaded into BIMS${NC}"
    else
        echo -e "${YELLOW}⚠️  No Apollo CRM data found${NC}"
        echo "Run setup_apollo_crm.sh first"
    fi
}

# Function to create BIMS dashboards
create_bims_dashboards() {
    echo -e "${BLUE}[4/5] Creating BIMS dashboards...${NC}"

    # Create Looker Studio dashboard configuration
    cat > data/bims_dashboard_config.json << EOF
{
  "name": "Dominion OS BIMS Dashboard",
  "description": "Business Intelligence Management System with Apollo CRM data",
  "dataSources": [
    {
      "name": "CRM Accounts",
      "type": "BIGQUERY",
      "projectId": "$PROJECT1",
      "datasetId": "$DATASET",
      "tableId": "crm_accounts"
    },
    {
      "name": "Sales Pipeline",
      "type": "BIGQUERY",
      "projectId": "$PROJECT1",
      "datasetId": "$DATASET",
      "tableId": "sales_pipeline"
    },
    {
      "name": "Business Metrics",
      "type": "BIGQUERY",
      "projectId": "$PROJECT1",
      "datasetId": "$DATASET",
      "tableId": "business_metrics"
    }
  ],
  "charts": [
    {
      "name": "CRM Pipeline Overview",
      "type": "BAR_CHART",
      "dataSource": "CRM Accounts",
      "dimensions": ["industry"],
      "metrics": ["COUNT(id)"],
      "filters": [{"field": "crm_status", "operator": "EQUALS", "value": "prospect"}]
    },
    {
      "name": "Revenue by Industry",
      "type": "PIE_CHART",
      "dataSource": "CRM Accounts",
      "dimensions": ["industry"],
      "metrics": ["SUM(headcount)"]
    },
    {
      "name": "Apollo Score Distribution",
      "type": "HISTOGRAM",
      "dataSource": "CRM Accounts",
      "dimensions": ["apollo_score"],
      "metrics": ["COUNT(id)"]
    }
  ]
}
EOF

    echo -e "${GREEN}✅ BIMS dashboard configuration created${NC}"
    echo "Config saved to: data/bims_dashboard_config.json"
}

# Function to deploy BIMS service
deploy_bims_service() {
    echo -e "${BLUE}[5/5] Deploying BIMS service...${NC}"

    # Check if BIMS service exists
    bims_exists=$(gcloud run services list --project="$PROJECT1" \
        --format="value(metadata.name)" | grep -c "dominion-bims" || echo "0")

    if [ "$bims_exists" -eq "0" ]; then
        echo "Creating new dominion-bims service..."

        # Deploy BIMS service (placeholder - would need actual container)
        echo -e "${YELLOW}⚠️  BIMS service deployment placeholder${NC}"
        echo "Note: Actual deployment requires BIMS application container"
    else
        echo -e "${GREEN}✅ BIMS service already exists${NC}"
    fi
}

# Main execution
main() {
    echo "🎯 BIMS Optimization for Dominion OS Google Cloud"
    echo "================================================"
    echo "Integrating Apollo data for business intelligence"
    echo ""

    setup_bigquery_dataset
    create_bims_tables
    load_apollo_data
    create_bims_dashboards
    deploy_bims_service

    echo ""
    echo -e "${GREEN}🎉 BIMS Optimization Complete!${NC}"
    echo ""
    echo "BIMS Components:"
    echo "• BigQuery Dataset: $DATASET"
    echo "• Tables: crm_accounts, sales_pipeline, business_metrics"
    echo "• Dashboard Config: data/bims_dashboard_config.json"
    echo ""
    echo "Next steps:"
    echo "1. Deploy BIMS application container"
    echo "2. Configure Looker Studio dashboard"
    echo "3. Set up automated data refresh"
    echo "4. Test BI queries and reports"
}

# Run main function
main
