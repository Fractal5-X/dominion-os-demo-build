# Ecosystem Optimizer Report

- Timestamp (UTC): 2026-04-23T21:28:17Z
- Mode: apply-safe
- Root: /workspaces
- Region: us-central1

## Docker Baseline
## Governance
- Budget increase authority: locked
- Required approver: Matthew Burbidge
- Public surface policy: valid
- Official public surface repo: dominion-os-demo-build
- Official public GCP project: dominion-core-prod
- Local machine profile: AT2_LIVE_OPS

- Docker status: ready
- Docker version: client=29.1.3 server=29.1.3
- Compose version: Docker Compose version v5.1.3

## Source Repositories

| Repository | Branch | Dirty Files | Remotes | Remote Health |
|---|---:|---:|---:|---|
| /workspaces/dominion-AGI | main | 0 | 4 | warn |
| /workspaces/dominion-ai-gpu-local | main | 0 | 4 | warn |
| /workspaces/dominion-autocoder | main | 0 | 4 | warn |
| /workspaces/dominion-cloud-computer | main | 0 | 4 | warn |
| /workspaces/dominion-command-center | deploy/security-audit-2026-03-15 | 5 | 4 | ok |
| /workspaces/dominion-os-1.0 | main | 0 | 1 | warn |
| /workspaces/dominion-os-1.0-aws | main | 0 | 4 | warn |
| /workspaces/dominion-os-1.0-azure | main | 0 | 4 | warn |
| /workspaces/dominion-os-1.0-desktop-pc | main | 0 | 4 | warn |
| /workspaces/dominion-os-1.0-gcloud | phi/autopilot-complete | 0 | 4 | warn |
| /workspaces/dominion-os-1.0-politics | phi/autopilot-complete | 0 | 4 | warn |
| /workspaces/dominion-os-analytics | main | 0 | 4 | warn |
| /workspaces/dominion-os-api | main | 0 | 4 | warn |
| /workspaces/dominion-os-demo-build | sync/e8ffd184-pr | 70 | 5 | ok |
| /workspaces/dominion-os-edge | main | 0 | 4 | warn |
| /workspaces/dominion-os-enterprise | main | 0 | 4 | warn |
| /workspaces/dominion-os-mobile | main | 0 | 4 | warn |
| /workspaces/dominion-os-quantum | main | 0 | 4 | warn |
| /workspaces/dominion-os-security | main | 0 | 4 | warn |

- Repository count: 19
- Dirty repositories: 2
- Remote health warnings: 17
- Git tuning applied to: 19 repositories

## AI Runtime Inventory
- AI-related config files: 38593
- AI-related containers running: 0
- AI-related processes running: 13

## GCP Projects

| Project | Tier | Billing | Cloud Run Services | Safe Tune | Aggressive Tune |
|---|---|---|---:|---:|---:|
| dominion-core-prod | prod | true | 26 | 0 | 0 |

- GCP project count: 1
- Prod projects: 1
- Nonprod projects: 0
- Cloud Run services discovered: 26
- Safe tuning applied (min-instances=0, nonprod): 0
- Safe tuning failed: 0
- Safe tuning blocked (billing/guardrails): 0

## Outputs
- Status json: /workspaces/dominion-os-demo-build/scripts/telemetry/ecosystem_optimizer_status.json
- Log file: /workspaces/dominion-os-demo-build/scripts/reports/ecosystem_optimizer_20260423_212817Z.log
