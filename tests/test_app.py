import pytest
from app.main import app, reset_store
from fastapi.testclient import TestClient


@pytest.fixture(autouse=True)
def _clean_store():
    reset_store()
    yield
    reset_store()


@pytest.fixture
def client():
    return TestClient(app)


def test_health_and_security_headers(client: TestClient):
    response = client.get("/health")
    assert response.status_code == 200
    assert response.json() == {"status": "ok"}
    assert response.headers["x-content-type-options"] == "nosniff"
    assert response.headers["x-frame-options"] == "DENY"
    assert response.headers["referrer-policy"] == "no-referrer"
    assert "frame-ancestors 'none'" in response.headers["content-security-policy"]
    assert response.headers["cross-origin-resource-policy"] == "same-origin"
    assert response.headers["permissions-policy"] == "geolocation=(), microphone=(), camera=()"
    assert response.headers["cache-control"] == "no-store"


def test_root(client: TestClient):
    response = client.get("/")
    assert response.status_code == 200
    assert response.json()["service"] == "devsecops-demo"


def test_item_lifecycle(client: TestClient):
    created = client.post("/items", json={"name": "edge-router", "owner": "netops"})
    assert created.status_code == 201
    body = created.json()
    assert body["id"] == 1
    assert body["name"] == "edge-router"

    listing = client.get("/items")
    assert listing.status_code == 200
    assert listing.json() == [body]

    fetched = client.get("/items/1")
    assert fetched.status_code == 200
    assert fetched.json() == body


def test_validation_and_missing_item(client: TestClient):
    invalid = client.post("/items", json={"name": "", "owner": "netops"})
    assert invalid.status_code == 422
    missing = client.get("/items/404")
    assert missing.status_code == 404
