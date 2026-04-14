# Demo Boundary Audit

Generated (UTC): 2026-03-30T19:15:00Z

## Boundary

`dominion-os-demo-build` is the public-serving demo surface.

`dominion-command-center` remains the source of truth for operational authority, overlays, contracts, and structured company/demo records.

## Source Of Truth Evidence In `dominion-command-center`

- Overlay contract present at `config/situation_room_overlay_canada.json`
  - version `1.0.0`
  - `overlayMode: dual_overlay`
  - overlays: `business`, `politics`
- Typed runtime models present at `app/models/toolapi.py`
  - includes `TenantSummary`, `RunRecord`, `ApprovalRecord`, `AuditEvent`, and related API models
- Contract schemas present at `contracts/contracts.json`
  - `Task`, `Evidence`, `Decision`, `LedgerEntry`, `Heartbeat`
- Connector/product manifest present at `manifest/connect-manifest.csv`
- Company record surface present at `data/apollo_crm/accounts_raw.json`
  - `organizations` count: `3`
  - records are demo-company style structured entries, not production secrets

## Public Demo Runtime Evidence In `dominion-os-demo-build`

The public demo runtime has been constrained to:

- `command_core.pyc`
- `demo/**`
- `store/**`
- `products/**`
- `scripts/telemetry/config_project1.txt`
- `scripts/telemetry/config_project2.txt`
- `scripts/telemetry/services_project1.txt`
- `scripts/telemetry/services_project2.txt`

Excluded from the public runtime payload:

- `.env*`
- `.venv*`
- `data/**`
- `backups/**`
- `command-center/**`
- `commercial/**`
- `oauth_server/**`
- `ops/**`
- `orchestrator/**`
- `reports/**`
- `telemetry/**`

## Hardening Applied

- Added `.dockerignore` allowlist to restrict build context upload
- Updated `Dockerfile.production` to copy only approved public assets
- Compiled `command_core.py` to `command_core.pyc` and removed plain source from the final image
- Added `scripts/verify_public_demo_surface.py`
- Added workflow enforcement in `.github/workflows/production-deploy.yml`

## Verification

- Public surface verifier reports only `16` included payload paths
- High-risk tracked paths excluded from payload: `12462`
- Hardened image built successfully
- Hardened container runtime responded successfully on `/health`

## Release Intent

`dominion-os-demo` should remain optimized as a public-safe business-overlay demo surface for GCP.

It should not serve:

- repository source trees
- local virtual environments
- raw CRM/contact exports
- secrets, tokens, or operator-only artifacts

It should serve:

- demo UX
- store/product summaries
- overlay/version/source-of-truth metadata
- topology/status visibility appropriate for a public-safe demo
