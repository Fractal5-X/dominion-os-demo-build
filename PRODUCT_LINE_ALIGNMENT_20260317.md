# Dominion OS Product Line Alignment (2026-03-17)

## Scope

- Repo: `dominion-demo-build` (remote: `dominion-os-demo-build`)
- Product line scope: first five repos in current governance thread.
- Platform scope: desktop and cloud only.
- Explicit exclusion: mobile.

## Mandatory Stack Contract (Non-Mobile)

All non-mobile Dominion OS deployments must include:

1. `PHI MCP`
2. `Dominion Core`
3. `SaaS Suite`

## Repo Role

- Public-facing demo and serving surface for business overlays.
- Non-authoritative runtime; control plane authority remains in `dominion-command-center`.
