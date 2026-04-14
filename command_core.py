#!/usr/bin/env python3
"""Unified Dominion OS command surface for demo, store, and topology status."""

from __future__ import annotations

import json
import os
import subprocess
from datetime import datetime, timezone
from pathlib import Path
import re
from urllib.parse import urlparse

import requests
from flask import Flask, abort, jsonify, render_template_string, request, send_from_directory

BASE_DIR = Path(__file__).resolve().parent

app = Flask(__name__)
app.config["JSON_SORT_KEYS"] = False
app.config["ENABLE_PROBES"] = os.getenv("COMMAND_CORE_ENABLE_PROBES", "1").lower() not in {
    "0",
    "false",
    "no",
}

APP_VERSION = os.getenv("APP_VERSION", "1.2.0")
SERVICE_NAME = os.getenv("SERVICE_NAME", "dominion-os-demo")
REGION = os.getenv("REGION", os.getenv("GCP_REGION", "us-central1"))
PROJECT_ID = os.getenv("PROJECT_ID", os.getenv("GCP_PROJECT_ID", "dominion-os-1-0-main"))
OVERLAY = os.getenv("OVERLAY", "business")
RELEASE_SHA = os.getenv("RELEASE_SHA", "")
SOURCE_OF_TRUTH_REPO = os.getenv("SOURCE_OF_TRUTH_REPO", "dominion-command-center")
SOURCE_OF_TRUTH_SHA = os.getenv("SOURCE_OF_TRUTH_SHA", "")
SOURCE_OF_TRUTH_VERSION = os.getenv("SOURCE_OF_TRUTH_VERSION", "")
IMAGE_REF = os.getenv("IMAGE_REF", "")
RELEASE_REPO = os.getenv("RELEASE_REPO", "dominion-os-demo-build")

LOCAL_SERVICE_TARGETS = (
    {
        "id": "command-center-bims",
        "name": "Command Center BIMS",
        "role": "financial-demo",
        "url": os.getenv("COMMAND_CENTER_URL", "http://127.0.0.1:5000"),
        "health_paths": ("/health", "/healthz"),
    },
    {
        "id": "phi-oauth-server",
        "name": "PHI OAuth Server",
        "role": "auth-gateway",
        "url": os.getenv("OAUTH_SERVER_URL", "http://127.0.0.1:8080"),
        "health_paths": ("/health", "/ready"),
    },
    {
        "id": "phi-askphi-widget",
        "name": "PHI AskPHI Widget",
        "role": "public-safe-chat",
        "url": os.getenv("ASKPHI_WIDGET_URL", "http://127.0.0.1:8081"),
        # Include all known widget health routes across deployments.
        "health_paths": ("/health", "/ready", "/healthz"),
    },
    {
        "id": "dominion-java-live-ops-site",
        "name": "Dominion Java Live Ops Site",
        "role": "sovereign-live-ops-java",
        "url": os.getenv("JAVA_SITE_URL", "http://127.0.0.1:8090"),
        "health_paths": ("/ready", "/health", "/healthz"),
    },
)

REMOTE_TELEMETRY_FILES = {
    "dominion-os-1-0-main": BASE_DIR / "scripts" / "telemetry" / "services_project1.txt",
    "dominion-core-prod": BASE_DIR / "scripts" / "telemetry" / "services_project2.txt",
}

