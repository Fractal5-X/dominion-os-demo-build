#!/bin/bash
# Google Drive Integration for Dominion OS

echo "📁 Setting up Google Drive integration..."

# Create Google Drive configuration
cat > data/google_drive/drive_config.json << EOF
{
  "name": "Google Drive Integration",
  "description": "Harvest documents and files from Google Drive",
  "api_scopes": [
    "https://www.googleapis.com/auth/drive.readonly"
  ],
  "sync_schedule": "0 */6 * * *",
  "file_types": [
    "application/pdf",
    "application/vnd.google-apps.document",
    "application/vnd.google-apps.spreadsheet",
    "text/plain",
    "application/msword"
  ],
  "max_file_size_mb": 10,
  "content_extraction": {
    "extract_text": true,
    "extract_metadata": true,
    "ocr_enabled": false
  }
}
EOF

echo "✅ Google Drive integration configured"
