#!/bin/bash
set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/scripts/public_repo_handoff.sh"
deny_public_repo_operation "production launch orchestration"
