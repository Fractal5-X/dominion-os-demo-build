# Ops Readiness Audit - 2026-03-20

## Scope

Audit focus was limited to this runtime, where the Docker CLI is installed but the Docker daemon is not reachable. The practical blocker here is environment capability, not missing repo assets.

## Current State

- Local HTTP services are reachable on ports `5000`, `5001`, `5002`, `8080`, and `8081`.
- `scripts/phi_live_ops_verification.sh` confirms those local services are healthy.
- `docker info` fails with `Cannot connect to the Docker daemon at unix:///var/run/docker.sock`.
- Container-oriented flows remain unverifiable in this runtime.

## High-Signal Gaps Found

1. Historical readiness documents overstate current operability.
   Files such as `PRODUCTION_READINESS_PROOF.md` and `AT2_DEPLOYMENT_READY.md` describe successful or ready deployment states without clarifying that those claims are environment-specific and not validated in this runtime.

2. Some verification scripts mixed local service checks with Docker-only assertions.
   That made healthy non-Docker services look less ready than they are, or caused hard failures before the useful part of the verification completed.

3. Some MCP management flows assumed Docker control unconditionally.
   In a runtime like this one, those commands should degrade cleanly and explain the blocker rather than fail opaquely.

4. The deployed `phi-oauth-server` Cloud Run revision does not currently expose `/ready` or `/health`.
   The repo implementation does include those routes locally, so this is a deployment drift signal rather than a code-absence issue in the checked-out repo.

## Immediate Remediation Applied

- Added `scripts/runtime_preflight.sh` to centralize Docker runtime detection.
- Updated `verify-deployment.sh` to:
  - verify local services independently of Docker,
  - stop requiring stale `/demo` and `/store` endpoints,
  - report Docker as a runtime blocker instead of a repo failure when appropriate.
- Updated `scripts/verify_dominion_deployment.py` so local verification targets the actual non-Docker service layout in this runtime instead of probing the OAuth port for `command_core`.
- Updated `scripts/mcp_health_check.sh` to skip cleanly when Docker is unreachable in this runtime.
- Updated `scripts/mcp_manage.sh` to emit a runtime limitation note instead of attempting blind Docker operations.
- Updated `scripts/phi_live_ops_verification.sh` to show Docker as runtime-scoped `N/A`, report real Python service processes, and flag stale telemetry timestamps.

## Recommended Next Checks

```bash
bash scripts/phi_live_ops_verification.sh
bash verify-deployment.sh
bash scripts/mcp_health_check.sh
bash scripts/mcp_manage.sh status
docker info
```
