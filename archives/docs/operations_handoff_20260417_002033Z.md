# Operations Handoff Report

## Timestamp
- Generated (UTC): 2026-04-17T00:20:33Z

## Status Snapshot
- Core web services: 8/8 operational
- Supervisor stack: running
- Readiness: 80/100 overall, 100/100 normalized (Docker daemon N/A in this runtime)

## Controlled Failover / Auto-Heal
- Target: Sidecar service (port 5003)
- Action: process terminated intentionally
- Result: recovered to healthy (HTTP 200 on /health)

## Degraded-Only Watch Validation
- Watch mode: daemon-managed
- Daemon PID: 268082
- Worker PID: 268082
- Alert evidence: `ALERT service:sidecar` logged during induced outage
- Clear evidence: alert state file removed after recovery (healthy state)

## Active Watch Artifacts
- Alert log: /workspaces/dominion-os-demo-build/scripts/telemetry/degraded_watch.log
- Daemon log: /workspaces/dominion-os-demo-build/scripts/telemetry/degraded_watch_daemon.log
- Daemon PID file: /workspaces/dominion-os-demo-build/scripts/telemetry/degraded_watch_daemon.pid
- Worker state: /workspaces/dominion-os-demo-build/scripts/telemetry/degraded_watch.state
