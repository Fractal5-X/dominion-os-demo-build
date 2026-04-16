"""
PHI Chief AI - AskPhi OAuth Server.

Production intent:
- liveness succeeds when the process is serving traffic
- readiness fails when required auth configuration is missing
- JWT/session secrets are stable across restarts via environment variables
"""

from __future__ import annotations

import base64
import hashlib
import os
import secrets
import time
from datetime import datetime, timedelta, timezone
from http import HTTPStatus
from pathlib import Path
from urllib.parse import quote

import jwt
import requests
from dotenv import load_dotenv
from flask import Flask, jsonify, redirect, render_template_string, request, session
from flask_cors import CORS

APP_DIR = Path(__file__).resolve().parent
for env_file in (APP_DIR / ".env", APP_DIR.parent / ".env", APP_DIR.parent / ".env.desktop-pro"):
    if env_file.exists():
        load_dotenv(env_file, override=False)


def env_first(*names: str, default: str = "") -> str:
    for name in names:
        value = os.getenv(name)
        if value and value.strip():
            return value.strip()
    return default


def env_truthy(name: str, default: bool) -> bool:
    value = os.getenv(name)
    if value is None:
        return default
    return value.lower() not in {"0", "false", "no", "off"}


ENVIRONMENT = env_first("ENV", "FLASK_ENV", default="production")
REQUEST_TIMEOUT_SECONDS = float(env_first("REQUEST_TIMEOUT_SECONDS", default="10"))
GITHUB_RETRY_ATTEMPTS = int(env_first("GITHUB_RETRY_ATTEMPTS", default="3"))
GITHUB_RETRY_BACKOFF_SECONDS = float(env_first("GITHUB_RETRY_BACKOFF_SECONDS", default="1"))
GITHUB_MIN_INTERVAL_SECONDS = float(env_first("GITHUB_MIN_INTERVAL_SECONDS", default="0.5"))
AUTHORIZED_ORGS = tuple(
    org.strip()
    for org in env_first("AUTHORIZED_GITHUB_ORGS", default="Fractal5-Solutions").split(",")
    if org.strip()
)
GITHUB_CLIENT_ID = env_first("GITHUB_CLIENT_ID", "OAUTH_CLIENT_ID")
GITHUB_CLIENT_SECRET = env_first("GITHUB_CLIENT_SECRET", "OAUTH_CLIENT_SECRET")
JWT_SECRET = env_first("JWT_SECRET", "JWT_SECRET_KEY", "SECRET_KEY")
SESSION_SECRET = env_first("SESSION_SECRET", "FLASK_SECRET_KEY", "SECRET_KEY")
OAUTH_BASE_URL = env_first("OAUTH_BASE_URL").rstrip("/")
WIDGET_BASE_URL = env_first("ASKPHI_WIDGET_URL").rstrip("/")
COOKIE_SECURE = env_truthy("COOKIE_SECURE", default=bool(OAUTH_BASE_URL.startswith("https://")))

PLACEHOLDER_VALUES = {
    "",
    "your_client_id_here",
    "your_client_secret_here",
    "change-me",
}

app = Flask(__name__)
app.config.update(
    SESSION_COOKIE_HTTPONLY=True,
    SESSION_COOKIE_SAMESITE="Lax",
    SESSION_COOKIE_SECURE=COOKIE_SECURE,
)
app.secret_key = SESSION_SECRET or secrets.token_hex(32)
CORS(app, resources={r"/api/*": {"origins": "*"}})
_last_github_request_at = 0.0


def utcnow_iso() -> str:
    return datetime.now(timezone.utc).isoformat()


def required_config_status() -> dict[str, bool]:
    return {
        "github_client_id": GITHUB_CLIENT_ID not in PLACEHOLDER_VALUES,
        "github_client_secret": GITHUB_CLIENT_SECRET not in PLACEHOLDER_VALUES,
        "jwt_secret": JWT_SECRET not in PLACEHOLDER_VALUES,
        "session_secret": SESSION_SECRET not in PLACEHOLDER_VALUES,
        "authorized_orgs": bool(AUTHORIZED_ORGS),
    }


def oauth_ready() -> bool:
    return all(required_config_status().values())


def callback_url() -> str:
    if OAUTH_BASE_URL:
        return f"{OAUTH_BASE_URL}/auth/callback"
    return f"{request.host_url.rstrip('/')}/auth/callback"


