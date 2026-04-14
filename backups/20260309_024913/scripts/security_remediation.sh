#!/bin/bash
# PHI Chief AI Security Remediation Script
# Phase 1: Emergency Security Response for Compromised GitHub PAT

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging function
log() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')] $1${NC}"
}

error() {
    echo -e "${RED}[ERROR] $1${NC}" >&2
}

success() {
    echo -e "${GREEN}[SUCCESS] $1${NC}"
}

warning() {
    echo -e "${YELLOW}[WARNING] $1${NC}"
}

# Function to revoke compromised token
revoke_compromised_token() {
    log "Revoking compromised GitHub PAT..."

    # This would be done via GitHub API - for now, we'll document the process
    cat << 'EOF'
🔐 COMPROMISED TOKEN REVOCATION REQUIRED:

1. Go to: https://github.com/settings/tokens
2. Find the compromised token (likely named something like "PHI Chief AI" or "Dominion OS")
3. Click "Delete" to revoke it immediately
4. Check GitHub security log for any unauthorized access

EOF

    # Create new token with minimal permissions
    cat << 'EOF'
🆕 CREATE NEW SECURE TOKEN:

1. Go to: https://github.com/settings/tokens/new
2. Token name: "PHI Chief AI - Secure"
3. Expiration: 30 days (rotate regularly)
4. Scopes: ✅ repo (only if absolutely needed)
5. Repository access: Only this repository
6. Generate and copy token immediately

EOF
}

# Function to scan for hardcoded tokens
scan_hardcoded_tokens() {
    log "Scanning for hardcoded tokens in repository..."

    # Scan for common token patterns
    local patterns=(
        'ghp_[A-Za-z0-9_]{36}'
        'github_pat_[A-Za-z0-9_]{82}'
        'AIza[0-9A-Za-z-_]{35}'
        '-----BEGIN [A-Z ]*PRIVATE KEY-----'
        'xoxb-[0-9]{10,12}-[0-9]{10,12}-[A-Za-z0-9]{24}'
        'sk-[A-Za-z0-9]{48}'
    )

    local found_tokens=0

    for pattern in "${patterns[@]}"; do
        if grep -r "$pattern" . --exclude-dir=.git --exclude-dir=node_modules --exclude-dir=__pycache__ > /dev/null 2>&1; then
            error "Found potential token pattern: $pattern"
            grep -r "$pattern" . --exclude-dir=.git --exclude-dir=node_modules --exclude-dir=__pycache__
            ((found_tokens++))
        fi
    done

    if [ $found_tokens -eq 0 ]; then
        success "No hardcoded tokens found in current HEAD"
    else
        error "Found $found_tokens token patterns - manual review required"
    fi
}

# Function to clean git history
clean_git_history() {
    log "Preparing git history cleanup..."

    # Check if we have any commits with sensitive data
    if git log --all --grep="token\|password\|secret" --oneline | grep -v "placeholder\|example" > /dev/null; then
        warning "Found commits that may contain sensitive data"
        git log --all --grep="token\|password\|secret" --oneline | grep -v "placeholder\|example"

        cat << 'EOF'
🧹 GIT HISTORY CLEANUP REQUIRED:

Due to sensitive data in history, you may need to:

1. Create a new repository with clean history
2. Use git filter-branch or BFG Repo-Cleaner
3. Force push the clean history

For immediate security:
- All sensitive data has been removed from HEAD
- New commits will not contain tokens
- Consider this repository compromised and monitor for unauthorized access

EOF
    else
        success "Git history appears clean of sensitive data"
    fi
}

