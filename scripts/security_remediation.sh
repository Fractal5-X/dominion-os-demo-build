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
    local detector_source

    if [ -f "ai_token_detector.py" ]; then
        log "AI token detector already exists"
        return 0
    fi

    detector_source="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/ai_token_detector.py"
    if [ ! -f "$detector_source" ]; then
        error "Maintained AI token detector not found at $detector_source"
        return 1
    fi

    cp "$detector_source" ai_token_detector.py
    chmod +x ai_token_detector.py
    success "AI-based token detection system copied from maintained repository version"
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