def chat_redirect_url(token: str) -> str:
    base = WIDGET_BASE_URL or OAUTH_BASE_URL or request.host_url.rstrip("/")
    return f"{base}/chat?token={quote(token)}"


def github_headers(access_token: str) -> dict[str, str]:
    return {
        "Accept": "application/json",
        "Authorization": f"Bearer {access_token}",
        "X-GitHub-Api-Version": "2022-11-28",
    }


def github_request(method: str, url: str, **kwargs) -> requests.Response:
    global _last_github_request_at

    timeout = kwargs.pop("timeout", REQUEST_TIMEOUT_SECONDS)
    last_error: requests.RequestException | None = None

    for attempt in range(1, GITHUB_RETRY_ATTEMPTS + 1):
        elapsed = time.monotonic() - _last_github_request_at
        if elapsed < GITHUB_MIN_INTERVAL_SECONDS:
            time.sleep(GITHUB_MIN_INTERVAL_SECONDS - elapsed)

        response = requests.request(method, url, timeout=timeout, **kwargs)
        _last_github_request_at = time.monotonic()

        if response.status_code == HTTPStatus.TOO_MANY_REQUESTS:
            retry_after = int(response.headers.get("Retry-After", "1") or "1")
            time.sleep(max(retry_after, 1))
            continue

        if response.status_code == HTTPStatus.FORBIDDEN and response.headers.get("X-RateLimit-Remaining") == "0":
            reset_at = int(response.headers.get("X-RateLimit-Reset", "0") or "0")
            delay = max(reset_at - int(time.time()), 1)
            time.sleep(min(delay, 60))
            continue

        if response.status_code >= HTTPStatus.INTERNAL_SERVER_ERROR and attempt < GITHUB_RETRY_ATTEMPTS:
            time.sleep(GITHUB_RETRY_BACKOFF_SECONDS * attempt)
            continue

        return response

    if last_error is not None:
        raise last_error

    raise requests.RequestException(f"GitHub request failed after {GITHUB_RETRY_ATTEMPTS} attempts")


def generate_code_verifier() -> str:
    return secrets.token_urlsafe(64)


def generate_code_challenge(verifier: str) -> str:
    sha256 = hashlib.sha256(verifier.encode("utf-8")).digest()
    return base64.urlsafe_b64encode(sha256).decode("utf-8").rstrip("=")


def verify_state(expected_state: str | None, received_state: str | None) -> bool:
    if not expected_state or not received_state:
        return False
    return secrets.compare_digest(expected_state, received_state)


def health_payload() -> dict:
    config = required_config_status()
    return {
        "service": "phi-oauth-server",
        "environment": ENVIRONMENT,
        "timestamp": utcnow_iso(),
        "status": "healthy",
        "ready": all(config.values()),
        "checks": {
            "config": config,
            "callback_url": bool(callback_url()),
            "widget_base_url": bool(WIDGET_BASE_URL),
        },
    }


@app.after_request
def add_security_headers(response):
    response.headers.setdefault("Cache-Control", "no-store")
    response.headers.setdefault("X-Content-Type-Options", "nosniff")
    response.headers.setdefault("X-Frame-Options", "DENY")
    response.headers.setdefault("Referrer-Policy", "strict-origin-when-cross-origin")
    response.headers.setdefault("Content-Security-Policy", "default-src 'self'; style-src 'self' 'unsafe-inline'; script-src 'self' 'unsafe-inline'; img-src 'self' data:; connect-src 'self' https://github.com https://api.github.com; frame-ancestors 'none'; base-uri 'self'")
    return response


@app.route("/health")
def health():
    return jsonify(health_payload()), HTTPStatus.OK


@app.route("/ready")
def ready():
    payload = health_payload()
    payload["status"] = "ready" if payload["ready"] else "not_ready"
    return (
        jsonify(payload),
        HTTPStatus.OK if payload["ready"] else HTTPStatus.SERVICE_UNAVAILABLE,
    )