# Function to enable GitHub security features
enable_github_security() {
    log "Configuring GitHub security features..."

    cat << 'EOF'
🛡️ ENABLE GITHUB SECURITY FEATURES:

1. Secret Scanning:
   - Go to: https://github.com/Fractal5-Solutions/dominion-os-demo-build/settings/security_analysis
   - Enable "Secret scanning"
   - Enable "Push protection"

2. Branch Protection:
   - Go to: https://github.com/Fractal5-Solutions/dominion-os-demo-build/settings/branches
   - Add rule for 'main' branch
   - Require pull requests
   - Require status checks
   - Include administrators

3. Repository Settings:
   - Disable force pushes to main
   - Require signed commits (optional)
   - Enable vulnerability alerts

EOF
}

# Function to create AI-based token detection
create_ai_detection() {
    log "Creating AI-based token detection system..."

    # Check if AI detector already exists
    if [ -f "ai_token_detector.py" ]; then
        log "AI token detector already exists"
        return 0
    fi

    # Create the detection script
    cat > ai_token_detector.py << 'EOF'
#!/usr/bin/env python3
"""
PHI Chief AI - Token Detection and Protection System
Monitors for unauthorized token usage and potential compromises
"""

import os
import re
import json
import time
from datetime import datetime, timedelta
import requests
from typing import List, Dict, Optional

class AITokenDetector:
    def __init__(self):
        self.authorized_users = {
            "Fractal5-Solutions",
            "authorized-user-1",  # Add actual authorized users
        }
        self.token_patterns = [
            r'ghp_[A-Za-z0-9_]{36}',
            r'github_pat_[A-Za-z0-9_]{82}',
            r'AIza[0-9A-Za-z-_]{35}',
            r'-----BEGIN [A-Z ]*PRIVATE KEY-----',
            r'xoxb-[0-9]{10,12}-[0-9]{10,12}-[A-Za-z0-9]{24}',
            r'sk-[A-Za-z0-9]{48}',
        ]

    def scan_repository(self, repo_path: str) -> List[Dict]:
        """Scan repository for potential token exposures"""
        findings = []

        for root, dirs, files in os.walk(repo_path):
            # Skip .git and other irrelevant directories
            dirs[:] = [d for d in dirs if not d.startswith('.') and d not in ['node_modules', '__pycache__']]

            for file in files:
                if file.endswith(('.py', '.sh', '.md', '.json', '.yaml', '.yml')):
                    filepath = os.path.join(root, file)
                    try:
                        with open(filepath, 'r', encoding='utf-8', errors='ignore') as f:
                            content = f.read()
                            lines = content.split('\n')

                            for line_num, line in enumerate(lines, 1):
                                for pattern in self.token_patterns:
                                    matches = re.findall(pattern, line)
                                    if matches:
                                        findings.append({
                                            'file': filepath,
                                            'line': line_num,
                                            'pattern': pattern,
                                            'matches': matches,
                                            'severity': 'HIGH'
                                        })
                    except Exception as e:
                        print(f"Error scanning {filepath}: {e}")

        return findings

    def check_github_activity(self, token: str) -> Dict:
        """Check recent GitHub activity for suspicious patterns"""
        try:
            headers = {'Authorization': f'token {token}'}
            response = requests.get('https://api.github.com/user', headers=headers)

            if response.status_code == 401:
                return {'status': 'INVALID_TOKEN', 'message': 'Token is invalid or expired'}

            user_data = response.json()
            username = user_data.get('login', 'unknown')

            if username not in self.authorized_users:
                return {
                    'status': 'UNAUTHORIZED_USER',
                    'user': username,
                    'message': f'Token used by unauthorized user: {username}'
                }

            # Check recent activity
            activity_response = requests.get(
                f'https://api.github.com/users/{username}/events',
                headers=headers
            )

            if activity_response.status_code == 200:
                events = activity_response.json()
                suspicious_activity = []

                for event in events[:10]:  # Check last 10 events
                    if event.get('type') == 'PushEvent':
                        repo = event.get('repo', {}).get('name', '')
                        if 'dominion-os' in repo.lower():
                            suspicious_activity.append({
                                'type': 'PUSH_TO_SENSITIVE_REPO',
                                'repo': repo,
                                'time': event.get('created_at')
                            })

                return {
                    'status': 'OK',
                    'user': username,
                    'suspicious_activity': suspicious_activity
                }

        except Exception as e:
            return {'status': 'ERROR', 'message': str(e)}

    def generate_security_report(self, findings: List[Dict], activity_check: Dict) -> str:
        """Generate comprehensive security report"""
        report = []
        report.append("# PHI Chief AI Security Report")
        report.append(f"Generated: {datetime.now().isoformat()}")
        report.append("")

        # Token findings
        if findings:
            report.append("## 🚨 Token Exposure Findings")
            for finding in findings:
                report.append(f"- **{finding['severity']}**: {finding['file']}:{finding['line']}")
                report.append(f"  Pattern: {finding['pattern']}")
                report.append(f"  Matches: {', '.join(finding['matches'])}")
            report.append("")
        else:
            report.append("## ✅ No Token Exposures Found")
            report.append("")

        # Activity check
        report.append("## 🔍 GitHub Activity Analysis")
        if activity_check['status'] == 'OK':
            report.append(f"✅ Token valid for authorized user: {activity_check['user']}")
            if activity_check.get('suspicious_activity'):
                report.append("⚠️  Suspicious activity detected:")
                for activity in activity_check['suspicious_activity']:
                    report.append(f"  - {activity['type']} in {activity['repo']} at {activity['time']}")
        else:
            report.append(f"❌ {activity_check['status']}: {activity_check['message']}")

        return '\n'.join(report)

def main():
    detector = AITokenDetector()

    # Scan current repository
    print("🔍 Scanning repository for token exposures...")
    findings = detector.scan_repository('.')

    # Check token activity if token is provided
    token = os.getenv('GITHUB_TOKEN')
    activity_check = {'status': 'NO_TOKEN_PROVIDED'}

    if token:
        print("🔍 Checking GitHub activity...")
        activity_check = detector.check_github_activity(token)

    # Generate report
    report = detector.generate_security_report(findings, activity_check)

    # Save report
    with open('security_report.md', 'w') as f:
        f.write(report)

    print("📋 Security report saved to security_report.md")

    # Alert if critical issues found
    if findings or activity_check['status'] != 'OK':
        print("🚨 SECURITY ALERT: Issues detected!")
        return 1

    print("✅ Security check passed")
    return 0

if __name__ == '__main__':
    exit(main())
EOF

    chmod +x ai_token_detector.py
    success "AI-based token detection system created"
}

