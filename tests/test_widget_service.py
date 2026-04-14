from widget_service.app import app


def build_client():
    app.config.update(TESTING=True)
    return app.test_client()


def test_widget_homepage_renders_public_safe_command_core():
    client = build_client()
    response = client.get("/")

    assert response.status_code == 200
    assert b"AI Phi - Command Core" in response.data
    assert b"Mode: Public Safe" in response.data


def test_widget_health_contract_is_stable():
    client = build_client()
    response = client.get("/health")

    assert response.status_code == 200
    assert response.json["status"] == "healthy"
    assert response.json["service"] == "askphi-widget"
    assert response.json["mode"] == "PUBLIC_SAFE"


def test_public_chat_returns_public_safe_response():
    client = build_client()
    response = client.post("/api/chat", json={"message": "How does pricing work?"})

    assert response.status_code == 200
    assert response.json["mode"] == "PUBLIC_SAFE"
    assert response.json["topic"] == "pricing"
    assert "Pricing is scope-based" in response.json["response"]
    assert "speaking" in response.json


def test_public_chat_rejects_empty_message():
    client = build_client()
    response = client.post("/api/chat", json={"message": "   "})

    assert response.status_code == 400
    assert response.json["error"] == "message cannot be empty"


def test_bootstrap_exposes_runtime_profile():
    client = build_client()
    response = client.get("/api/bootstrap")

    assert response.status_code == 200
    assert response.json["mode"] == "PUBLIC_SAFE"
    assert response.json["runtime_repo"] == "dominion-os-demo-build"
