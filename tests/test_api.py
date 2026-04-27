import pytest
from fastapi.testclient import TestClient
from src.app import app

client = TestClient(app)

def test_health_check():
    response = client.get("/health")
    assert response.status_code == 200
    assert response.json()["status"] == "healthy"

def test_predict_valid():
    response = client.post("/predict", json={"features": [5.1, 3.5, 1.4, 0.2]})
    assert response.status_code == 200
    assert "prediction" in response.json()

def test_predict_invalid():
    response = client.post("/predict", json={"features": []})
    assert response.status_code in [400, 422]