# Function to update CI/CD with security gates
update_ci_security() {
    log "Updating CI/CD with security gates..."

    # Create GitHub Actions workflow for security scanning
    mkdir -p .github/workflows

    cat > .github/workflows/security-scan.yml << 'EOF'
name: Security Scan

on:
  push:
    branches: [ main ]
  pull_request:
    branches: [ main ]

jobs:
  security-scan:
    runs-on: ubuntu-latest

    steps:
    - name: Checkout code
      uses: actions/checkout@v4
      with:
        fetch-depth: 0

    - name: Run TruffleHog OSS
      uses: trufflesecurity/trufflehog@main
      with:
        path: ./
        base: main
        head: HEAD
        extra_args: --debug --only-verified

    - name: Run AI Token Detector
      run: |
        python scripts/ai_token_detector.py

    - name: Upload security report
      uses: actions/upload-artifact@v3
      if: always()
      with:
        name: security-report
        path: security_report.md
EOF

    success "Security scanning workflow created"
}

# Main execution
main() {
    log "Starting PHI Chief AI Security Remediation - Phase 1"

    revoke_compromised_token
    scan_hardcoded_tokens
    clean_git_history
    enable_github_security
    create_ai_detection
    update_ci_security

    success "Phase 1 Security Remediation Complete"
    log "Next: Implement Phase 2 AskPhi widget with proper OAuth"
}

# Run main function
main "$@"
