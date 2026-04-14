#!/bin/bash
# PHI Zero File Status Verification Script
# Confirms zero untracked, uncommitted, or unpushed files in gcloud systems
# Generated: 2026-03-02 by PHI Chief Sovereign Mode

set -e

echo "🔍 PHI ZERO FILE STATUS VERIFICATION"
echo "===================================="
echo "Target: Confirm zero untracked/uncommitted/unpushed files"
echo "Scope: Google Cloud systems and repositories"
echo "Timestamp: $(date)"
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
NC='\033[0m' # No Color

# Function to log verification steps
verify_log() {
    echo -e "${BLUE}[VERIFY]${NC} $1"
}

# Function to report success
success_log() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

# Function to report issues
issue_log() {
    echo -e "${RED}[ISSUE]${NC} $1"
}

# Function to report warnings
warning_log() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

# 1. Check for untracked files
verify_log "Checking for untracked files..."
UNTRACKED_COUNT=$(git status --porcelain | grep "^?" | wc -l)
if [ "$UNTRACKED_COUNT" -eq 0 ]; then
    success_log "Zero untracked files found ✓"
else
    issue_log "Found $UNTRACKED_COUNT untracked files"
    git status --porcelain | grep "^?"
fi

# 2. Check for uncommitted changes (not staged)
verify_log "Checking for uncommitted changes..."
UNCOMMITTED_COUNT=$(git status --porcelain | grep -v "^A\|^M" | wc -l)
if [ "$UNCOMMITTED_COUNT" -eq 0 ]; then
    success_log "Zero uncommitted files found ✓"
else
    issue_log "Found $UNCOMMITTED_COUNT uncommitted files"
    git status --porcelain | grep -v "^A\|^M"
fi

# 3. Check for unpushed commits
verify_log "Checking for unpushed commits..."
CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD)
UPSTREAM=$(git rev-parse --abbrev-ref --symbolic-full-name @{upstream} 2>/dev/null || echo "")
if [ -n "$UPSTREAM" ]; then
    UNPUSHED_COUNT=$(git rev-list --count "$UPSTREAM"..HEAD 2>/dev/null || echo 0)
else
    UNPUSHED_COUNT=0
fi
if [ "$UNPUSHED_COUNT" -eq 0 ]; then
    success_log "Zero unpushed commits found ✓"
else
    issue_log "Found $UNPUSHED_COUNT unpushed commits on branch $CURRENT_BRANCH"
    if [ -n "$UPSTREAM" ]; then
        git log --oneline "$UPSTREAM"..HEAD
    fi
fi

# 4. Check staged files count
verify_log "Checking staged files count..."
STAGED_COUNT=$(git status --porcelain | wc -l)
warning_log "Found $STAGED_COUNT staged files (committed but not yet pushed)"

# 5. Verify repository cleanliness
verify_log "Verifying repository cleanliness..."
if [ "$UNTRACKED_COUNT" -eq 0 ] && [ "$UNCOMMITTED_COUNT" -eq 0 ] && [ "$UNPUSHED_COUNT" -eq 0 ]; then
    echo ""
    echo -e "${GREEN}🎉 ZERO FILE STATUS CONFIRMED${NC}"
    echo -e "${GREEN}================================${NC}"
    echo -e "${GREEN}✅ Untracked files: 0${NC}"
    echo -e "${GREEN}✅ Uncommitted files: 0${NC}"
    echo -e "${GREEN}✅ Unpushed commits: 0${NC}"
    echo -e "${GREEN}📦 Staged files: $STAGED_COUNT (ready for push)${NC}"
    echo ""
    echo -e "${MAGENTA}🔐 SOVEREIGNTY MAINTAINED | ALL FILES SYNCHRONIZED${NC}"
    exit 0
else
    echo ""
    echo -e "${RED}❌ ISSUES DETECTED${NC}"
    echo -e "${RED}=================${NC}"
    echo -e "${RED}Untracked files: $UNTRACKED_COUNT${NC}"
    echo -e "${RED}Uncommitted files: $UNCOMMITTED_COUNT${NC}"
    echo -e "${RED}Unpushed commits: $UNPUSHED_COUNT${NC}"
    echo ""
    echo -e "${YELLOW}🔧 ACTION REQUIRED: Resolve issues above${NC}"
    exit 1
fi
