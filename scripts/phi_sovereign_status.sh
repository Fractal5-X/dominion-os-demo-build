#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [[ -x "$SCRIPT_DIR/phi_status.sh" ]]; then
    "$SCRIPT_DIR/phi_status.sh" || true
else
    echo "[WARN] phi_status.sh not found"
fi

echo ""
echo "Sovereign keepalive processes:"
ps -ef | grep phi_sovereign_keepalive.sh | grep -v grep || true