@app.route("/")
def index():
    payload = health_payload()
    return render_template_string(
        """
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>PHI OAuth</title>
  <style>
    body { font-family: "IBM Plex Sans", sans-serif; margin: 0; padding: 32px; background: linear-gradient(135deg, #0f0f0f, #5f5f5f); color: #111; }
    .panel { max-width: 720px; margin: 0 auto; background: #fff; border-radius: 24px; padding: 28px; box-shadow: 0 24px 60px rgba(0,0,0,.18); }
    .pill { display: inline-block; padding: 6px 10px; border-radius: 999px; background: #111; color: #fff; font-size: 12px; letter-spacing: .06em; text-transform: uppercase; }
    .meta { margin-top: 16px; color: #555; }
    .warning { margin-top: 18px; padding: 14px 16px; border-radius: 14px; background: #fff1d6; color: #603d00; }
    .action { display: inline-flex; margin-top: 20px; padding: 12px 18px; border-radius: 999px; background: #111; color: #fff; text-decoration: none; font-weight: 600; }
  </style>
</head>
<body>
  <div class="panel">
    <span class="pill">PHI OAuth</span>
    <h1>GitHub authentication gateway</h1>
    <p class="meta">Readiness: {{ "ready" if payload.ready else "not ready" }}. Callback: {{ callback_url }}</p>
    {% if not payload.ready %}
      <div class="warning">Missing required secrets or org configuration. `/ready` will stay failed until those are present.</div>
    {% endif %}
    <a class="action" href="/auth/github">Authenticate with GitHub</a>
  </div>
</body>
</html>
        """,
        payload=payload,
        callback_url=callback_url(),
    )


@app.route("/auth/github")
def github_auth():
    if not oauth_ready():
        return jsonify({"error": "oauth_not_configured", "ready": False}), HTTPStatus.SERVICE_UNAVAILABLE

    code_verifier = generate_code_verifier()
    code_challenge = generate_code_challenge(code_verifier)
    state = secrets.token_urlsafe(32)

    session["code_verifier"] = code_verifier
    session["state"] = state

    params = {
        "client_id": GITHUB_CLIENT_ID,
        "redirect_uri": callback_url(),
        "scope": "read:user read:org",
        "state": state,
        "code_challenge": code_challenge,
        "code_challenge_method": "S256",
    }
    query = "&".join(f"{key}={quote(value)}" for key, value in params.items())
    return redirect(f"https://github.com/login/oauth/authorize?{query}")


@app.route("/auth/callback")
def github_callback():
    error = request.args.get("error")
    if error:
        return redirect(f"/?error={quote(error)}")

    if not verify_state(session.get("state"), request.args.get("state")):
        return redirect("/?error=invalid_state")

    code = request.args.get("code")
    code_verifier = session.get("code_verifier")
    if not code or not code_verifier:
        return redirect("/?error=missing_oauth_context")

    try:
        token_response = github_request(
            "POST",
            "https://github.com/login/oauth/access_token",
            headers={"Accept": "application/json"},
            data={
                "client_id": GITHUB_CLIENT_ID,
                "client_secret": GITHUB_CLIENT_SECRET,
                "code": code,
                "redirect_uri": callback_url(),
                "code_verifier": code_verifier,
            },
        )
        token_response.raise_for_status()
        token_data = token_response.json()
        access_token = token_data.get("access_token")
        if not access_token:
            return redirect("/?error=token_exchange_failed")

        user_response = github_request(
            "GET",
            "https://api.github.com/user",
            headers=github_headers(access_token),
        )
        user_response.raise_for_status()
        user_data = user_response.json()

        org_response = github_request(
            "GET",
            "https://api.github.com/user/orgs",
            headers=github_headers(access_token),
        )
        org_response.raise_for_status()
        user_orgs = [org["login"] for org in org_response.json()]
        if AUTHORIZED_ORGS and not any(org in AUTHORIZED_ORGS for org in user_orgs):
            return redirect("/?error=unauthorized_organization")

        jwt_payload = {
            "sub": str(user_data["id"]),
            "username": user_data["login"],
            "orgs": user_orgs,
            "iat": datetime.now(timezone.utc),
            "exp": datetime.now(timezone.utc) + timedelta(hours=24),
        }
        token = jwt.encode(jwt_payload, JWT_SECRET, algorithm="HS256")
        session.pop("state", None)
        session.pop("code_verifier", None)
        return redirect(chat_redirect_url(token))
    except requests.RequestException:
        return redirect("/?error=github_request_failed")
    except Exception:
        return redirect("/?error=server_error")


