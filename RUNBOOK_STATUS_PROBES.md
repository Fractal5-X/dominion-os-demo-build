# Status Probe Runbook Note

## Scope

- Endpoint: `/status`
- Endpoint: `/api/v1/topology`

## Probe Semantics

- Default behavior: no probes are executed.
- `?probe=local`: executes local service probes only.
- `?probe=remote`: executes remote project probes only.
- `?probe=all`: executes both local and remote probes.
- Backward compatibility: `?probe=true` and `?probe=1` map to local probes.

## Operational Guidance

- Use default `/status` for low-latency health and inventory checks.
- Use `?probe=local` during operator diagnostics when validating local dependencies.
- Use `?probe=remote` or `?probe=all` only when remote telemetry verification is required.

## Verification Examples

- `http://127.0.0.1:5000/status`
- `http://127.0.0.1:5000/status?probe=local`
- `http://127.0.0.1:5000/api/v1/topology?probe=all`
