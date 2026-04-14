#!/usr/bin/env python3
# -*- coding: utf-8 -*-
# -*- coding: utf-8 -*-
# -*- coding: utf-8 -*-
"""Local and optional Cloud Run verification for Dominion OS auth surfaces."""

from __future__ import annotations

import json
import os
import subprocess
import sys
import urllib.error
import urllib.request
from dataclasses import dataclass


PROJECT = os.getenv("GCP_PROJECT", "dominion-core-prod")
REGION = os.getenv("GCP_REGION", "us-central1")


@dataclass(frozen=True)
class CloudTarget:
    service: str
    path: str
    required: bool = True


CLOUD_TARGETS: tuple[CloudTarget, ...] = (
    CloudTarget("dominion-api", "/health", True),
    CloudTarget("dominion-ui", "/health", True),
    CloudTarget("dominion-identity", "/health", True),
    CloudTarget("dominion-worker", "/health", True),
    # Legacy/optional auth surfaces kept for backward compatibility.
    CloudTarget("dominion-os-demo", "/status", False),
    CloudTarget("phi-oauth-server", "/ready", False),
    CloudTarget("phi-askphi-widget", "/ready", False),
)


@dataclass(frozen=True)
class ProbeTarget:
    name: str
    base_url: str
    path: str
    required: bool = True


def fetch_json(url: str) -> tuple[int | None, dict | None]:
    try:
        with urllib.request.urlopen(url, timeout=10) as response:
            body = response.read().decode("utf-8")
            return response.getcode(), json.loads(body)
    except urllib.error.HTTPError as exc:
        try:
            return exc.code, json.loads(exc.read().decode("utf-8"))
        except Exception:
            return exc.code, None
    except Exception:
        return None, None


def cloud_run_url(service: str) -> str | None:
    try:
        result = subprocess.run(
            [
                "gcloud",
                "run",
                "services",
                "describe",
                service,
                f"--project={PROJECT}",
                f"--region={REGION}",
                "--format=value(status.url)",
            ],
            check=True,
            capture_output=True,
            text=True,
        )
    except Exception:
        return None
    return result.stdout.strip() or None


def verify_service(name: str, base_url: str, path: str) -> bool:
    code, payload = fetch_json(base_url.rstrip("/") + path)
    print(f"{name}: {base_url}{path} -> {code}")
    if payload is not None:
        print(json.dumps(payload, indent=2))
    return bool(
        code
        and 200 <= code < 300
        and payload
        and payload.get("status") in {"healthy", "ready", "ok"}
    )


def verify_local_target(target: ProbeTarget) -> bool:
    ok = verify_service(target.name, target.base_url, target.path)
    if not ok and not target.required:
        print(f"{target.name}: optional local probe did not pass; continuing")
        return True
    return ok


def main() -> int:
    ok = True

    local_targets = [
        ProbeTarget(
            "command_center_demo_local",
            os.getenv("COMMAND_CENTER_URL", "http://127.0.0.1:5000"),
            "/health",
            required=False,
        ),
        ProbeTarget(
            "oauth_local",
            os.getenv("OAUTH_SERVER_URL", "http://127.0.0.1:8080"),
            "/ready",
        ),
        ProbeTarget(
            "widget_local",
            os.getenv("ASKPHI_WIDGET_URL", "http://127.0.0.1:8081"),
            "/ready",
        ),
        ProbeTarget(
            "java_live_ops_local",
            os.getenv("JAVA_SITE_URL", "http://127.0.0.1:8090"),
            "/ready",
            required=False,
        ),
    ]
    print("Local verification")
    for target in local_targets:
        ok = verify_local_target(target) and ok

    print("\nCloud Run verification")
    cloud_ok = True
    discovered = False
    for target in CLOUD_TARGETS:
        url = cloud_run_url(target.service)
        if not url:
            if target.required:
                print(f"{target.service}: unavailable from gcloud (required)")
                cloud_ok = False
            else:
                print(f"{target.service}: unavailable from gcloud (optional)")
            continue
        discovered = True
        service_ok = verify_service(target.service, url, target.path)
        if target.required:
            cloud_ok = service_ok and cloud_ok
        elif not service_ok:
            print(f"{target.service}: optional cloud probe did not pass; continuing")

    if discovered:
        ok = ok and cloud_ok

    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
