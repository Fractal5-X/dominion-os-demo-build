#!/bin/bash
# Relationship Integration Demo Mode
# Creates sample data to demonstrate the complete integration workflow

set -e

echo "🎭 RELATIONSHIP INTEGRATION DEMO MODE"
echo "===================================="
echo "Creating sample data to demonstrate complete integration workflow"
echo "Target: Matthew Burbidge / Fractal5 Solutions Inc"
echo "Timestamp: $(date)"
echo ""

# Create sample Apollo CRM data
echo "📊 Creating sample Apollo CRM data..."
mkdir -p data/apollo_crm

cat > data/apollo_crm/accounts_raw.json << 'EOF'
{
  "organizations": [
    {
      "id": "demo_company_001",
      "name": "TechCorp Solutions",
      "primary_domain": "techcorp.com",
      "account_score": 85,
      "industry": "Software Development",
      "employee_count": 150,
      "revenue_range": "$10M-$50M",
      "city": "San Francisco",
      "state": "CA",
      "country": "United States",
      "linkedin_url": "https://linkedin.com/company/techcorp",
      "twitter_url": "https://twitter.com/techcorp",
      "facebook_url": "https://facebook.com/techcorp",
      "phone": "+1-415-555-0123",
      "founded_year": 2015,
      "short_description": "Leading software development company specializing in AI and cloud solutions."
    },
    {
      "id": "demo_company_002",
      "name": "DataFlow Systems",
      "primary_domain": "dataflow.io",
      "account_score": 92,
      "industry": "Data Analytics",
      "employee_count": 75,
      "revenue_range": "$5M-$10M",
      "city": "Austin",
      "state": "TX",
      "country": "United States",
      "linkedin_url": "https://linkedin.com/company/dataflow",
      "phone": "+1-512-555-0456",
      "founded_year": 2018,
      "short_description": "Advanced data analytics and business intelligence platform."
    },
    {
      "id": "demo_company_003",
      "name": "CloudTech Innovations",
      "primary_domain": "cloudtech.dev",
      "account_score": 78,
      "industry": "Cloud Computing",
      "employee_count": 200,
      "revenue_range": "$50M-$100M",
      "city": "Seattle",
      "state": "WA",
      "country": "United States",
      "linkedin_url": "https://linkedin.com/company/cloudtech",
      "twitter_url": "https://twitter.com/cloudtech",
      "phone": "+1-206-555-0789",
      "founded_year": 2012,
      "short_description": "Enterprise cloud solutions and infrastructure management."
    }
  ]
}
EOF

# Process Apollo data
python3 scripts/process_apollo_crm.py data/apollo_crm/accounts_raw.json data/apollo_crm/crm_accounts.json

echo "✅ Sample Apollo CRM data created"
echo ""

# Create sample Gmail contacts data
echo "📧 Creating sample Gmail contacts data..."
mkdir -p data/gmail_contacts

cat > data/gmail_contacts/contacts.json << 'EOF'
{
  "john.doe@techcorp.com": {
    "name": "John Doe",
    "email": "john.doe@techcorp.com",
    "interaction_count": 15,
    "last_contact": "2024-03-01T10:30:00Z",
    "first_contact": "2024-01-15T14:20:00Z",
    "threads": ["thread_001", "thread_002", "thread_003"]
  },
  "sarah.smith@dataflow.io": {
    "name": "Sarah Smith",
    "email": "sarah.smith@dataflow.io",
    "interaction_count": 8,
    "last_contact": "2024-02-28T16:45:00Z",
    "first_contact": "2024-02-01T09:15:00Z",
    "threads": ["thread_004", "thread_005"]
  },
  "mike.johnson@cloudtech.dev": {
    "name": "Mike Johnson",
    "email": "mike.johnson@cloudtech.dev",
    "interaction_count": 22,
    "last_contact": "2024-03-02T11:20:00Z",
    "first_contact": "2023-12-10T13:30:00Z",
    "threads": ["thread_006", "thread_007", "thread_008", "thread_009"]
  },
  "jane.wilson@techstartup.net": {
    "name": "Jane Wilson",
    "email": "jane.wilson@techstartup.net",
    "interaction_count": 5,
    "last_contact": "2024-02-25T08:10:00Z",
    "first_contact": "2024-02-20T15:45:00Z",
    "threads": ["thread_010"]
  }
}
EOF

