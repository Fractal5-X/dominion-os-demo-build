# Full-Stack Startup Learning Report

- Generated (UTC): 2026-04-23T22:17:51Z
- Safe-clean mode: 1
- Recent runs analyzed: 7
- Docker rate-limit signal runs: 4
- Compose failure signal runs: 4
- Dev stack failure signal runs: 2
- Current run status: FAIL
- Current warning count: 0
- Docker clean gate blocked: 1
- Execution log: /workspaces/dominion-os-demo-build/scripts/logs/dominion_full_stack_20260423_221743Z.log

## Learned Guidance

- If Docker rate-limit signals recur and compose images are not cached, require Docker Hub auth before startup.
- Keep startup strict in safe-clean mode to avoid partial startup states.
- Preserve command-center verification as mandatory completion criteria.
