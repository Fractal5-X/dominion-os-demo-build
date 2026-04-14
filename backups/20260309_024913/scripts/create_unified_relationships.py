#!/usr/bin/env python3
# -*- coding: utf-8 -*-
# -*- coding: utf-8 -*-
# -*- coding: utf-8 -*-
"""
Unified Relationship Database Creator
Combines data from Apollo, Gmail, Google Drive, and Dropbox
"""

import json
from collections import defaultdict
from datetime import datetime
from typing import Any, Dict, List


def load_data_sources() -> Dict[str, Any]:
    """Load data from all sources"""
    sources = {}

    # Load Apollo CRM data
    try:
        with open("data/apollo_crm/crm_accounts.json", "r") as f:
            sources["apollo"] = json.load(f)
    except (FileNotFoundError, json.JSONDecodeError):
        sources["apollo"] = []

    # Load Gmail contacts
    try:
        with open("data/gmail_contacts/contacts.json", "r") as f:
            sources["gmail"] = json.load(f)
    except (FileNotFoundError, json.JSONDecodeError):
        sources["gmail"] = {}

    # Load Google Drive documents
    try:
        with open("data/google_drive/documents.json", "r") as f:
            sources["google_drive"] = json.load(f)
    except (FileNotFoundError, json.JSONDecodeError):
        sources["google_drive"] = []

    # Load Dropbox files
    try:
        with open("data/dropbox_drive/files.json", "r") as f:
            sources["dropbox"] = json.load(f)
    except (FileNotFoundError, json.JSONDecodeError):
        sources["dropbox"] = []

    return sources


def create_unified_relationships(sources: Dict[str, Any]) -> List[Dict[str, Any]]:
    """Create unified relationship database"""
    relationships = defaultdict(
        lambda: {
            "entity_id": "",
            "entity_name": "",
            "entity_type": "",
            "email": "",
            "domain": "",
            "apollo_data": {},
            "gmail_data": {},
            "drive_data": [],
            "dropbox_data": [],
            "relationship_score": 0,
            "last_interaction": None,
            "interaction_count": 0,
            "data_sources": [],
            "tags": [],
            "notes": "",
        }
    )

    # Process Apollo data
    for account in sources["apollo"]:
        email = account.get("email", "").lower()
        domain = account.get("domain", "")

        if email:
            rel = relationships[email]
            rel["entity_id"] = account.get("account_id", "")
            rel["entity_name"] = account.get("account_name", "")
            rel["entity_type"] = "company"
            rel["email"] = email
            rel["domain"] = domain
            rel["apollo_data"] = account
            rel["relationship_score"] += account.get("apollo_score", 0) * 10
            rel["data_sources"].append("apollo")

    # Process Gmail data
    for email, contact in sources["gmail"].items():
        email = email.lower()
        rel = relationships[email]

        if not rel["entity_name"]:
            rel["entity_name"] = contact.get("name", "")
        if not rel["domain"] and "@" in email:
            rel["domain"] = email.split("@")[1]

        rel["gmail_data"] = contact
        rel["interaction_count"] += contact.get("interaction_count", 0)
        rel["relationship_score"] += contact.get("interaction_count", 0) * 2
        rel["data_sources"].append("gmail")

        # Update last interaction
        last_contact = contact.get("last_contact")
        if last_contact:
            if isinstance(last_contact, str):
                last_contact = datetime.fromisoformat(last_contact.replace("Z", "+00:00"))
            if not rel["last_interaction"] or last_contact > rel["last_interaction"]:
                rel["last_interaction"] = last_contact

    # Process Google Drive data
    for doc in sources["google_drive"]:
        for email in doc.get("shared_with", []):
            email = email.lower()
            rel = relationships[email]
            rel["drive_data"].append(doc)
            rel["relationship_score"] += 5  # Points for document sharing
            if "google_drive" not in rel["data_sources"]:
                rel["data_sources"].append("google_drive")

    # Process Dropbox data
    for file in sources["dropbox"]:
        for email in file.get("shared_with", []):
            email = email.lower()
            rel = relationships[email]
            rel["dropbox_data"].append(file)
            rel["relationship_score"] += 3  # Points for file sharing
            if "dropbox" not in rel["data_sources"]:
                rel["data_sources"].append("dropbox")

    # Convert to list and add metadata
    unified_relationships = []
    for email, rel in relationships.items():
        rel["entity_id"] = rel["entity_id"] or f"contact_{hash(email) % 1000000}"
        rel["last_updated"] = datetime.now().isoformat()
        unified_relationships.append(dict(rel))

    # Sort by relationship score
    unified_relationships.sort(key=lambda x: x["relationship_score"], reverse=True)

    return unified_relationships


def save_unified_relationships(relationships: List[Dict[str, Any]], output_file: str):
    """Save unified relationships database"""
    with open(output_file, "w") as f:
        json.dump(relationships, f, indent=2, default=str)


def generate_relationship_report(relationships: List[Dict[str, Any]], report_file: str):
    """Generate relationship analysis report"""
    total_relationships = len(relationships)
    high_value = len([r for r in relationships if r["relationship_score"] > 50])
    active_contacts = len([r for r in relationships if r["interaction_count"] > 0])

    report = {
        "generated_at": datetime.now().isoformat(),
        "summary": {
            "total_relationships": total_relationships,
            "high_value_relationships": high_value,
            "active_contacts": active_contacts,
            "data_sources": ["apollo", "gmail", "google_drive", "dropbox"],
        },
        "top_relationships": relationships[:10],
        "source_breakdown": {
            "apollo_companies": len([r for r in relationships if "apollo" in r["data_sources"]]),
            "gmail_contacts": len([r for r in relationships if "gmail" in r["data_sources"]]),
            "drive_shared": len([r for r in relationships if "google_drive" in r["data_sources"]]),
            "dropbox_shared": len([r for r in relationships if "dropbox" in r["data_sources"]]),
        },
    }

    with open(report_file, "w") as f:
        json.dump(report, f, indent=2, default=str)


def main():
    print("Creating unified relationship database...")

    # Load all data sources
    sources = load_data_sources()

    # Create unified relationships
    relationships = create_unified_relationships(sources)

    # Save unified database
    save_unified_relationships(relationships, "data/unified_relationships.json")

    # Generate report
    generate_relationship_report(relationships, "reports/relationship_analysis.json")

    print(f"✅ Created unified database with {len(relationships)} relationships")
    print("   Database saved to: data/unified_relationships.json")
    print("   Report saved to: reports/relationship_analysis.json")


if __name__ == "__main__":
    main()
