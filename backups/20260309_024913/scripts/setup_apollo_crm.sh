#!/bin/bash
# PHI Chief - Apollo CRM Integration & Optimization
# Purpose: Integrate real Apollo account data into Dominion OS CRM
# Target: Google Cloud CRM with sovereign data handling

set -e

echo "🔗 PHI CHIEF - APOLLO CRM INTEGRATION"
echo "===================================="
echo "Integrating real Apollo account data into Dominion OS CRM"
echo "Timestamp: $(date)"
echo ""

# Configuration
PROJECT1="dominion-os-1-0-main"
PROJECT2="dominion-core-prod"
REGION="us-central1"

# Apollo API Configuration (to be set via environment)
APOLLO_API_KEY="${APOLLO_API_KEY:-}"
APOLLO_BASE_URL="https://api.apollo.io/v1"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

# Function to check Apollo API connectivity
check_apollo_api() {
    echo -e "${BLUE}[1/4] Checking Apollo API connectivity...${NC}"

    if [ -z "$APOLLO_API_KEY" ]; then
        echo -e "${YELLOW}⚠️  APOLLO_API_KEY not set${NC}"
        echo "Please set your Apollo API key:"
        echo "export APOLLO_API_KEY='your_api_key_here'"
        echo ""
        echo "Get your API key from: https://app.apollo.io/#/settings/api"
        return 1
    fi

    # Test API connectivity
    response=$(curl -s -H "X-API-Key: $APOLLO_API_KEY" \
        "$APOLLO_BASE_URL/auth/health_check" 2>/dev/null || echo "error")

    if [ "$response" = "error" ]; then
        echo -e "${RED}❌ Apollo API connection failed${NC}"
        return 1
    else
        echo -e "${GREEN}✅ Apollo API connected${NC}"
        return 0
    fi
}

# Function to sync Apollo account data
sync_apollo_accounts() {
    echo -e "${BLUE}[2/4] Syncing Apollo account data...${NC}"

    # Create data directory
    mkdir -p data/apollo_crm

    # Fetch account data (example query)
    # Note: Replace with actual Apollo API endpoints and parameters
    curl -s -H "X-API-Key: $APOLLO_API_KEY" \
        -H "Content-Type: application/json" \
        -d '{
            "q_keywords": "technology software",
            "page": 1,
            "per_page": 100
        }' \
        "$APOLLO_BASE_URL/organizations/search" \
        > data/apollo_crm/accounts_raw.json

    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✅ Apollo account data synced${NC}"
        echo "Data saved to: data/apollo_crm/accounts_raw.json"
    else
        echo -e "${RED}❌ Failed to sync Apollo data${NC}"
        return 1
    fi
}

# Function to optimize CRM data structure
optimize_crm_data() {
    echo -e "${BLUE}[3/4] Optimizing CRM data structure...${NC}"

    # Process raw Apollo data into CRM format
    python3 -c "
import json
import sys

try:
    with open('data/apollo_crm/accounts_raw.json', 'r') as f:
        raw_data = json.load(f)

    # Transform Apollo data to CRM format
    crm_accounts = []
    if 'organizations' in raw_data:
        for org in raw_data['organizations']:
            crm_account = {
                'id': org.get('id'),
                'name': org.get('name'),
                'domain': org.get('primary_domain'),
                'industry': org.get('industry'),
                'headcount': org.get('employee_count'),
                'revenue_range': org.get('revenue_range'),
                'location': org.get('city', '') + ', ' + org.get('state', '') if org.get('city') else org.get('country', ''),
                'apollo_score': org.get('account_score'),
                'last_updated': org.get('updated_at'),
                'crm_status': 'prospect',
                'tags': ['apollo_import', 'technology']
            }
            crm_accounts.append(crm_account)

    # Save processed data
    with open('data/apollo_crm/crm_accounts.json', 'w') as f:
        json.dump(crm_accounts, f, indent=2)

    print(f'✅ Processed {len(crm_accounts)} CRM accounts')

except Exception as e:
    print(f'❌ Error processing CRM data: {e}')
    sys.exit(1)
"

    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✅ CRM data optimized${NC}"
    else
        echo -e "${RED}❌ CRM optimization failed${NC}"
        return 1
    fi
}

# Function to deploy CRM service
deploy_crm_service() {
    echo -e "${BLUE}[4/4] Deploying CRM service to Google Cloud...${NC}"

    # Check if CRM service exists
    crm_exists=$(gcloud run services list --project="$PROJECT1" \
        --format="value(metadata.name)" | grep -c "dominion-crm" || echo "0")

    if [ "$crm_exists" -eq "0" ]; then
        echo "Creating new dominion-crm service..."

        # Deploy CRM service (placeholder - would need actual container)
        # gcloud run deploy dominion-crm \
        #     --project="$PROJECT1" \
        #     --region="$REGION" \
        #     --source=. \
        #     --allow-unauthenticated \
        #     --memory=1Gi \
        #     --cpu=1

        echo -e "${YELLOW}⚠️  CRM service deployment placeholder${NC}"
        echo "Note: Actual deployment requires CRM application container"
    else
        echo -e "${GREEN}✅ CRM service already exists${NC}"
    fi
}

# Main execution
main() {
    echo "🎯 Apollo CRM Integration for Dominion OS"
    echo "=========================================="
    echo "Using real Apollo account data for CRM optimization"
    echo ""

    check_apollo_api
    if [ $? -ne 0 ]; then
        echo -e "${RED}❌ Apollo API setup required. Exiting.${NC}"
        exit 1
    fi

    sync_apollo_accounts
    optimize_crm_data
    deploy_crm_service

    echo ""
    echo -e "${GREEN}🎉 Apollo CRM Integration Complete!${NC}"
    echo ""
    echo "Next steps:"
    echo "1. Review CRM data: data/apollo_crm/crm_accounts.json"
    echo "2. Configure CRM service endpoints"
    echo "3. Set up BIMS integration"
    echo "4. Test CRM functionality"
}

# Run main function
main
