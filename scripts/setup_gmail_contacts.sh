#!/bin/bash
# Gmail Contacts Integration for Dominion OS

echo "📧 Setting up Gmail contacts integration..."

# Create Gmail contacts configuration
cat > data/gmail_contacts/gmail_config.json << EOF
{
  "name": "Gmail Contacts Integration",
  "description": "Harvest email contacts and communication data from Gmail",
  "api_scopes": [
    "https://www.googleapis.com/auth/gmail.readonly",
    "https://www.googleapis.com/auth/contacts.readonly"
  ],
  "sync_schedule": "0 */4 * * *",
  "data_retention_days": 365,
  "contact_filters": {
    "min_interactions": 3,
    "date_range": "1 year",
    "exclude_domains": ["noreply", "notification", "alert"]
  }
}
EOF

echo "✅ Gmail contacts integration configured"
