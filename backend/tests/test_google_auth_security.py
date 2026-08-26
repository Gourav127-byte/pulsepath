import jwt
import pytest
from fastapi.testclient import TestClient

from app.main import app
from app.services.auth import verify_google_id_token

client = TestClient(app)

_TEST_JWT_PAYLOAD = jwt.encode(
    {"sub": "google-test-sub", "email": "google-user@test.com"},
    "dummy-secret",
    algorithm="HS256",
)
TEST_GOOGLE_TOKEN = f"test_google_token_{_TEST_JWT_PAYLOAD}"


def test_synthetic_test_google_token_accepted_in_test_env() -> None:
    payload = verify_google_id_token(TEST_GOOGLE_TOKEN)
    assert payload["sub"] == "google-test-sub"
    assert payload["email"] == "google-user@test.com"


def test_invalid_google_issuer_rejected() -> None:
    fake_token = jwt.encode(
        {"sub": "12345", "iss": "https://evil.com", "email": "evil@test.com"},
        "secret",
        algorithm="HS256",
    )
    with pytest.raises(ValueError, match="Google ID token"):
        verify_google_id_token(fake_token)


def test_google_auth_endpoint_creates_user() -> None:
    res = client.post("/auth/google", json={"id_token": TEST_GOOGLE_TOKEN})
    assert res.status_code == 200
    data = res.json()
    assert "access_token" in data
    assert "refresh_token" in data
    assert data["user"]["email"] == "google-user@test.com"
