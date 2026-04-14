from command_center_demo.app import app


def test_command_center_demo_supports_health_aliases():
    app.config.update(TESTING=True)
    client = app.test_client()

    health = client.get("/health")
    healthz = client.get("/healthz")

    assert health.status_code == 200
    assert healthz.status_code == 200
    assert health.json["status"] == "healthy"
    assert healthz.json["status"] == "healthy"
