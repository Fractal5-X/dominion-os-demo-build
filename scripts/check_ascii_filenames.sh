#!/usr/bin/env bash
set -euo pipefail

# Fail if any tracked filename contains bytes outside printable ASCII.
bad=0
while IFS= read -r -d '' path; do
  if printf '%s' "$path" | LC_ALL=C grep -q '[^ -~]'; then
    echo "Non-ASCII filename detected: $path"
    bad=1
  fi
done < <(git ls-files -z)

if [[ "$bad" -ne 0 ]]; then
  echo "Filename policy violation: only printable ASCII filenames are allowed."
  exit 1
fi

echo "ASCII filename check passed."