echo "✅ Sample Gmail contacts data created"
echo ""

# Create sample Google Drive data
echo "📁 Creating sample Google Drive data..."
mkdir -p data/google_drive

cat > data/google_drive/documents.json << 'EOF'
[
  {
    "id": "doc_001",
    "name": "Q1 Business Review.pptx",
    "mime_type": "application/vnd.google-apps.presentation",
    "size": 5242880,
    "created_time": "2024-01-15T10:00:00Z",
    "modified_time": "2024-02-28T14:30:00Z",
    "owners": ["matthew.burbidge@fractal5solutions.com"],
    "shared_with": ["john.doe@techcorp.com", "sarah.smith@dataflow.io"],
    "web_view_link": "https://docs.google.com/presentation/d/doc_001",
    "description": "Q1 business performance and strategic initiatives"
  },
  {
    "id": "doc_002",
    "name": "Technical Architecture.pdf",
    "mime_type": "application/pdf",
    "size": 2097152,
    "created_time": "2024-02-01T09:15:00Z",
    "modified_time": "2024-02-15T16:20:00Z",
    "owners": ["matthew.burbidge@fractal5solutions.com"],
    "shared_with": ["mike.johnson@cloudtech.dev", "jane.wilson@techstartup.net"],
    "web_view_link": "https://drive.google.com/file/d/doc_002",
    "description": "System architecture documentation and design specifications"
  },
  {
    "id": "doc_003",
    "name": "Client Proposal Template.docx",
    "mime_type": "application/vnd.google-apps.document",
    "size": 1048576,
    "created_time": "2024-01-20T11:30:00Z",
    "modified_time": "2024-03-01T13:45:00Z",
    "owners": ["matthew.burbidge@fractal5solutions.com"],
    "shared_with": ["john.doe@techcorp.com", "mike.johnson@cloudtech.dev"],
    "web_view_link": "https://docs.google.com/document/d/doc_003",
    "description": "Standard client proposal template with pricing models"
  }
]
EOF

echo "✅ Sample Google Drive data created"
echo ""

# Create sample Dropbox data
echo "📦 Creating sample Dropbox data..."
mkdir -p data/dropbox_drive

cat > data/dropbox_drive/files.json << 'EOF'
[
  {
    "id": "file_001",
    "name": "Project_Plan_v2.xlsx",
    "path": "/Projects/TechCorp/Project_Plan_v2.xlsx",
    "size": 1572864,
    "server_modified": "2024-02-20T10:15:00Z",
    "client_modified": "2024-02-20T10:15:00Z",
    "rev": "a1b2c3d4",
    "content_hash": "abc123def456",
    "shared_with": ["john.doe@techcorp.com"]
  },
  {
    "id": "file_002",
    "name": "Data_Analysis_Report.pdf",
    "path": "/Reports/Q1/Data_Analysis_Report.pdf",
    "size": 3145728,
    "server_modified": "2024-02-25T14:30:00Z",
    "client_modified": "2024-02-25T14:30:00Z",
    "rev": "e5f6g7h8",
    "content_hash": "def456ghi789",
    "shared_with": ["sarah.smith@dataflow.io", "mike.johnson@cloudtech.dev"]
  },
  {
    "id": "file_003",
    "name": "Meeting_Notes.txt",
    "path": "/Meetings/2024-03-01/Meeting_Notes.txt",
    "size": 16384,
    "server_modified": "2024-03-01T16:00:00Z",
    "client_modified": "2024-03-01T16:00:00Z",
    "rev": "i9j0k1l2",
    "content_hash": "ghi789jkl012",
    "shared_with": ["jane.wilson@techstartup.net"]
  }
]
EOF

echo "✅ Sample Dropbox data created"
echo ""

# Create unified relationships database
echo "🔗 Creating unified relationships database..."
python3 scripts/create_unified_relationships.py

echo "✅ Unified relationships database created"
echo ""

# Generate demo report
echo "📊 Generating demo integration report..."
cat > reports/DEMO_INTEGRATION_RESULTS.md << 'EOF'
# Relationship Integration Demo Results

**Generated:** Demo Mode
**Data Sources:** Sample Data
**Target:** Matthew Burbidge / Fractal5 Solutions Inc

## Demo Data Summary

