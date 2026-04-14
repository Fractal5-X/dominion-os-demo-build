#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/runtime_preflight.sh"

GITHUB_API_URL="${GITHUB_API_URL:-https://api.github.com}"

if [ "${1:-}" = "--healthcheck" ]; then
    export_github_no_proxy
    github_api_preflight "${GITHUB_API_URL}"
    exit $?
fi

echo "[mcp-github] Preparing GitHub API network settings"
export_github_no_proxy
echo "[mcp-github] NO_PROXY=${NO_PROXY}"

if [ -z "${GITHUB_TOKEN:-}" ]; then
    echo "[mcp-github] GITHUB_TOKEN is required" >&2
    exit 1
fi

echo "[mcp-github] Validating ${GITHUB_API_URL}"
if ! github_api_preflight "${GITHUB_API_URL}"; then
    echo "[mcp-github] GitHub API preflight failed" >&2
    exit 1
fi

echo "[mcp-github] GitHub API reachable, starting server"
exec mcp-server-github
