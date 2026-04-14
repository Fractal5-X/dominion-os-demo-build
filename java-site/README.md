# Dominion Java Live Ops Site

Lean Java 17 service for sovereign local live operations.

## Endpoints

- `/health`
- `/healthz`
- `/ready`
- `/metrics` (Prometheus format)
- `/api/v1/topology`
- `/`

## Local commands

```bash
# Build classes
bash scripts/java_live_ops_site.sh build

# Start in background
bash scripts/java_live_ops_site.sh start

# Verify health and metrics
bash scripts/java_live_ops_site.sh verify

# Stop service
bash scripts/java_live_ops_site.sh stop
```

Default port is `8090` and can be overridden with `JAVA_SITE_PORT`.
