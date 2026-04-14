#!/bin/bash
###############################################################################
# PHI Intelligent Sync Script
# Optimally synchronizes workspace changes to GitHub repository
# 
# Features:
# - Automatic .gitignore management for sensitive files
# - Smart commit message generation based on changes
# - Feature branch creation with PR automation
# - Protected branch handling
# - Clean staging (excludes logs, temp files, credentials)
###############################################################################

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Helper functions
print_success() { echo -e "${GREEN}✓${NC} $1"; }
print_error() { echo -e "${RED}✗${NC} $1"; }
print_warning() { echo -e "${YELLOW}⚠${NC} $1"; }
print_info() { echo -e "${BLUE}ℹ${NC} $1"; }
print_header() { echo -e "\n${BLUE}▶${NC} $1"; }

# Configuration
REPO_DIR="/workspaces/dominion-os-demo-build"
DEFAULT_BRANCH="main"

###############################################################################
# Phase 1: Pre-flight Checks
###############################################################################
print_header "Phase 1: Pre-flight Checks"

cd "$REPO_DIR" || exit 1
print_success "Changed to repository directory"

# Check git status
if ! git rev-parse --git-dir > /dev/null 2>&1; then
    print_error "Not a git repository"
    exit 1
fi
print_success "Git repository confirmed"

# Check for uncommitted changes
if git diff-index --quiet HEAD --; then
    print_warning "No changes to commit"
    print_info "Workspace is already synchronized"
    exit 0
fi
print_success "Changes detected"

###############################################################################
# Phase 2: Ensure .gitignore Protection
###############################################################################
print_header "Phase 2: Security Check (.gitignore)"

if [ ! -f .gitignore ]; then
    print_warning ".gitignore not found, creating protection rules"
    cat > .gitignore << 'EOF'
# Environment files with secrets
.env.mcp
.env
*.env.local

# Python virtual environments
.venv/
venv/
env/
ENV/
__pycache__/
*.pyc
*.pyo
*.pyd
.Python

# IDE files
.vscode/
.idea/
*.swp
*.swo
*~

# OS files
.DS_Store
Thumbs.db

