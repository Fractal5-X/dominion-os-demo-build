# Operations Handoff Report

## Timestamp
- Generated (UTC): 2026-04-17T00:21:28Z

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
- Daemon PID: 272964
- Worker PID: 272970
- Alert evidence in log: ALERT service:sidecar
- Clear evidence: degraded watch state file removed after healthy recovery

## Active Watch Artifacts
- Alert log: /workspaces/dominion-os-demo-build/scripts/telemetry/degraded_watch.log
- Daemon log: /workspaces/dominion-os-demo-build/scripts/telemetry/degraded_watch_daemon.log
- Daemon PID file: /workspaces/dominion-os-demo-build/scripts/telemetry/degraded_watch_daemon.pid