LANDING_TEMPLATE = """
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Dominion OS Command Core</title>
    <style>
        :root {
            --ink: #000000;
            --paper: #ffffff;
            --mist: #f5f5f5;
            --steel: #d9d9d9;
            --ash: #797979;
        }
        * { box-sizing: border-box; }
        body {
            margin: 0;
            font-family: "Manrope", "Segoe UI", system-ui, -apple-system, Roboto, Arial, sans-serif;
            color: var(--ink);
            background:
                radial-gradient(circle at top left, var(--steel), transparent 35%),
                linear-gradient(135deg, var(--paper), var(--mist));
        }
        main {
            max-width: 1100px;
            margin: 0 auto;
            padding: 48px 24px 72px;
        }
        .hero {
            display: grid;
            gap: 20px;
            padding: 32px;
            border: 1px solid var(--steel);
            border-radius: 28px;
            background: var(--paper);
            box-shadow: 0 24px 60px var(--steel);
        }
        .eyebrow {
            display: inline-flex;
            width: fit-content;
            padding: 6px 12px;
            border-radius: 999px;
            background: var(--ink);
            color: var(--paper);
            font-size: 0.85rem;
            letter-spacing: 0.08em;
            text-transform: uppercase;
        }
        h1 {
            margin: 0;
            font-size: clamp(2.8rem, 6vw, 4.7rem);
            line-height: 0.95;
        }
        p {
            margin: 0;
            max-width: 62ch;
            color: var(--ash);
            font-size: 1.05rem;
        }
        .actions {
            display: flex;
            flex-wrap: wrap;
            gap: 12px;
        }
        .btn {
            display: inline-flex;
            align-items: center;
            justify-content: center;
            min-height: 48px;
            padding: 0 18px;
            border-radius: 999px;
            text-decoration: none;
            font-weight: 600;
            transition: transform 0.18s ease, background 0.18s ease;
        }
        .btn:hover { transform: translateY(-1px); }
        .btn-primary {
            background: var(--ink);
            color: var(--paper);
        }
        .btn-secondary {
            background: transparent;
            color: var(--ink);
            border: 1px solid var(--steel);
        }
        .grid {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(220px, 1fr));
            gap: 16px;
            margin-top: 24px;
        }
        .card {
            padding: 20px;
            border-radius: 22px;
            background: var(--paper);
            border: 1px solid var(--steel);
        }
        .card strong {
            display: block;
            margin-bottom: 10px;
            font-size: 1rem;
        }
        .meta {
            margin-top: 24px;
            color: var(--ash);
            font-size: 0.92rem;
        }
    </style>
</head>
<body>
    <main>
        <section class="hero">
            <span class="eyebrow">Command Core</span>
            <h1>One surface for the demo, store, and live topology.</h1>
            <p>
                This app is the production-safe entrypoint expected by the repo's
                Docker and Cloud Run configuration. It serves the polished
                <code>/demo</code> and <code>/store</code> routes, exposes API-backed
                product data, and reports local plus telemetry-defined remote wiring.
            </p>
            <div class="actions">
                <a class="btn btn-primary" href="/demo">Open /demo</a>
                <a class="btn btn-secondary" href="/store">Open /store</a>
                <a class="btn btn-secondary" href="/status">View /status</a>
            </div>
            <div class="grid">
                <div class="card">
                    <strong>Service</strong>
                    <span>{{ info.service }}</span>
                </div>
                <div class="card">
                    <strong>Products</strong>
                    <span>{{ product_count }} sellable SKUs</span>
                </div>
                <div class="card">
                    <strong>Telemetry</strong>
                    <span>{{ project_count }} GCP projects mapped</span>
                </div>
                <div class="card">
                    <strong>Health</strong>
                    <span><a href="/health">/health</a>, <a href="/ready">/ready</a>, <a href="/healthz">/healthz</a></span>
                </div>
            </div>
            <div class="meta">
                Version {{ info.version }} · Project {{ info.project_id }} · Region {{ info.region }}
            </div>
        </section>
    </main>
</body>
</html>
"""


def now_iso() -> str:
    return datetime.now(timezone.utc).isoformat()


def resolve_release_sha() -> str:
    if RELEASE_SHA:
        return RELEASE_SHA
    try:
        output = subprocess.check_output(
            ["git", "rev-parse", "--short=12", "HEAD"],
            cwd=BASE_DIR,
            text=True,
            stderr=subprocess.DEVNULL,
        )
        return output.strip()
    except (OSError, subprocess.CalledProcessError):
        return ""


def release_info() -> dict:
    return {
        "version": APP_VERSION,
        "release_sha": resolve_release_sha(),
        "release_repo": RELEASE_REPO,
        "overlay": OVERLAY,
        "image_ref": IMAGE_REF,
        "source_of_truth": {
            "repo": SOURCE_OF_TRUTH_REPO,
            "sha": SOURCE_OF_TRUTH_SHA,
            "version": SOURCE_OF_TRUTH_VERSION,
        },
    }


def wants_json_response() -> bool:
    best = request.accept_mimetypes.best_match(["application/json", "text/html"])
    return best == "application/json" and (
        request.accept_mimetypes[best] >= request.accept_mimetypes["text/html"]
    )


def parse_probe_flags() -> tuple[bool, bool, list[str]]:
    probe_raw = request.args.get("probe", "").strip().lower()
    if not probe_raw:
        return False, False, []

    parts = [part for part in re.split(r"[,\s]+", probe_raw) if part]
    tokens = set(parts)

    # Backward-compatible shorthand: probe=1|true enables local probes only.
    if probe_raw in {"1", "true", "yes", "on"}:
        tokens.add("local")
    if "all" in tokens:
        tokens.update({"local", "remote"})

    local_requested = "local" in tokens
    remote_requested = "remote" in tokens
    return local_requested, remote_requested, sorted(tokens)


