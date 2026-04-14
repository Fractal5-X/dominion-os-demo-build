#!/usr/bin/env python3
# -*- coding: utf-8 -*-
# -*- coding: utf-8 -*-
# -*- coding: utf-8 -*-
"""
Apollo CRM Data Processor
Processes raw Apollo account data into CRM-compatible format
"""

import csv
import json
import sys
from datetime import datetime
from typing import Any, Dict, List


def load_apollo_data(input_file: str) -> Dict[str, Any]:
    """Load raw Apollo API response data"""
    try:
        with open(input_file, "r") as f:
            return json.load(f)
    except FileNotFoundError:
        print(f"Error: Input file {input_file} not found")
        sys.exit(1)
    except json.JSONDecodeError as e:
        print(f"Error: Invalid JSON in {input_file}: {e}")
        sys.exit(1)


def transform_account_data(apollo_data: Dict[str, Any]) -> List[Dict[str, Any]]:
    """Transform Apollo account data to CRM format"""
    crm_accounts = []

    organizations = apollo_data.get("organizations", [])

    for org in organizations:
        # Extract key account information
        account = {
            "account_id": org.get("id", ""),
            "account_name": org.get("name", ""),
            "domain": org.get("primary_domain", ""),
            "apollo_score": org.get("account_score", 0),
            "industry": org.get("industry", ""),
            "headcount": org.get("employee_count", 0),
            "revenue_range": org.get("revenue_range", ""),
            "city": org.get("city", ""),
            "state": org.get("state", ""),
            "country": org.get("country", ""),
            "linkedin_url": org.get("linkedin_url", ""),
            "twitter_url": org.get("twitter_url", ""),
            "facebook_url": org.get("facebook_url", ""),
            "phone": org.get("phone", ""),
            "founded_year": org.get("founded_year", ""),
            "description": org.get("short_description", ""),
            "last_updated": datetime.now().isoformat(),
            "data_source": "apollo_api",
        }

        # Add to CRM accounts list
        crm_accounts.append(account)

    return crm_accounts


def save_crm_data(crm_accounts: List[Dict[str, Any]], output_file: str):
    """Save CRM data as JSON"""
    with open(output_file, "w") as f:
        json.dump(crm_accounts, f, indent=2)


def save_csv_data(crm_accounts: List[Dict[str, Any]], csv_file: str):
    """Save CRM data as CSV for BigQuery import"""
    if not crm_accounts:
        print("Warning: No account data to save")
        return

    fieldnames = crm_accounts[0].keys()

    with open(csv_file, "w", newline="") as f:
        writer = csv.DictWriter(f, fieldnames=fieldnames)
        writer.writeheader()
        writer.writerows(crm_accounts)


def main():
    if len(sys.argv) != 3:
        print("Usage: python process_apollo_crm.py <input_json> <output_json>")
        sys.exit(1)

    input_file = sys.argv[1]
    output_file = sys.argv[2]
    csv_file = output_file.replace(".json", ".csv")

    print(f"Processing Apollo CRM data from {input_file}")

    # Load and transform data
    apollo_data = load_apollo_data(input_file)
    crm_accounts = transform_account_data(apollo_data)

    # Save processed data
    save_crm_data(crm_accounts, output_file)
    save_csv_data(crm_accounts, csv_file)

    print(f"✅ Processed {len(crm_accounts)} CRM accounts")
    print(f"   JSON saved to: {output_file}")
    print(f"   CSV saved to: {csv_file}")


if __name__ == "__main__":
    main()
