#!/usr/bin/env python3
# -*- coding: utf-8 -*-
# -*- coding: utf-8 -*-
"""Verify the public demo runtime payload is restricted to approved assets."""

from __future__ import annotations

import json
import subprocess
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[1]

ALLOWED_PREFIXES = (
    "command_core.py",
    "demo/",
    "products/",
    "store/",
    "scripts/telemetry/config_project1.txt",
    "scripts/telemetry/config_project2.txt",
    "scripts/telemetry/services_project1.txt",
    "scripts/telemetry/services_project2.txt",
    "requirements-prod.txt",
)

FORBIDDEN_PREFIXES = (
    ".env",
    ".venv/",
    ".venv_phi2/",
    "backups/",
    "command-center/",
    "commercial/",
    "data/",
    "oauth_server/",
    "ops/",
    "orchestrator/",
    "reports/",
    "telemetry/",
)


def run_git_ls_files() -> list[str]:
    output = subprocess.check_output(
        ["git", "-C", str(REPO_ROOT), "ls-files"],
        text=True,
    )
    return [line.strip() for line in output.splitlines() if line.strip()]


def is_allowed(path: str) -> bool:
    return any(path == prefix or path.startswith(prefix) for prefix in ALLOWED_PREFIXES)


def is_forbidden(path: str) -> bool:
    return any(path == prefix or path.startswith(prefix) for prefix in FORBIDDEN_PREFIXES)


def main() -> int:
    tracked = run_git_ls_files()
    included = [path for path in tracked if is_allowed(path)]
    forbidden_included = [path for path in included if is_forbidden(path)]
    high_risk_excluded = [path for path in tracked if is_forbidden(path)]

    required = {
        "command_core.py",
        "demo/index.html",
        "store/index.html",
        "requirements-prod.txt",
        "scripts/telemetry/config_project1.txt",
        "scripts/telemetry/config_project2.txt",
        "scripts/telemetry/services_project1.txt",
        "scripts/telemetry/services_project2.txt",
    }
    missing_required = sorted(path for path in required if path not in tracked)

    if missing_required:
        raise SystemExit(f"missing required public payload files: {', '.join(missing_required)}")

    if forbidden_included:
        raise SystemExit(
            "forbidden paths leaked into public payload allowlist: "
            + ", ".join(sorted(forbidden_included))
        )

    print(
        json.dumps(
            {
                "ok": True,
                "included_count": len(included),
                "included_paths": included,
                "excluded_high_risk_count": len(high_risk_excluded),
                "excluded_high_risk_sample": sorted(high_risk_excluded)[:40],
            },
            indent=2,
        )
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
