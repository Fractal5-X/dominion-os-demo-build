#!/bin/bash

# Script to commit and push all changes in all repos under /workspaces

repos=$(find /workspaces -name .git -type d 2>/dev/null | sed 's|/.git||')

for repo in $repos; do
  echo "Processing repo: $repo"
  cd "$repo"
  if git status --porcelain | grep -q .; then
    echo "Changes found, committing and pushing..."
    git add .
    git commit -m "Automated commit for live ops readiness - $(date)"
    git push origin $(git branch --show-current)
  else
    echo "No changes in $repo"
  fi
done

echo "All repos processed."