def read_json_file(path: Path, default):
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except FileNotFoundError:
        return default
    except json.JSONDecodeError:
        return default


def is_safe_slug(value: str) -> bool:
    if not value:
        return False
    if value.startswith(".") or ".." in value or "/" in value or "\\" in value:
        return False
    return re.fullmatch(r"[A-Za-z0-9._-]+", value) is not None


def url_port(url: str) -> int | None:
    parsed = urlparse(url)
    if parsed.port:
        return parsed.port
    if parsed.scheme == "https":
        return 443
    if parsed.scheme == "http":
        return 80
    return None


def probe_service(base_url: str, health_paths: tuple[str, ...], enabled: bool) -> dict:
    if not enabled:
        return {"status": "not_probed", "healthy": None}

    last_error = ""
    last_status_code = None
    last_checked_url = f"{base_url.rstrip('/')}{health_paths[0]}"
    for health_path in health_paths:
        target = f"{base_url.rstrip('/')}{health_path}"
        last_checked_url = target
        try:
            response = requests.get(target, timeout=2, allow_redirects=False)
            healthy = 200 <= response.status_code < 400
            if healthy:
                return {
                    "status": "healthy",
                    "healthy": True,
                    "checked_url": target,
                    "status_code": response.status_code,
                }
            last_status_code = response.status_code
            last_error = f"HTTP {response.status_code}"
        except requests.RequestException as exc:
            last_error = str(exc)

    if last_status_code is not None:
        return {
            "status": "degraded",
            "healthy": False,
            "checked_url": last_checked_url,
            "status_code": last_status_code,
        }

    return {
        "status": "unreachable",
        "healthy": False,
        "checked_url": last_checked_url,
        "error": last_error or "Connection failed",
    }


def load_products() -> list[dict]:
    products: list[dict] = []
    for product_file in sorted((BASE_DIR / "products").glob("*/product.json")):
        payload = read_json_file(product_file, {})
        if not payload:
            continue
        slug = product_file.parent.name
        payload["slug"] = slug
        payload["spec_path"] = f"/api/products/{slug}"
        products.append(payload)

    if products:
        return products

    return read_json_file(BASE_DIR / "store" / "api_products.json", [])


def load_demo_experience() -> dict:
    local_urls = {service["id"]: service["url"] for service in LOCAL_SERVICE_TARGETS}

    config = read_json_file(BASE_DIR / "demo" / "config.json", {})
    accessibility = read_json_file(BASE_DIR / "demo" / "components" / "accessibility.json", {})
    tutorials = read_json_file(BASE_DIR / "demo" / "components" / "tutorials.json", {})
    performance = read_json_file(BASE_DIR / "demo" / "optimization" / "performance.json", {})
    return {
        "config": config.get("demo", {}),
        "accessibility": accessibility.get("accessibility_features", {}),
        "tutorials": tutorials.get("interactive_tutorials", {}),
        "performance": performance.get("performance_optimization", {}),
        "links": {
            "command_center": local_urls.get("command-center-bims", "http://127.0.0.1:5000"),
            "oauth": local_urls.get("phi-oauth-server", "http://127.0.0.1:8080"),
            "widget": local_urls.get("phi-askphi-widget", "http://127.0.0.1:8081"),
            "java_live_ops": local_urls.get(
                "dominion-java-live-ops-site",
                "http://127.0.0.1:8090",
            ),
        },
    }


def load_remote_projects() -> dict:
    remote_projects: dict[str, dict] = {}
    for project_id, telemetry_file in REMOTE_TELEMETRY_FILES.items():
        services = []
        try:
            lines = telemetry_file.read_text(encoding="utf-8").splitlines()
        except FileNotFoundError:
            lines = []

        for line in lines[1:]:
            stripped = line.strip()
            if not stripped:
                continue
            parts = stripped.rsplit(None, 1)
            if len(parts) != 2:
                continue
            name, url = parts
            services.append({"name": name, "url": url})

        remote_projects[project_id] = {"services": services, "count": len(services)}
    return remote_projects


def service_info() -> dict:
    remote_projects = load_remote_projects()
    return {
        "service": SERVICE_NAME,
        **release_info(),
        "timestamp": now_iso(),
        "project_id": PROJECT_ID,
        "region": REGION,
        "routes": {
            "health": "/health",
            "ready": "/ready",
            "status": "/status",
            "demo": "/demo",
            "store": "/store",
            "products_api": "/api/products",
            "topology_api": "/api/v1/topology",
        },
        "remote_projects": {
            project_id: project["count"] for project_id, project in remote_projects.items()
        },
    }