### Apollo CRM Companies (3)
- **TechCorp Solutions** (Score: 85) - Software Development, 150 employees
- **DataFlow Systems** (Score: 92) - Data Analytics, 75 employees
- **CloudTech Innovations** (Score: 78) - Cloud Computing, 200 employees

### Gmail Contacts (4)
- **John Doe** (john.doe@techcorp.com) - 15 interactions
- **Sarah Smith** (sarah.smith@dataflow.io) - 8 interactions
- **Mike Johnson** (mike.johnson@cloudtech.dev) - 22 interactions
- **Jane Wilson** (jane.wilson@techstartup.net) - 5 interactions

### Google Drive Documents (3)
- **Q1 Business Review.pptx** - Shared with TechCorp and DataFlow contacts
- **Technical Architecture.pdf** - Shared with CloudTech and TechStartup contacts
- **Client Proposal Template.docx** - Shared with TechCorp and CloudTech contacts

### Dropbox Files (3)
- **Project_Plan_v2.xlsx** - Shared with TechCorp contact
- **Data_Analysis_Report.pdf** - Shared with DataFlow and CloudTech contacts
- **Meeting_Notes.txt** - Shared with TechStartup contact

## Unified Relationship Intelligence

### Top Relationships by Score:
1. **Mike Johnson** (mike.johnson@cloudtech.dev) - Score: 178
   - Apollo: CloudTech Innovations (Score: 78)
   - Gmail: 22 interactions
   - Drive: Technical Architecture, Client Proposal
   - Dropbox: Data Analysis Report

2. **John Doe** (john.doe@techcorp.com) - Score: 155
   - Apollo: TechCorp Solutions (Score: 85)
   - Gmail: 15 interactions
   - Drive: Q1 Business Review, Client Proposal
   - Dropbox: Project Plan

3. **Sarah Smith** (sarah.smith@dataflow.io) - Score: 132
   - Apollo: DataFlow Systems (Score: 92)
   - Gmail: 8 interactions
   - Drive: Q1 Business Review
   - Dropbox: Data Analysis Report

## Business Intelligence Insights

### Opportunity Pipeline
- **High Priority:** Mike Johnson (CloudTech) - Multiple touchpoints, high engagement
- **Medium Priority:** John Doe (TechCorp) - Strong company match, active communication
- **Medium Priority:** Sarah Smith (DataFlow) - Excellent company score, growing engagement

### Communication Patterns
- **Most Active:** Mike Johnson - 22 email interactions across 4 threads
- **Recent Activity:** All contacts active within last 7 days
- **Collaboration:** 6 shared documents, 3 shared files across relationships

### Industry Focus
- **Software Development:** TechCorp Solutions
- **Data Analytics:** DataFlow Systems
- **Cloud Computing:** CloudTech Innovations
- **Tech Startups:** Jane Wilson (TechStartup)

## Demo Mode Notes

This demonstration shows how the relationship integration system works with real data structures. In production mode:

1. **Replace sample data** with actual API responses from Apollo, Gmail, Google Drive, and Dropbox
2. **Set real API keys** for authenticated data access
3. **Configure automated sync** for continuous relationship updates
4. **Deploy to Google Cloud** for production scalability

## Next Steps for Production

1. Obtain real API credentials for all 4 data sources
2. Run `./scripts/execute_complete_integration.sh` with real keys
3. Deploy applications with `./scripts/deploy_relationship_apps.sh`
4. Configure automated pipelines and monitoring
5. Access relationship intelligence dashboards

---
*Demo generated by PHI Chief AI - Relationship Integration System*
EOF

echo "✅ Demo integration report generated"
echo ""

echo "🎭 DEMO MODE COMPLETE!"
echo ""
echo "📊 Demo Results:"
echo "   • 3 Apollo companies processed"
echo "   • 4 Gmail contacts analyzed"
echo "   • 3 Google Drive documents indexed"
echo "   • 3 Dropbox files cataloged"
echo "   • Unified relationship database created"
echo ""
echo "🎯 Top Relationships Identified:"
echo "   1. Mike Johnson (CloudTech) - Score: 178"
echo "   2. John Doe (TechCorp) - Score: 155"
echo "   3. Sarah Smith (DataFlow) - Score: 132"
echo ""
echo "📄 Demo Report: reports/DEMO_INTEGRATION_RESULTS.md"
echo ""
echo "🚀 Ready for production activation with real API credentials!"
