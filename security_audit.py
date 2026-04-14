#!/usr/bin/env python3
"""
PHI Chief AI Security Audit Tool
Comprehensive security analysis and fixes
"""

import os
import json
import hashlib
from pathlib import Path
from typing import Dict, List, Set

def calculate_file_hash(filepath: str) -> str:
    """Calculate SHA256 hash of file"""
    sha256 = hashlib.sha256()
    try:
        with open(filepath, 'rb') as f:
            for chunk in iter(lambda: f.read(4096), b""):
                sha256.update(chunk)
        return sha256.hexdigest()
    except (IOError, OSError):
        return "ERROR"

def audit_file_permissions() -> Dict[str, List[str]]:
    """Audit file permissions for security issues"""
    issues = {"world_writable": [], "executable_scripts": []}

    for root, dirs, files in os.walk("/workspaces/dominion-os-demo-build"):
        for file in files:
            filepath = os.path.join(root, file)
            try:
                stat = os.stat(filepath)
                # Check for world-writable files
                if stat.st_mode & 0o002:
                    issues["world_writable"].append(filepath)

                # Check for potentially dangerous executable files
                if stat.st_mode & 0o111 and not file.endswith(('.sh', '.py', '.exe')):
                    issues["executable_scripts"].append(filepath)
            except OSError:
                continue

    return issues

def audit_sensitive_data() -> Dict[str, List[str]]:
    """Audit for potential sensitive data exposure"""
    sensitive_patterns = [
        r'password\s*[:=]\s*["\'][^"\']+["\']',
        r'secret\s*[:=]\s*["\'][^"\']+["\']',
        r'key\s*[:=]\s*["\'][^"\']+["\']',
        r'token\s*[:=]\s*["\'][^"\']+["\']',
    ]

    issues = {"potential_secrets": []}

    for root, dirs, files in os.walk("/workspaces/dominion-os-demo-build"):
        for file in files:
            if file.endswith(('.py', '.sh', '.md', '.json', '.yaml', '.yml')):
                filepath = os.path.join(root, file)
                try:
                    with open(filepath, 'r', encoding='utf-8', errors='ignore') as f:
                        content = f.read()
                        for pattern in sensitive_patterns:
                            import re
                            if re.search(pattern, content, re.IGNORECASE):
                                issues["potential_secrets"].append(filepath)
                                break
                except (IOError, OSError, UnicodeDecodeError):
                    continue

    return issues

def generate_security_report() -> Dict:
    """Generate comprehensive security report"""
    report = {
        "timestamp": "2026-03-02T17:15:00Z",
        "sovereign_authority": "PHI Chief AI",
        "audit_type": "comprehensive_security_audit",
        "file_permissions": audit_file_permissions(),
        "sensitive_data": audit_sensitive_data(),
        "recommendations": []
    }

    # Generate recommendations
    if report["file_permissions"]["world_writable"]:
        report["recommendations"].append("Fix world-writable file permissions")

    if report["file_permissions"]["executable_scripts"]:
        report["recommendations"].append("Review executable file permissions")

    if report["sensitive_data"]["potential_secrets"]:
        report["recommendations"].append("Review potential sensitive data exposure")

    return report

if __name__ == "__main__":
    report = generate_security_report()
    with open("security_audit_report.json", "w") as f:
        json.dump(report, f, indent=2)

    print("✅ PHI Chief AI Security Audit Complete")
    print(f"📊 Report saved to: security_audit_report.json")
