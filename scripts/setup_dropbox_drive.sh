#!/bin/bash
# Dropbox Drive Integration for Dominion OS

echo "📦 Setting up Dropbox Drive integration..."

# Create Dropbox configuration
cat > data/dropbox_drive/dropbox_config.json << EOF
{
  "name": "Dropbox Drive Integration",
  "description": "Harvest files and documents from Dropbox",
  "api_scopes": [
    "files.content.read",
    "files.metadata.read"
  ],
  "sync_schedule": "0 */6 * * *",
  "file_types": [
    "pdf",
    "doc",
    "docx",
    "txt",
    "xlsx",
    "pptx"
  ],
  "max_file_size_mb": 10,
  "content_extraction": {
    "extract_text": true,
    "extract_metadata": true
  }
}
EOF

echo "✅ Dropbox Drive integration configured"
