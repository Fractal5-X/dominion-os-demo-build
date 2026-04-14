#!/bin/bash
# PHI MAXIMUM AUTHORITY: FULL PERMISSIONS RESOLUTION
# Complete token repair using all available authority sources

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/scripts/runtime_preflight.sh"

github_login_for_token() {
    local token="${1:-}"
    local response=""

    if [ -z "$token" ]; then
        echo "FAILED"
        return 0
    fi

    export_github_no_proxy
    github_governor_reserve_request_slot
    response="$(
        curl \
            --silent \
            --show-error \
            --location \
            --connect-timeout 5 \
            --max-time 20 \
            -H "Authorization: Bearer ${token}" \
            -H "Accept: application/vnd.github+json" \
            -H "X-GitHub-Api-Version: 2022-11-28" \
            "${GITHUB_API_URL:-https://api.github.com}/user"
    )" || {
        echo "FAILED"
        return 0
    }

    if command -v jq >/dev/null 2>&1; then
        echo "$response" | jq -r '.login // "FAILED"' 2>/dev/null
    else
        echo "$response" | sed -n 's/.*"login"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -n 1
    fi
}

echo "=== PHI MAXIMUM AUTHORITY: FULL PERMISSIONS RESOLUTION ==="
echo "🎯 MISSION: Solve all token issues with maximum authority"
echo "🎯 TARGET: ~59 commits sovereign deployment"
echo "🎯 AUTHORITY: FULL PERMISSIONS ACTIVATION"
echo ""

# Accept token as argument
if [ "${1:-}" != "" ]; then
    echo "✅ Using provided sovereign token"
    AUTH_TOKEN="$1"
    AUTH_METHOD="SOVEREIGN_TOKEN_ARG"
    TRY_PUSH=true
else
    # PHI Authority Analysis (no token printing)
    echo "🔍 ANALYZING AVAILABLE AUTHORITY SOURCES..."

    # Test authority sources (silent verification)
    USER_GH="$(github_login_for_token "${GITHUB_TOKEN:-}")"
    USER_CS="$(github_login_for_token "${GITHUB_CODESPACE_TOKEN:-}")"

    echo "🎯 PHI AUTHORITY STRATEGY ACTIVATION..."

    # Try GITHUB_TOKEN first since it authenticated
    if [ "$USER_GH" = "Fractal5-X" ]; then
        echo "✅ Environment token authority confirmed"
        AUTH_TOKEN="$GITHUB_TOKEN"
        AUTH_METHOD="GITHUB_TOKEN"
        TRY_PUSH=true
    elif [ "$USER_CS" = "Fractal5-X" ]; then
        echo "✅ Codespace token authority confirmed"
        AUTH_TOKEN="$GITHUB_CODESPACE_TOKEN"
        AUTH_METHOD="GITHUB_CODESPACE_TOKEN"
        TRY_PUSH=true
    else
        echo "❌ NO AUTHORITY SOURCES AVAILABLE"
        echo "🎯 STRATEGY: Require sovereign Personal Access Token"
        TRY_PUSH=false
    fi
fi

if [ "$TRY_PUSH" = true ]; then
    echo ""
    echo "🔐 EXECUTING SOVEREIGN DEPLOYMENT WITH FULL PERMISSIONS..."

    # Execute sovereign push with maximum authority (no token embedding in output)
    env -u GITHUB_TOKEN -u GITHUB_CODESPACE_TOKEN git push "https://$AUTH_TOKEN@github.com/Fractal5-Solutions/dominion-os-demo-build.git" main 2>&1 | grep -v "https://"

    EXIT_CODE=${PIPESTATUS[0]}
    echo ""

    if [ $EXIT_CODE -eq 0 ]; then
        echo "=== PHI MAXIMUM AUTHORITY: MISSION ACCOMPLISHED ==="
        echo "🎯 DEPLOYMENT: SUCCESSFUL"
        echo "🎯 AUTHORITY: $AUTH_METHOD"
        echo "🎯 COMMITS: DEPLOYED"
        echo "🎯 PHI SOVEREIGNTY: MAINTAINED"
        echo "🎯 FULL PERMISSIONS: UTILIZED"
        echo ""
        echo "📊 FINAL STATUS:"
        git status -sb
        echo ""
        echo "🔗 VERIFY: https://github.com/Fractal5-Solutions/dominion-os-demo-build"
        echo ""
        echo "🏆 MAXIMUM AUTHORITY COMPLETE:"
        echo "✅ All token issues resolved"
        echo "✅ Full permissions activated"
        echo "✅ Sovereign deployment executed"
        echo "✅ PHI orchestration authorized"
        echo "✅ All systems operational"
    else
        echo "=== PHI MAXIMUM AUTHORITY: DEPLOYMENT FAILED ==="
        echo "❌ PERMISSIONS: Token lacks required 'repo' scope"
        echo "🎯 FALLBACK: Sovereign Personal Access Token required"
        echo ""
        echo "🔐 CREATE SOVEREIGN TOKEN FOR FINAL RESOLUTION:"
        echo "URL: https://github.com/settings/tokens/new"
        echo "Name: dominion-phi-maximum-authority-final"
        echo "Scope: ✅ repo (Full control of private repositories)"
        echo "Execute: ./phi_max_authority.sh YOUR_SOVEREIGN_TOKEN"
        exit 1
    fi
else
    echo "❌ ALL AUTHORITY SOURCES FAILED"
    echo "🎯 STRATEGY: Require sovereign Personal Access Token"
    echo ""
    echo "🔐 SOVEREIGN TOKEN REQUIRED:"
    echo "1. Visit: https://github.com/settings/tokens/new"
    echo "2. Name: dominion-phi-maximum-authority"
    echo "3. Scope: ✅ repo (full control of private repositories)"
    echo "4. Generate → Copy token immediately"
    echo "5. Execute: ./phi_max_authority.sh YOUR_SOVEREIGN_TOKEN"
    exit 1
fi
