# AT2 PC Restart Preparation Plan

- Prepared on: 2026-04-20 (UTC)
- Scope: Prepare and execute a controlled restart of the AT2 primary machine while preserving command-center continuity.
- Topology note: AT2 local live ops is primary at `D:/dominion-command-center`; this codespace environment is complementary.

## Success Criteria

- Pre-restart health evidence captured.
- Graceful live-ops shutdown completed before OS restart.
- After reboot, services restored and verified healthy.
- Monitoring supervisor stack is fully running (`supervisor`, `continuous_monitor`, `sovereign_monitor`, `auto_audit`).

## Phase 1: Pre-Restart Readiness (T-15 to T-5 minutes)

1. Capture current stack status.

```bash
/workspaces/dominion-command-center/scripts/live_ops_status.sh
```

2. Run full verification gate.

```bash
/workspaces/dominion-command-center/scripts/live_ops_verify.sh
```

3. Record most recent artifacts for handoff.

```bash
ls -1t /workspaces/dominion-os-demo-build/scripts/logs/phi_startup_*.log | head -1
ls -1t /workspaces/dominion-os-demo-build/scripts/logs/phi_shutdown_*.log | head -1
cat /workspaces/dominion-os-demo-build/scripts/telemetry/system_status.json
```

Go/No-Go gate:
- Proceed only if core web services and monitor supervisor show healthy.
- If degraded, stabilize first (do not restart yet).

## Phase 2: Graceful Service Stop (T-5 to T-1 minutes)

1. Perform authoritative shutdown path.

```bash
/workspaces/dominion-command-center/scripts/live_ops_stop.sh
```

2. Confirm shutdown state snapshot.

```bash
/workspaces/dominion-command-center/scripts/live_ops_status.sh
cat /workspaces/dominion-os-demo-build/scripts/telemetry/system_status.json
```

Expected result:
- `active_services` reflects stopped state.
- Latest shutdown log exists: `/workspaces/dominion-os-demo-build/scripts/logs/phi_shutdown_*.log`.

## Phase 3: PC Restart (AT2 host)

Execute on the AT2 machine console/session:

```powershell
shutdown /r /t 0
```

## Phase 4: Post-Restart Recovery (T+1 to T+10 minutes)

1. Start stack using command-center wrapper.

```bash
/workspaces/dominion-command-center/scripts/live_ops_start.sh
```

2. Verify end-to-end health.

```bash
/workspaces/dominion-command-center/scripts/live_ops_status.sh
/workspaces/dominion-command-center/scripts/live_ops_verify.sh
```

3. Confirm monitor supervisor components are all running.

```bash
/workspaces/dominion-os-demo-build/scripts/phi_monitor_supervisor.sh status
```

Exit gate:
- All expected services healthy.
- Supervisor + monitors all running.
- No repeating restart loops in telemetry.

## Phase 5: Rollback / Contingency

If startup fails:

1. Re-run startup once and capture latest startup log.

```bash
/workspaces/dominion-command-center/scripts/live_ops_start.sh
ls -1t /workspaces/dominion-os-demo-build/scripts/logs/phi_startup_*.log | head -1
```

2. If still unhealthy, stop and re-verify baseline.

```bash
/workspaces/dominion-command-center/scripts/live_ops_stop.sh
/workspaces/dominion-command-center/scripts/live_ops_status.sh
```

3. Use `live_ops_verify.sh` plus latest startup/shutdown logs as incident packet for next action.

## Operator Checklist (Quick)

- [ ] Status captured (`live_ops_status.sh`)
- [ ] Verify passed (`live_ops_verify.sh`)
- [ ] Graceful stop completed (`live_ops_stop.sh`)
- [ ] AT2 reboot command executed
- [ ] Start completed (`live_ops_start.sh`)
- [ ] Post-verify passed (`live_ops_verify.sh`)
- [ ] Evidence logs saved for handoff
