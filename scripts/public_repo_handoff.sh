#!/bin/bash
set -euo pipefail

COMMAND_CENTER_ROOT="${DOMINION_WORKSPACE_ROOT:-/workspaces/dominion-command-center}"
DEFAULT_COMMAND_CENTER_ROOT="/workspaces/dominion-command-center"

is_command_center_context() {
    local workspace_root="${DOMINION_WORKSPACE_ROOT:-}"
    local command_center_root="${DOMINION_COMMAND_CENTER:-}"
    local phi_base_root="${PHI_BASE:-}"

    [ "$workspace_root" = "$DEFAULT_COMMAND_CENTER_ROOT" ] \
        || [ "$workspace_root" = "$COMMAND_CENTER_ROOT" ] \
        || [ "$command_center_root" = "$DEFAULT_COMMAND_CENTER_ROOT" ] \
        || [ "$command_center_root" = "$COMMAND_CENTER_ROOT" ] \
        || [ "$phi_base_root" = "$DEFAULT_COMMAND_CENTER_ROOT" ] \
        || [ "$phi_base_root" = "$COMMAND_CENTER_ROOT" ]
}

print_handoff() {
    local requested_action="${1:-live operations}"
    local primary_local_root="${PRIMARY_LOCAL_ROOT:-D:/dominion-command-center}"
    local complementary_codespace="${COMPLEMENTARY_CODESPACE:-bookish-umbrella}"
    local matthew_client_host="${MATTHEW_CLIENT_HOST:-laptop-e2139tsl}"
    cat <<EOF
[PUBLIC REPO HANDOFF]
This repository is public-serving only and does not own ${requested_action}.

Authorized internal operations repository:
  ${COMMAND_CENTER_ROOT}

Operational topology:
  Proper local live ops : AT2 machine at ${primary_local_root}
  Complementary access  : Codespace ${complementary_codespace} from ${matthew_client_host}
  Operating rule        : Complementary access must not disrupt AT2 local live ops

Use command-center owned entrypoints instead:
  Local/live ops start   : ${COMMAND_CENTER_ROOT}/scripts/live_ops_start.sh
  Local/live ops status  : ${COMMAND_CENTER_ROOT}/scripts/live_ops_status.sh
  Local/live ops verify  : ${COMMAND_CENTER_ROOT}/scripts/live_ops_verify.sh
  GCP/remote deploy flow : ${COMMAND_CENTER_ROOT}/.github/workflows/gcp-cloudrun-deploy.yml

Public demo assets remain in:
  /workspaces/dominion-os-demo-build
EOF
}

deny_public_repo_operation() {
    local requested_action="${1:-live operations}"
    print_handoff "$requested_action" >&2
    exit 1
}

require_command_center_context() {
    local requested_action="${1:-live operations}"

    if is_command_center_context; then
        return 0
    fi

    deny_public_repo_operation "$requested_action"
}
