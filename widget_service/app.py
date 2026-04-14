from __future__ import annotations

import os
import re
from datetime import datetime, timezone
from http import HTTPStatus

from flask import Flask, jsonify, request, send_file

app = Flask(__name__)

SERVICE_NAME = "askphi-widget"
PUBLIC_MODE = "PUBLIC_SAFE"
RUNTIME_REPO = os.getenv("PHI_RUNTIME_REPO", "dominion-os-demo-build")
SYSTEM_PROFILE = os.getenv(
    "PHI_SYSTEM_PROFILE",
    "In-house hardware and software optimization profile",
)
CONTACT_URL = os.getenv("PHI_CONTACT_URL", "https://www.fractal5solutions.com/")
MAX_MESSAGE_CHARS = int(os.getenv("PHI_MAX_MESSAGE_CHARS", "600"))


def utcnow_iso() -> str:
    return datetime.now(timezone.utc).isoformat()


def normalize_message(message: str) -> str:
    return re.sub(r"\s+", " ", message).strip()


def classify_topic(message: str) -> str:
    lowered = message.lower()
    if any(token in lowered for token in ("hello", "hi ", "hey", "good morning", "good evening")):
        return "greeting"
    if any(token in lowered for token in ("service", "services", "offer", "what do you do")):
        return "services"
    if any(token in lowered for token in ("capability", "capabilities", "dominion", "platform", "feature")):
        return "capabilities"
    if any(token in lowered for token in ("implement", "implementation", "approach", "deploy", "timeline")):
        return "implementation"
    if any(token in lowered for token in ("price", "pricing", "cost", "quote", "estimate", "budget")):
        return "pricing"
    if any(token in lowered for token in ("runtime", "repo", "in-house", "hardware", "software")):
        return "runtime"
    return "unknown"


def response_for_topic(topic: str) -> str:
    if topic == "greeting":
        return (
            "PHI Public Command Core online. Ask about Fractal5 services, Dominion OS capabilities, "
            "implementation approach, or pricing process."
        )
    if topic == "services":
        return (
            "Fractal5 public-safe service coverage includes sovereign AI systems, intelligence pipelines, "
            "creative engineering, communications systems, and productized Dominion OS applications."
        )
    if topic == "capabilities":
        return (
            "Dominion OS capabilities include agentic orchestration, secure data-to-action pipelines, "
            "and operating surfaces tuned for campaign, enterprise, and mission operations."
        )
    if topic == "implementation":
        return (
            "Implementation is run as a scoped delivery path: mission definition, architecture mapping, "
            "build phase, validation, and controlled rollout with measurable checkpoints."
        )
    if topic == "pricing":
        return (
            "Pricing is scope-based across complexity, timeline, integrations, and support level. "
            "For an accurate estimate, share objective/outcomes, current stack, timeline, and constraints."
        )
    if topic == "runtime":
        return (
            f"Runtime profile: {SYSTEM_PROFILE}. Serving build provenance is {RUNTIME_REPO} in {PUBLIC_MODE} mode."
        )
    return (
        "Public-safe mode can answer services, capabilities, implementation approach, and pricing process. "
        f"For deeper or private scoping, contact: {CONTACT_URL}"
    )


def speaking_profile(message: str) -> dict[str, float | int]:
    words = max(1, len(message.split()))
    intensity = min(1.0, max(0.35, words / 28))
    cadence_ms = int(max(850, min(3200, words * 145)))
    return {"intensity": round(float(intensity), 2), "cadence_ms": cadence_ms}


def health_payload() -> dict:
    return {
        "status": "healthy",
        "service": SERVICE_NAME,
        "mode": PUBLIC_MODE,
        "runtime_repo": RUNTIME_REPO,
        "timestamp": utcnow_iso(),
    }


@app.after_request
def add_headers(response):
    response.headers.setdefault("X-Content-Type-Options", "nosniff")
    response.headers.setdefault("Referrer-Policy", "strict-origin-when-cross-origin")
    response.headers.setdefault("Cache-Control", "no-store")
    response.headers.setdefault(
        "Content-Security-Policy",
        "default-src 'self'; img-src 'self' data:; style-src 'self' 'unsafe-inline'; "
        "script-src 'self' 'unsafe-inline'; connect-src 'self'; font-src 'self' data:; base-uri 'self';",
    )
    return response


@app.route("/")
def serve_widget():
    return send_file("widget.html", mimetype="text/html")


@app.route("/api/bootstrap")
def bootstrap():
    return (
        jsonify(
            {
                "service": SERVICE_NAME,
                "mode": PUBLIC_MODE,
                "opening_message": response_for_topic("greeting"),
                "contact_url": CONTACT_URL,
                "runtime_repo": RUNTIME_REPO,
                "system_profile": SYSTEM_PROFILE,
            }
        ),
        HTTPStatus.OK,
    )


@app.route("/api/chat", methods=["POST"])
def chat():
    payload = request.get_json(silent=True) or {}
    message = payload.get("message")
    if not isinstance(message, str):
        return jsonify({"error": "message must be a string"}), HTTPStatus.BAD_REQUEST

    message = normalize_message(message)
    if not message:
        return jsonify({"error": "message cannot be empty"}), HTTPStatus.BAD_REQUEST
    if len(message) > MAX_MESSAGE_CHARS:
        return jsonify({"error": "message too long"}), HTTPStatus.REQUEST_ENTITY_TOO_LARGE

    topic = classify_topic(message)
    response_text = response_for_topic(topic)
    return (
        jsonify(
            {
                "service": SERVICE_NAME,
                "mode": PUBLIC_MODE,
                "topic": topic,
                "response": response_text,
                "speaking": speaking_profile(response_text),
                "runtime_repo": RUNTIME_REPO,
                "timestamp": utcnow_iso(),
            }
        ),
        HTTPStatus.OK,
    )


@app.route("/health")
@app.route("/ready")
def health():
    return jsonify(health_payload()), HTTPStatus.OK


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=int(os.environ.get("PORT", 8080)))
