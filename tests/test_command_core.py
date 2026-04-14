import command_core


def build_client():
    command_core.app.config.update(TESTING=True, ENABLE_PROBES=False)
    return command_core.app.test_client()


def test_health_endpoints_are_available():
    client = build_client()

    for path in ("/health", "/healthz", "/ready", "/_ah/health"):
        response = client.get(path)
        assert response.status_code == 200
        assert response.json["status"] == "healthy"


def test_root_supports_json_negotiation():
    client = build_client()
    response = client.get("/", headers={"Accept": "application/json"})

    assert response.status_code == 200
    assert response.is_json
    assert response.json["service"] == "dominion-os-demo"
    assert response.json["release_repo"] == "dominion-os-demo-build"
    assert response.json["overlay"] == "business"
    assert response.json["source_of_truth"]["repo"] == "dominion-command-center"


def test_demo_and_store_pages_render():
    client = build_client()

    demo_response = client.get("/demo")
    store_response = client.get("/store")

    assert demo_response.status_code == 200
    assert b'data-contract="demo-shell"' in demo_response.data
    assert store_response.status_code == 200
    assert b'data-contract="store-shell"' in store_response.data


def test_products_api_exposes_repo_inventory():
    client = build_client()
    response = client.get("/api/products")

    assert response.status_code == 200
    assert len(response.json) == 3
    assert {product["slug"] for product in response.json} == {
        "dominion-cloud-computer",
        "dominion-os-1.0-desktop-pc",
        "dominion-os-1.0-gcloud",
    }


def test_product_detail_route_exposes_single_spec():
    client = build_client()
    response = client.get("/api/products/dominion-os-1.0-gcloud")

    assert response.status_code == 200
    assert response.json["sku"] == "DOM-OS-GCLOUD-001"


def test_status_reports_local_topology_without_live_probes():
    client = build_client()
    response = client.get("/status")

    assert response.status_code == 200
    assert response.json["release_repo"] == "dominion-os-demo-build"
    assert response.json["overlay"] == "business"
    assert response.json["source_of_truth"]["repo"] == "dominion-command-center"
    topology = response.json["topology"]
    assert len(topology["local_services"]) == 4
    assert {
        service["id"] for service in topology["local_services"]
    } == {
        "command-center-bims",
        "phi-oauth-server",
        "phi-askphi-widget",
        "dominion-java-live-ops-site",
    }
    assert set(topology["remote_projects"]) == {"dominion-os-1-0-main", "dominion-core-prod"}


def test_health_reports_release_contract():
    client = build_client()
    response = client.get("/health")

    assert response.status_code == 200
    assert response.json["status"] == "healthy"
    assert response.json["release_repo"] == "dominion-os-demo-build"
    assert response.json["overlay"] == "business"
    assert response.json["source_of_truth"]["repo"] == "dominion-command-center"
    assert "release_sha" in response.json
