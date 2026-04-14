#!/usr/bin/env bash
set -euo pipefail

# PHI Intelligent Sync
# Local-first sync: commits locally, pushes to origin only when a Classic PAT (ghp_*) is configured

REPO_DIR="/workspaces/dominion-os-demo-build"
LOG="$REPO_DIR/telemetry/intelligent_sync.log"
mkdir -p "$(dirname "$LOG")"
cd "$REPO_DIR" || exit 1

echo "[$(date -u +'%Y-%m-%dT%H:%M:%SZ')] Intelligent sync start" >> "$LOG"

# Ensure remote exists
git remote get-url origin >> "$LOG" 2>&1 || { echo "No git remote configured" >> "$LOG"; exit 1; }

git fetch origin >> "$LOG" 2>&1 || echo "git fetch failed" >> "$LOG"

COMMITS_AHEAD=$(git rev-list --count origin/main..HEAD 2>/dev/null || echo 0)
if [ "$COMMITS_AHEAD" -eq 0 ]; then
  echo "No commits to push" >> "$LOG"
  exit 0
fi

echo "Commits ahead: $COMMITS_AHEAD" >> "$LOG"

# Try to discover a token
TOKEN="${GITHUB_TOKEN:-}"
if [ -z "$TOKEN" ] && [ -f ~/.git-credentials ]; then
  TOKEN_LINE=$(grep -m1 "github.com" ~/.git-credentials || true)
  TOKEN=$(echo "$TOKEN_LINE" | sed -n 's|https://[^:]*:\([^@]*\)@github.com.*|\1|p' || true)
fi

if [ -z "$TOKEN" ]; then
  echo "No token available; logging and creating an issue via gh (if available)" >> "$LOG"
  if command -v gh >/dev/null 2>&1; then
    gh issue create -R Fractal5-Solutions/dominion-os-demo-build -t "PHI: AUTONOMOUS SYNC PENDING" -b "PHI requires a Classic PAT (ghp_*) to push $COMMITS_AHEAD commits. Please run scripts/configure_pat.sh ghp_YOUR_TOKEN" >>"$LOG" 2>&1 || true
  fi
  echo "Manual intervention required: provide a Classic PAT (ghp_*)" >> "$LOG"
  exit 0
fi

if [[ "$TOKEN" =~ ^ghp_ ]]; then
  echo "PAT detected; attempting autonomous push" >> "$LOG"
  # Commit any changes (safe-guard: only if there are staged/unstaged changes)
  if ! git diff --quiet || ! git diff --cached --quiet; then
    git add -A
    git commit -m "PHI Autonomous sync: $(date -u +'%Y-%m-%dT%H:%M:%SZ')" || echo "Nothing to commit"
  fi

  # Create an auth-aware remote (use token inline for non-interactive environments)
  REMOTE_URL=$(git remote get-url origin)
  if [[ "$REMOTE_URL" =~ ^https:// ]]; then
    AUTH_REMOTE=$(echo "$REMOTE_URL" | sed -E "s#https://#https://$TOKEN:@#")
    git push "$AUTH_REMOTE" HEAD:main >>"$LOG" 2>&1 && echo "Push successful" >>"$LOG" || echo "Push failed" >>"$LOG"
  else
    # SSH remote - rely on configured credentials
    git push origin HEAD:main >>"$LOG" 2>&1 && echo "Push successful via origin" >>"$LOG" || echo "Push failed via origin" >>"$LOG"
  fi
else
  echo "Token present but not a Classic PAT (ghp_*). Autonomous push skipped." >> "$LOG"
  exit 0
fi

echo "[$(date -u +'%Y-%m-%dT%H:%M:%SZ')] Intelligent sync finished" >> "$LOG"
exit 0
