# Ecosystem Repair + Verification

- Timestamp (UTC): 2026-04-23T14:06:41Z
- Mode: verify-only
- Region: us-central1
- Projects: dominion-core-prod dominion-os dominion-os-1-0-main dominion-marketplace-prod f5-demo-sandbox

## Budget Authority
- Status: PASS
- Detail: budget increase authority locked (Matthew approval required)

## Local AT2 Profile
- Status: PASS
- Detail: AT2 local profile active (AT2_LIVE_OPS/MAX_PERFORMANCE/LOWEST_COST, cpu=16)

## Intelligent Sync
- Status: PASS
- Sync heartbeat age (s): 36
- GCS heartbeat age (s): 157
- Mirror heartbeat age (s): 36
- Detail: intelligent sync daemon healthy

## Authority
- Status: PASS
- Sovereignty: 14/14
- Mode: NHITL_AUTOPILOT
- Active: ACTIVE
- Max power: ENABLED
- Detail: authority 14/14 NHITL max active

## Service Matrix

| Local Service | Port | Local Running | GCP Deployed | Mapping Pattern |
|---|---:|---|---|---|
| Dominion Command Center | 5000 | YES | YES | /(demo|dominion-demo|dominion-os-demo)$ |
| Billing Service | 5001 | YES | YES | /(dominion-bootstrap|store)$ |
| Dominion Command Core | 5002 | YES | YES | /(dominion-api|api)$ |
| Sidecar Service | 5003 | YES | YES | /(situation-sidecar|.*sidecar.*)$ |
| ChatGPT Gateway | 5004 | YES | YES | /chatgpt-gateway$ |
| OAuth Server | 8080 | YES | YES | /phi-oauth-server$ |
| AskPHI Widget Service | 8081 | YES | YES | /(phi-askphi-widget|askphi-chatbot)$ |
| Dominion Java Live Ops Site | 8090 | YES | YES | /(dominion-os-1-0|dominion-os-1-0-101)$ |
| Politics Local Legacy | 5005 | YES | YES | /(dominion-os-demo|dominion-demo|demo)$ |

- Local services running: 9/9
- GCP mapped services deployed: 9/9
- Status: PASS
- Detail: all mapped services healthy

## Cost Posture
- Status: PASS
- Detail: cost controls active

