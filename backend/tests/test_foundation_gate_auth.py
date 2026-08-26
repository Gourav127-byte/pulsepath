import pytest
from fastapi import status
from httpx import ASGITransport, AsyncClient
from app.main import app
from app.services.sms_provider import ProductionSMSProvider, MockSMSProvider, get_sms_provider


@pytest.mark.anyio
async def test_login_returns_refresh_token(seeded_database):
    async with AsyncClient(
        transport=ASGITransport(app=app), base_url="http://test"
    ) as client:
        # Register a fresh user
        email = "gate_auth_1@example.com"
        pwd = "Password123!"
        reg = await client.post("/auth/register", json={"email": email, "password": pwd})
        assert reg.status_code == status.HTTP_201_CREATED
        assert "refresh_token" in reg.json()

        # Login
        response = await client.post(
            "/auth/login",
            json={"email": email, "password": pwd},
        )
        assert response.status_code == status.HTTP_200_OK
        body = response.json()
        assert "access_token" in body
        assert "refresh_token" in body
        assert body["refresh_token"] is not None


@pytest.mark.anyio
async def test_refresh_token_rotation(seeded_database):
    async with AsyncClient(
        transport=ASGITransport(app=app), base_url="http://test"
    ) as client:
        email = "gate_auth_2@example.com"
        pwd = "Password123!"
        await client.post("/auth/register", json={"email": email, "password": pwd})

        login_res = (
            await client.post(
                "/auth/login",
                json={"email": email, "password": pwd},
            )
        ).json()
        refresh_1 = login_res["refresh_token"]

        # First refresh succeeds and rotates refresh token
        refresh_res = await client.post("/auth/refresh", json={"refresh_token": refresh_1})
        assert refresh_res.status_code == status.HTTP_200_OK
        body = refresh_res.json()
        assert "access_token" in body
        assert "refresh_token" in body
        refresh_2 = body["refresh_token"]
        assert refresh_2 != refresh_1


@pytest.mark.anyio
async def test_refresh_token_reuse_detection(seeded_database):
    async with AsyncClient(
        transport=ASGITransport(app=app), base_url="http://test"
    ) as client:
        email = "gate_auth_3@example.com"
        pwd = "Password123!"
        await client.post("/auth/register", json={"email": email, "password": pwd})

        login_res = (
            await client.post(
                "/auth/login",
                json={"email": email, "password": pwd},
            )
        ).json()
        refresh_1 = login_res["refresh_token"]

        # First refresh uses refresh_1
        await client.post("/auth/refresh", json={"refresh_token": refresh_1})

        # Second refresh using ALREADY-USED refresh_1 triggers reuse detection & revokes family
        reuse_res = await client.post("/auth/refresh", json={"refresh_token": refresh_1})
        assert reuse_res.status_code == status.HTTP_401_UNAUTHORIZED
        assert "reuse" in reuse_res.json()["detail"].lower()


@pytest.mark.anyio
async def test_logout_revokes_token(seeded_database):
    async with AsyncClient(
        transport=ASGITransport(app=app), base_url="http://test"
    ) as client:
        email = "gate_auth_4@example.com"
        pwd = "Password123!"
        await client.post("/auth/register", json={"email": email, "password": pwd})

        login_res = (
            await client.post(
                "/auth/login",
                json={"email": email, "password": pwd},
            )
        ).json()
        refresh_tok = login_res["refresh_token"]

        logout_res = await client.post("/auth/logout", json={"refresh_token": refresh_tok})
        assert logout_res.status_code == status.HTTP_200_OK

        # Subsequent refresh fails
        refresh_res = await client.post("/auth/refresh", json={"refresh_token": refresh_tok})
        assert refresh_res.status_code == status.HTTP_401_UNAUTHORIZED


@pytest.mark.anyio
async def test_phone_otp_flow(seeded_database):
    async with AsyncClient(
        transport=ASGITransport(app=app), base_url="http://test"
    ) as client:
        phone = "+919876543210"
        req_res = await client.post("/auth/phone/request-otp", json={"phone_number": phone})
        assert req_res.status_code == status.HTTP_200_OK
        body = req_res.json()
        assert "cooldown_seconds" in body
        otp = body.get("development_otp")

        if otp:
            verify_res = await client.post(
                "/auth/phone/verify-otp",
                json={"phone_number": phone, "otp": otp},
            )
            assert verify_res.status_code == status.HTTP_200_OK
            assert "access_token" in verify_res.json()
            assert "refresh_token" in verify_res.json()


def test_production_sms_provider_safety(monkeypatch):
    from app.core.config import settings

    # In production without credentials, ProductionSMSProvider MUST raise RuntimeError
    monkeypatch.setattr(settings, "app_env", "production")
    monkeypatch.setattr(settings, "sms_api_key", None)
    with pytest.raises(RuntimeError, match="strictly forbidden"):
        ProductionSMSProvider(api_key=None)