@app.route("/chat")
def chat():
    token = request.args.get("token") or request.headers.get("Authorization", "").replace("Bearer ", "")
    if not token:
        return redirect("/")

    try:
        payload = jwt.decode(token, JWT_SECRET, algorithms=["HS256"])
    except jwt.ExpiredSignatureError:
        return redirect("/?error=token_expired")
    except jwt.InvalidTokenError:
        return redirect("/?error=invalid_token")

    username = payload.get("username", "user")
    return render_template_string(
        """
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>PHI Chat</title>
  <style>
    body { font-family: "IBM Plex Sans", sans-serif; background: linear-gradient(135deg, #101010, #707070); margin: 0; padding: 20px; }
    .chat { max-width: 880px; margin: 0 auto; min-height: calc(100vh - 40px); background: #fff; border-radius: 24px; padding: 24px; display: flex; flex-direction: column; }
    .messages { flex: 1; overflow: auto; border: 1px solid #e6e6e6; border-radius: 18px; padding: 16px; margin: 16px 0; }
    .message { margin-bottom: 12px; padding: 12px 14px; border-radius: 14px; max-width: 72%; }
    .phi { background: #f3f3f3; }
    .user { background: #111; color: #fff; margin-left: auto; }
    .composer { display: flex; gap: 10px; }
    input { flex: 1; padding: 12px 14px; border: 1px solid #ccc; border-radius: 999px; }
    button { padding: 12px 18px; border: none; border-radius: 999px; background: #111; color: #fff; }
  </style>
</head>
<body>
  <div class="chat">
    <h1>PHI Chief AI</h1>
    <div>Authenticated as {{ username }}</div>
    <div class="messages" id="messages">
      <div class="message phi"><strong>PHI:</strong> Welcome, {{ username }}.</div>
    </div>
    <div class="composer">
      <input id="messageInput" placeholder="Ask me anything">
      <button id="sendButton" type="button">Send</button>
    </div>
  </div>
  <script>
    const token = {{ token | tojson }};
    const messages = document.getElementById("messages");
    const input = document.getElementById("messageInput");
    document.getElementById("sendButton").addEventListener("click", sendMessage);
    input.addEventListener("keydown", (event) => { if (event.key === "Enter") sendMessage(); });

    function appendMessage(text, sender) {
      const node = document.createElement("div");
      node.className = "message " + sender;
      node.innerHTML = "<strong>" + (sender === "user" ? "You" : "PHI") + ":</strong> " + text;
      messages.appendChild(node);
      messages.scrollTop = messages.scrollHeight;
    }

    async function sendMessage() {
      const message = input.value.trim();
      if (!message) return;
      input.value = "";
      appendMessage(message, "user");
      try {
        const response = await fetch("/api/chat", {
          method: "POST",
          headers: { "Content-Type": "application/json", "Authorization": "Bearer " + token },
          body: JSON.stringify({ message })
        });
        const payload = await response.json();
        appendMessage(payload.response || payload.error || "Unknown error", "phi");
      } catch (error) {
        appendMessage("Request failed.", "phi");
      }
    }
  </script>
</body>
</html>
        """,
        token=token,
        username=username,
    )


@app.route("/api/chat", methods=["POST"])
def chat_api():
    token = request.headers.get("Authorization", "").replace("Bearer ", "")
    payload = request.get_json(silent=True) or {}
    if not token or "message" not in payload:
        return jsonify({"error": "invalid_request"}), HTTPStatus.BAD_REQUEST

    try:
        user_payload = jwt.decode(token, JWT_SECRET, algorithms=["HS256"])
    except jwt.ExpiredSignatureError:
        return jsonify({"error": "token_expired"}), HTTPStatus.UNAUTHORIZED
    except jwt.InvalidTokenError:
        return jsonify({"error": "invalid_token"}), HTTPStatus.UNAUTHORIZED

    return jsonify({"response": generate_phi_response(payload.get("message", ""), user_payload)})


def generate_phi_response(message: str, user_payload: dict) -> str:
    username = user_payload.get("username", "user")
    orgs = ", ".join(user_payload.get("orgs", [])) or "authorized organization"
    lowered = message.lower()
    canned = {
        "hello": f"Hello {username}. Authentication is active for {orgs}.",
        "help": "I can report service status, security posture, and deployment readiness.",
        "status": f"OAuth gateway ready={oauth_ready()}. User {username} authenticated from {orgs}.",
        "security": "OAuth 2.0 with PKCE, signed JWT sessions, org authorization, and readiness validation are active.",
    }
    for key, response in canned.items():
        if key in lowered:
            return response
    return f"I received: '{message}'. Deployment-authenticated session is active for {username}."


if __name__ == "__main__":
    port = int(os.getenv("PORT", "8080"))
    app.run(host="0.0.0.0", port=port, debug=False)
