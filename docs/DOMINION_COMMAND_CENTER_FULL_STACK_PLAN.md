# Dominion Command Center Full-Stack Startup Plan

Use this runbook to start Docker systems, GitHub readiness checks, VS Code extension readiness, and the Dominion Command Center full stack in one ordered flow.

## Primary command

```bash
bash scripts/dominion_command_center_full_stack.sh
```

## Operational launcher (recommended)

Use the command wrapper for day-to-day ops:

```bash
bash scripts/dominion_safe_clean_startup.sh start
```

Headless-safe mode for service/boot:

```bash
bash scripts/dominion_safe_clean_startup.sh start-headless
```

## Safe fully clean startup

Use strict mode to fail fast before any partial startup when prerequisites are not clean:

```bash
bash scripts/dominion_command_center_full_stack.sh --safe-clean
```

This mode adds two protections:
- Learns from recent startup attempts and applies stricter gating.
- Blocks startup before Phase 4 if preflight is not fully clean.
- In container-capability-limited runtimes, skips compose overlays safely instead of forcing a partial Docker failure.

## Plan phases

1. Docker foundation
- Runs `scripts/docker_repair_optimal.sh` when available.
- Checks Docker daemon reachability.
- Starts compose overlays:
  - `docker-compose.yml`
  - `docker-compose-mcp.yml`
  - `docker-compose.desktop-pro.yml` (if present)

2. GitHub system readiness
- Validates `.github/workflows` presence.
- Checks git `origin` remote.
- Checks credentials via `gh auth status` and token environment variables.
- Probes remote read access with `git ls-remote`.

3. VS Code extension readiness
- Reads recommendations from `.vscode/extensions.json`.
- Checks extension auto-update policy from `.vscode/settings.json`.
- Installs missing recommendations with `code --install-extension` when `code` CLI is available.

4. Command-center full-stack start
- Starts live ops via `/workspaces/dominion-command-center/scripts/live_ops_start.sh`.
- Starts command-center dev stack via `/workspaces/dominion-command-center/scripts/dev/up.sh` (optional).

5. Verification
- Runs `/workspaces/dominion-command-center/scripts/live_ops_verify.sh`.
- Runs `scripts/phi_live_ops_verification.sh`.
- Captures status output and writes a timestamped log in `scripts/logs/`.

## Useful modes

```bash
# Print the plan only
bash scripts/dominion_command_center_full_stack.sh --plan-only

# Verify stack only (no startup)
bash scripts/dominion_command_center_full_stack.sh --verify-only

# Skip selected phases
bash scripts/dominion_command_center_full_stack.sh --skip-docker --skip-vscode

# Strict safe-clean mode without learning (diagnostic)
bash scripts/dominion_command_center_full_stack.sh --safe-clean --no-learn
```

## Environment toggles

- `DOMINION_COMMAND_CENTER_DIR`: override command-center root path.
- `DOMINION_VSCODE_AUTO_INSTALL=0`: do not auto-install missing extensions.
- `DOMINION_FULL_STACK_SKIP_DEV_STACK=1`: skip command-center dev stack startup.
- `PHI_SYNC_ENV_FILE`: override sync env file path (default `scripts/live_ops_sync.env`).

## Troubleshooting

- If compose startup reports Docker Hub pull-rate limits, authenticate Docker first:
  - `docker login`
- If command-center dev stack fails due missing multipart support, the startup script now auto-installs `python-multipart` into the command-center `.venv`.
- Learning artifacts are written each run:
  - Report: `scripts/reports/full_stack_learning_<timestamp>.md`
  - Latest telemetry: `scripts/telemetry/full_stack_learning_latest.json`

## Boot service (safe-clean)

Service file:
- `scripts/dominion-safe-clean-startup.service`

Install steps (Linux/systemd):

```bash
sudo cp scripts/dominion-safe-clean-startup.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable --now dominion-safe-clean-startup.service
sudo systemctl status dominion-safe-clean-startup.service
```
