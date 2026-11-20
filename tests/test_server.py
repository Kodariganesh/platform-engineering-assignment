"""Tests for the platform engineering FastAPI service."""

from fastapi.testclient import TestClient
import pytest

from app.server import app


@pytest.fixture
def client():
    with TestClient(app) as test_client:
        yield test_client


def test_home_returns_greeting(client):
    response = client.get("/")

    assert response.status_code == 200
    assert response.text == "Hello from the platform engineering team!\n"


def test_health_returns_ok(client):
    response = client.get("/health")

    assert response.status_code == 200
    assert response.text == "OK\n"


def test_unknown_path_returns_not_found(client):
    response = client.get("/missing")

    assert response.status_code == 404
