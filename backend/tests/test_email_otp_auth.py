import pytest
from httpx import ASGITransport, AsyncClient

from app.main import app


@pytest.mark.anyio
async def test_email_otp_request_and_verify_success(seeded_database) -> None:
    async with AsyncClient(
        transport=ASGITransport(app=app), base_url="http://test"
    ) as client:
        # 1. Request Email OTP
        email = "testemailotp@example.com"
        resp = await client.post("/auth/email/request-otp", json={"email": email})
        assert resp.status_code == 200
        data = resp.json()
        assert "If this email is valid" in data["message"]
        assert isinstance(data["cooldown_seconds"], int)
        assert data["development_otp"] is not None
        otp_code = data["development_otp"]

        # 2. Verify Email OTP
        verify_resp = await client.post("/auth/email/verify-otp", json={"email": email, "otp": otp_code})
        assert verify_resp.status_code == 200
        session_data = verify_resp.json()
        assert "access_token" in session_data
        assert "refresh_token" in session_data
        assert session_data["user"]["email"] == email


@pytest.mark.anyio
async def test_email_otp_cooldown_enforced(seeded_database) -> None:
    async with AsyncClient(
        transport=ASGITransport(app=app), base_url="http://test"
    ) as client:
        email = "cooldownemail@example.com"
        resp1 = await client.post("/auth/email/request-otp", json={"email": email})
        assert resp1.status_code == 200

        # Immediate second request triggers cooldown response
        resp2 = await client.post("/auth/email/request-otp", json={"email": email})
        assert resp2.status_code == 200
        data = resp2.json()
        assert data["cooldown_seconds"] <= 60
        assert data["development_otp"] is None


@pytest.mark.anyio
async def test_email_otp_invalid_code_rejected(seeded_database) -> None:
    async with AsyncClient(
        transport=ASGITransport(app=app), base_url="http://test"
    ) as client:
        email = "invalidemailotp@example.com"
        await client.post("/auth/email/request-otp", json={"email": email})

        # Verify with wrong OTP
        verify_resp = await client.post("/auth/email/verify-otp", json={"email": email, "otp": "999999"})
        assert verify_resp.status_code == 400
        assert "invalid or expired" in verify_resp.json()["detail"].lower()
