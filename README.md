# Dominion OS Demo Build

![Demo](https://img.shields.io/badge/Demo-Ready-brightgreen)
[![Dominion OS](https://img.shields.io/badge/Depends%20on-dominion--os--1.0-blue)](https://github.com/Fractal5-Solutions/dominion-os-1.0)
![Cloud Run](https://img.shields.io/badge/Deployed-Google%20Cloud%20Run-4285F4?logo=googlecloud&logoColor=white)
![License](https://img.shields.io/badge/license-Commercial-blue)

This repo demonstrates consuming the sibling [`dominion-os-1.0`](https://github.com/Fractal5-Solutions/dominion-os-1.0) toy kernel to:

- Build a JSON image
- Run a demo and save outputs to `dist/`

Quickstart

- Build: `python demo_build.py build`
- Run demo: `python demo_build.py run`
- Tests: `python -m unittest`

Authoritative Local Live Ops Bridge

- `dominion-command-center` is the apex control plane for local live ops in this workspace.
- This repo provides the downstream PHI bridge and health surface that command-center drives.
- Start via command-center: `bash /workspaces/dominion-command-center/scripts/live_ops_start.sh`
- Stop via command-center: `bash /workspaces/dominion-command-center/scripts/live_ops_stop.sh`
- Status via command-center: `bash /workspaces/dominion-command-center/scripts/live_ops_status.sh`
- Verify via command-center: `bash /workspaces/dominion-command-center/scripts/live_ops_verify.sh`
- Demo-build bridge entrypoints:
  - `scripts/phi_start_all_systems.sh`
  - `scripts/phi_stop_all_systems.sh`
  - `scripts/phi_status.sh`
  - `scripts/phi_live_ops_verification.sh`

GitHub App Sales Packet

- Buyer packet: `store/github-app/README.md`
- Buyer listing copy: `store/github-app/listing.md`
- Enterprise offer mirror: `docs/marketplace/github-app-enterprise.md`
- Static landing page: `web/sqsp/github-app-enterprise.html`

Command Core (full experience)

- Run interactive dashboard (small scale):
    - `python demo_build.py command-core --duration 120 --scale small`
- Headless, generate artifacts only:
    - `python demo_build.py command-core --duration 100 --scale medium --no-ui`
- Artifacts are written to `dist/command_core/` as `events.log`, `session.json`, and `summary.txt`.

Autopilot (NHITL)

- Single automated run at large scale:
    - `python demo_build.py autopilot --scale large --duration 300`
- Multiple back-to-back runs with interval:
    - `python demo_build.py autopilot --scale medium --duration 120 --runs 3 --interval-ms 500`
- Output: flight summaries saved under `dist/command_core/flight_*.json`.

Note: This demo imports `dominion_os` from the sibling path `../dominion-os-1.0` without installing it. This keeps it network-free.