def build_topology(local_probe: bool, remote_probe: bool) -> dict:
    local_services = [
        {
            **service,
            "port": url_port(service["url"]),
            "probe": probe_service(service["url"], service["health_paths"], local_probe),
        }
        for service in LOCAL_SERVICE_TARGETS
    ]

    remote_projects = load_remote_projects()
    if remote_probe:
        for project in remote_projects.values():
            for service in project["services"]:
                service["probe"] = probe_service(service["url"], ("/health",), True)

    return {
        "local_services": local_services,
        "remote_projects": remote_projects,
    }


def send_static_page(directory: str):
    # Validate directory to prevent path traversal
    allowed_dirs = {"demo", "store"}
    if directory not in allowed_dirs:
        abort(404)
    return send_from_directory(str(BASE_DIR / directory), "index.html")


@app.after_request
def add_security_headers(response):
    response.headers.setdefault("X-Content-Type-Options", "nosniff")
    response.headers.setdefault("X-Frame-Options", "DENY")
    response.headers.setdefault("Referrer-Policy", "strict-origin-when-cross-origin")
    response.headers.setdefault("Permissions-Policy", "camera=(), microphone=(), geolocation=()")
    response.headers.setdefault("Cross-Origin-Opener-Policy", "same-origin")
    response.headers.setdefault("Content-Security-Policy", (
        "default-src 'self'; "
        "img-src 'self' data:; "
        "style-src 'self' 'unsafe-inline'; "
        "script-src 'self' 'unsafe-inline'; "
        "font-src 'self' data:; "
        "connect-src 'self'; "
        "base-uri 'self'; "
        "frame-ancestors 'none'; "
        "form-action 'self' mailto:"
    ))

    if request.path.startswith("/api/") or request.path in {
        "/health",
        "/healthz",
        "/ready",
        "/status",
        "/_ah/health",
    }:
        response.headers.setdefault("Cache-Control", "no-store")

    return response


@app.route("/")
def index():
    info = service_info()
    if wants_json_response() or request.args.get("format") == "json":
        return jsonify(info)

    remote_projects = load_remote_projects()
    return render_template_string(
        LANDING_TEMPLATE,
        info=info,
        product_count=len(load_products()),
        project_count=len(remote_projects),
    )


@app.route("/health")
@app.route("/healthz")
@app.route("/ready")
@app.route("/_ah/health")
def health():
    return jsonify(
        {
            "status": "healthy",
            "service": SERVICE_NAME,
            **release_info(),
            "timestamp": now_iso(),
        }
    )


@app.route("/status")
def status():
    local_requested, remote_requested, tokens = parse_probe_flags()
    local_probe = (
        app.config.get("ENABLE_PROBES", True)
        and not app.testing
        and local_requested
    )
    remote_probe = remote_requested
    return jsonify(
        {
            **service_info(),
            "probe": {
                "tokens": tokens,
                "local_enabled": bool(local_probe),
                "remote_enabled": bool(remote_probe),
            },
            "inventory": {
                "product_count": len(load_products()),
                "tutorial_count": len(load_demo_experience()["tutorials"]),
            },
            "topology": build_topology(local_probe=local_probe, remote_probe=remote_probe),
        }
    )


@app.route("/demo")
def demo_page():
    return send_static_page("demo")


@app.route("/store")
def store_page():
    return send_static_page("store")


@app.route("/api/products")
@app.route("/api/v1/products")
def products_api():
    return jsonify(load_products())


@app.route("/api/products/<slug>")
def product_detail(slug: str):
    # Accept repo slugs like dominion-os-1.0-gcloud while blocking traversal.
    if not is_safe_slug(slug):
        abort(400)
    product_file = BASE_DIR / "products" / slug / "product.json"
    payload = read_json_file(product_file, None)
    if payload is None:
        abort(404)
    payload["slug"] = slug
    payload["spec_path"] = f"/api/products/{slug}"
    return jsonify(payload)


@app.route("/api/demo/experience")
@app.route("/api/v1/demo/experience")
def demo_experience_api():
    demo_payload = load_demo_experience()
    demo_payload["pages"] = {"demo": "/demo", "store": "/store"}
    return jsonify(demo_payload)


@app.route("/api/v1/topology")
def topology_api():
    local_requested, remote_requested, _tokens = parse_probe_flags()
    local_probe = (
        app.config.get("ENABLE_PROBES", True)
        and not app.testing
        and local_requested
    )
    remote_probe = remote_requested
    return jsonify(build_topology(local_probe=local_probe, remote_probe=remote_probe))


if __name__ == "__main__":
    port = int(os.getenv("PORT", "8080"))
    app.run(host="0.0.0.0", port=port, debug=False)
