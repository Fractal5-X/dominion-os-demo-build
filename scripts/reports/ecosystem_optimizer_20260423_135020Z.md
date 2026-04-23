# Ecosystem Optimizer Report

- Timestamp (UTC): 2026-04-23T13:50:20Z
- Mode: audit
- Root: /workspaces
- Region: us-central1

## Docker Baseline
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
| /workspaces/dominion-command-center | deploy/security-audit-2026-03-15 | 4 | 4 | ok |
| /workspaces/dominion-os-1.0 | main | 0 | 1 | warn |
| /workspaces/dominion-os-1.0-aws | main | 0 | 4 | warn |
| /workspaces/dominion-os-1.0-azure | main | 0 | 4 | warn |
| /workspaces/dominion-os-1.0-desktop-pc | main | 0 | 4 | warn |
| /workspaces/dominion-os-1.0-gcloud | phi/autopilot-complete | 0 | 4 | warn |
| /workspaces/dominion-os-1.0-politics | phi/autopilot-complete | 0 | 4 | warn |
| /workspaces/dominion-os-analytics | main | 0 | 4 | warn |
| /workspaces/dominion-os-api | main | 0 | 4 | warn |
| /workspaces/dominion-os-demo-build | sync/e8ffd184-pr | 24 | 5 | ok |
| /workspaces/dominion-os-edge | main | 0 | 4 | warn |
| /workspaces/dominion-os-enterprise | main | 0 | 4 | warn |
| /workspaces/dominion-os-mobile | main | 0 | 4 | warn |
| /workspaces/dominion-os-quantum | main | 0 | 4 | warn |
| /workspaces/dominion-os-security | main | 0 | 4 | warn |

- Repository count: 19
- Dirty repositories: 2
- Remote health warnings: 17

## AI Runtime Inventory
- AI-related config files: 589
- AI-related containers running: 0
- AI-related processes running: 13

## GCP Projects

| Project | Tier | Billing | Cloud Run Services | Safe Tune | Aggressive Tune |
|---|---|---|---:|---:|---:|
| sys-22888716929838087373059549 | nonprod | n/a | na | 0 | 0 |
| sys-64833253371455487561017236 | nonprod | n/a | na | 0 | 0 |
| f5-international-prod | prod | n/a | na | 0 | 0 |
| f5-ai-research | nonprod | n/a | na | 0 | 0 |
| dominion-engines-prod-469914 | prod | n/a | na | 0 | 0 |
| sys-09901171393269334095360801 | nonprod | n/a | na | 0 | 0 |
| f5-demo-sandbox | nonprod | n/a | 11 | 0 | 0 |
| f5-preprod-stage | nonprod | n/a | na | 0 | 0 |
| f5-internal-ops | nonprod | n/a | na | 0 | 0 |
| f5-shared-services | unknown | n/a | na | 0 | 0 |
| dominion-github-apps-prod | prod | n/a | na | 0 | 0 |
| dominion-marketplace-prod | prod | n/a | 1 | 0 | 0 |
| dominion-endpoints-prod | prod | n/a | na | 0 | 0 |
| dominion-api-prod | prod | n/a | na | 0 | 0 |
| dominion-engines-prod | prod | n/a | na | 0 | 0 |
| dominion-apps-prod | prod | n/a | na | 0 | 0 |
| dominion-labs-prod | prod | n/a | na | 0 | 0 |
| dominion-core-prod | prod | n/a | 26 | 0 | 0 |
| app-95933378700714483451697893 | unknown | n/a | na | 0 | 0 |
| sys-05093536855945584251865327 | nonprod | n/a | na | 0 | 0 |
| dominion-os-1-0-main | unknown | n/a | 15 | 0 | 0 |
| google-mpf-809012535735 | nonprod | n/a | na | 0 | 0 |
| cs-host-dd869f0e3b6c425d82c325 | unknown | n/a | na | 0 | 0 |
| cs-hc-2d2ec159b8294d21b3df8726 | unknown | n/a | na | 0 | 0 |
| dominion-os | unknown | n/a | 24 | 0 | 0 |
| google-mpf-586167009642 | nonprod | n/a | na | 0 | 0 |
| sys-88344290966096851966934122 | nonprod | n/a | na | 0 | 0 |
| sys-90889003371782899159109449 | nonprod | n/a | na | 0 | 0 |

- GCP project count: 28
- Prod projects: 10
- Nonprod projects: 12
- Cloud Run services discovered: 77

## Outputs
- Status json: /workspaces/dominion-os-demo-build/scripts/telemetry/ecosystem_optimizer_status.json
- Log file: /workspaces/dominion-os-demo-build/scripts/reports/ecosystem_optimizer_20260423_135020Z.log
