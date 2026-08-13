import asyncio
import uuid
from collections.abc import Generator
from datetime import datetime, timedelta, timezone

import jwt
import pytest
from fastapi import HTTPException
from httpx import ASGITransport, AsyncClient, Response
from sqlalchemy import delete, select

from app.api.dependencies import get_current_user
from app.core.config import settings
from app.db.database import SessionLocal
from app.db.models.user import User
from app.main import app
from app.services.auth import create_access_token

TEST_EMAIL = "phase9a@example.com"
PASSWORD = "correct-password"


def request(
    method: str,
    path: str,
    json_body: dict[str, object] | None = None,
) -> Response:
    return asyncio.run(_request(method, path, json_body))


async def _request(
    method: str,
    path: str,
    json_body: dict[str, object] | None,
) -> Response:
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        return await client.request(method, path, json=json_body)


async def _authorized_get(path: str, token: str) -> Response:
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        return await client.get(path, headers={"Authorization": f"Bearer {token}"})


@pytest.fixture(autouse=True)
def clean_auth_users() -> Generator[None, None, None]:
    with SessionLocal() as session:
        session.execute(delete(User).where(User.email.like("phase9a%@example.com")))
        session.commit()
    yield
    with SessionLocal() as session:
        session.execute(delete(User).where(User.email.like("phase9a%@example.com")))
        session.commit()


def register(
    email: str = TEST_EMAIL,
    password: str = PASSWORD,
) -> Response:
    return request(
        "POST",
        "/auth/register",
        {"email": email, "password": password},
    )


def assert_unauthorized(token: str | None) -> None:
    with SessionLocal() as session, pytest.raises(HTTPException) as raised:
        get_current_user(token, session)
    assert raised.value.status_code == 401
    assert raised.value.detail == "Could not validate credentials"


def test_register_normalizes_email_and_returns_token() -> None:
    response = register("  Phase9A@Example.COM  ")

    assert response.status_code == 201
    body = response.json()
    assert body["user"]["email"] == TEST_EMAIL
    assert body["token_type"] == "bearer"
    assert body["access_token"]

    with SessionLocal() as session:
        user = session.scalar(select(User).where(User.email == TEST_EMAIL))
        assert user is not None
        assert str(user.id) == body["user"]["id"]


def test_register_stores_argon2_hash_not_plaintext() -> None:
    assert register().status_code == 201

    with SessionLocal() as session:
        user = session.scalar(select(User).where(User.email == TEST_EMAIL))
        assert user is not None
        assert user.password_hash != PASSWORD
        assert user.password_hash.startswith("$argon2id$")


def test_duplicate_normalized_email_returns_409() -> None:
    assert register().status_code == 201

    response = register(" PHASE9A@example.com ")

    assert response.status_code == 409
    assert response.json() == {"detail": "An account with this email already exists"}


def test_password_shorter_than_eight_characters_is_rejected() -> None:
    response = register(password="short")

    assert response.status_code == 422


def test_login_success_returns_valid_24_hour_jwt() -> None:
    registered = register().json()

    response = request(
        "POST",
        "/auth/login",
        {"email": " PHASE9A@EXAMPLE.COM ", "password": PASSWORD},
    )

    assert response.status_code == 200
    body = response.json()
    assert body["user"] == registered["user"]
    payload = jwt.decode(
        body["access_token"],
        settings.jwt_secret,
        algorithms=[settings.jwt_algorithm],
    )
    assert payload["sub"] == registered["user"]["id"]
    remaining = datetime.fromtimestamp(payload["exp"], timezone.utc) - datetime.now(
        timezone.utc
    )
    assert timedelta(hours=23, minutes=59) < remaining <= timedelta(hours=24)


def test_wrong_password_and_unknown_email_share_generic_401() -> None:
    assert register().status_code == 201

    wrong_password = request(
        "POST",
        "/auth/login",
        {"email": TEST_EMAIL, "password": "wrong-password"},
    )
    unknown_email = request(
        "POST",
        "/auth/login",
        {"email": "phase9a-missing@example.com", "password": "wrong-password"},
    )

    assert wrong_password.status_code == unknown_email.status_code == 401
    assert wrong_password.json() == unknown_email.json() == {
        "detail": "Invalid email or password"
    }


def test_short_wrong_password_still_returns_generic_401() -> None:
    assert register().status_code == 201

    response = request(
        "POST",
        "/auth/login",
        {"email": TEST_EMAIL, "password": "bad"},
    )

    assert response.status_code == 401
    assert response.json() == {"detail": "Invalid email or password"}


def test_get_current_user_accepts_valid_jwt() -> None:
    registered = register().json()

    with SessionLocal() as session:
        user = get_current_user(registered["access_token"], session)

    assert str(user.id) == registered["user"]["id"]
    assert user.email == TEST_EMAIL


def test_auth_me_validates_token_for_client_session_restoration() -> None:
    registered = register().json()

    response = asyncio.run(_authorized_get("/auth/me", registered["access_token"]))

    assert response.status_code == 200
    assert response.json() == registered["user"]


def test_auth_me_rejects_missing_or_invalid_token() -> None:
    missing = request("GET", "/auth/me")
    invalid = asyncio.run(_authorized_get("/auth/me", "not-a-jwt"))

    assert missing.status_code == invalid.status_code == 401


def test_get_current_user_rejects_missing_malformed_and_invalid_signature() -> None:
    assert_unauthorized(None)
    assert_unauthorized("not-a-jwt")
    invalid_signature = jwt.encode(
        {"sub": str(uuid.uuid4()), "exp": datetime.now(timezone.utc) + timedelta(hours=1)},
        "different-test-secret-that-is-at-least-32-bytes",
        algorithm=settings.jwt_algorithm,
    )
    assert_unauthorized(invalid_signature)


def test_get_current_user_rejects_expired_and_invalid_uuid_subject() -> None:
    expired = jwt.encode(
        {"sub": str(uuid.uuid4()), "exp": datetime.now(timezone.utc) - timedelta(seconds=1)},
        settings.jwt_secret,
        algorithm=settings.jwt_algorithm,
    )
    invalid_subject = jwt.encode(
        {"sub": "not-a-uuid", "exp": datetime.now(timezone.utc) + timedelta(hours=1)},
        settings.jwt_secret,
        algorithm=settings.jwt_algorithm,
    )

    assert_unauthorized(expired)
    assert_unauthorized(invalid_subject)


def test_get_current_user_rejects_nonexistent_user_subject() -> None:
    assert_unauthorized(create_access_token(uuid.uuid4()))