# Log files
*.log
scripts/logs/*.log
scripts/logs/*.pid
scripts/telemetry/*.log

# Temporary files
*.tmp
*.bak
*.swp
.tmp/
temp/

# Docker volumes (local data)
docker-volumes/
EOF
    print_success "Created .gitignore with security rules"
else
    print_success ".gitignore already exists"
fi

###############################################################################
# Phase 3: Analyze Changes
###############################################################################
print_header "Phase 3: Analyzing Changes"

# Get file statistics
ADDED_FILES=$(git status --porcelain | grep -c '^??' || echo 0)
MODIFIED_FILES=$(git status --porcelain | grep -c '^ M' || echo 0)
DELETED_FILES=$(git status --porcelain | grep -c '^ D' || echo 0)

echo "  Added:    $ADDED_FILES files"
echo "  Modified: $MODIFIED_FILES files"
echo "  Deleted:  $DELETED_FILES files"

# Detect change categories
CHANGE_TYPES=()
if git status --porcelain | grep -q '\.sh$'; then CHANGE_TYPES+=("scripts"); fi
if git status --porcelain | grep -q '\.yml$\|\.yaml$'; then CHANGE_TYPES+=("config"); fi
if git status --porcelain | grep -q '\.md$'; then CHANGE_TYPES+=("docs"); fi
if git status --porcelain | grep -q '\.py$'; then CHANGE_TYPES+=("python"); fi
if git status --porcelain | grep -q 'docker-compose'; then CHANGE_TYPES+=("docker"); fi

print_success "Change analysis complete"

###############################################################################
# Phase 4: Smart Staging
###############################################################################
print_header "Phase 4: Smart Staging"

# Stage all changes
git add -A

# Unstage sensitive/log files that might have been added
print_info "Removing sensitive files from staging..."
git restore --staged .env.mcp 2>/dev/null || true
git restore --staged scripts/logs/*.log 2>/dev/null || true
git restore --staged scripts/logs/*.pid 2>/dev/null || true
git restore --staged scripts/telemetry/*.log 2>/dev/null || true
git restore --staged *.tmp 2>/dev/null || true

# Show what's staged
STAGED_COUNT=$(git diff --cached --name-only | wc -l)
print_success "Staged $STAGED_COUNT files (excluding logs and sensitive data)"

if [ "$STAGED_COUNT" -eq 0 ]; then
    print_warning "No files staged after security filtering"
    print_info "Only log/sensitive files were changed"
    exit 0
fi

###############################################################################
# Phase 5: Generate Commit Message
###############################################################################
print_header "Phase 5: Generating Commit Message"

# Build commit type
COMMIT_TYPE="feat"
if [ "$MODIFIED_FILES" -gt "$ADDED_FILES" ]; then
    COMMIT_TYPE="chore"
fi

# Build commit scope
COMMIT_SCOPE="sync"
if [ ${#CHANGE_TYPES[@]} -eq 1 ]; then
    COMMIT_SCOPE="${CHANGE_TYPES[0]}"
fi

# Build commit message
COMMIT_MSG="${COMMIT_TYPE}: Intelligent sync - ${CHANGE_TYPES[*]}

Changes synchronized:
- Added: $ADDED_FILES files
- Modified: $MODIFIED_FILES files
- Deleted: $DELETED_FILES files

Staged files ($STAGED_COUNT):
$(git diff --cached --name-only | head -20)
$([ "$STAGED_COUNT" -gt 20 ] && echo "... and $((STAGED_COUNT - 20)) more files")

Automated sync by PHI Intelligent Sync System"

print_success "Commit message generated"
echo "$COMMIT_MSG" | head -3

###############################################################################
# Phase 6: Create Feature Branch and Commit
###############################################################################
print_header "Phase 6: Branch and Commit"

# Generate unique branch name
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BRANCH_NAME="sync/automated-sync-${TIMESTAMP}"

# Check if on protected branch
CURRENT_BRANCH=$(git branch --show-current)
if [ "$CURRENT_BRANCH" = "$DEFAULT_BRANCH" ]; then
    print_warning "On protected branch '$DEFAULT_BRANCH', creating feature branch"
    git checkout -b "$BRANCH_NAME"
    print_success "Created and switched to branch: $BRANCH_NAME"
else
    print_info "Already on feature branch: $CURRENT_BRANCH"
    BRANCH_NAME="$CURRENT_BRANCH"
fi

# Commit changes
git commit -m "$COMMIT_MSG"
print_success "Changes committed"

###############################################################################
# Phase 7: Push to GitHub
###############################################################################
print_header "Phase 7: Push to GitHub"

# Push branch
if git push -u origin "$BRANCH_NAME"; then
    print_success "Pushed to origin/$BRANCH_NAME"
else
    print_error "Failed to push to GitHub"
    exit 1
fi

###############################################################################
# Phase 8: Create Pull Request (if tools available)
###############################################################################
print_header "Phase 8: Pull Request Creation"

# Extract repo info
REPO_URL=$(git config --get remote.origin.url)
if [[ "$REPO_URL" =~ github\.com[:/]([^/]+)/([^/.]+) ]]; then
    OWNER="${BASH_REMATCH[1]}"
    REPO="${BASH_REMATCH[2]}"
    
    PR_URL="https://github.com/${OWNER}/${REPO}/pull/new/${BRANCH_NAME}"
    
    print_success "Branch pushed successfully!"
    print_info "Create pull request at: $PR_URL"
    
    # If in Codespaces, try to open in browser
    if [ -n "$BROWSER" ]; then
        print_info "Opening PR creation page in browser..."
        "$BROWSER" "$PR_URL" 2>/dev/null || true
    fi
else
    print_success "Push complete"
fi

###############################################################################
# Summary
###############################################################################
print_header "✅ Sync Complete"
echo ""
echo "Branch:        $BRANCH_NAME"
echo "Files staged:  $STAGED_COUNT"
echo "Status:        Pushed to GitHub"
echo ""
print_success "Repository synchronized optimally!"
echo ""
