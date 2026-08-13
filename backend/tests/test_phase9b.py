import asyncio
from collections.abc import Generator
from datetime import datetime, timedelta, timezone

import pytest
from httpx import ASGITransport, AsyncClient, Response
from sqlalchemy import delete, select
from sqlalchemy.exc import SQLAlchemyError
from sqlalchemy.orm import Session

from app.api.auth import FORGOT_PASSWORD_MESSAGE, RESET_PASSWORD_ERROR
from app.core.config import settings
from app.db.database import SessionLocal
from app.db.models.password_reset_token import PasswordResetToken
from app.db.models.user import User
from app.main import app
from app.services.auth import hash_password_reset_token

EMAIL = "phase9b@example.com"
OLD_PASSWORD = "old-password"
NEW_PASSWORD = "new-password"


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


@pytest.fixture(autouse=True)
def clean_password_reset_data(monkeypatch: pytest.MonkeyPatch) -> Generator[None, None, None]:
    monkeypatch.setattr(settings, "expose_password_reset_token", False)
    with SessionLocal() as session:
        session.execute(delete(User).where(User.email.like("phase9b%@example.com")))
        session.commit()
    yield
    with SessionLocal() as session:
        session.execute(delete(User).where(User.email.like("phase9b%@example.com")))
        session.commit()


def register() -> Response:
    return request(
        "POST",
        "/auth/register",
        {"email": EMAIL, "password": OLD_PASSWORD},
    )


def forgot_with_development_token(monkeypatch: pytest.MonkeyPatch) -> str:
    monkeypatch.setattr(settings, "expose_password_reset_token", True)
    response = request("POST", "/auth/forgot-password", {"email": EMAIL})
    assert response.status_code == 200
    token = response.json().get("development_reset_token")
    assert isinstance(token, str)
    return token


def login(password: str) -> Response:
    return request(
        "POST",
        "/auth/login",
        {"email": EMAIL, "password": password},
    )


def reset(token: str, new_password: str = NEW_PASSWORD) -> Response:
    return request(
        "POST",
        "/auth/reset-password",
        {"token": token, "new_password": new_password},
    )


def test_forgot_known_and_unknown_email_have_identical_public_response() -> None:
    assert register().status_code == 201

    known = request(
        "POST",
        "/auth/forgot-password",
        {"email": " PHASE9B@EXAMPLE.COM "},
    )
    unknown = request(
        "POST",
        "/auth/forgot-password",
        {"email": "phase9b-missing@example.com"},
    )

    expected = {"message": FORGOT_PASSWORD_MESSAGE}
    assert known.status_code == unknown.status_code == 200
    assert known.json() == unknown.json() == expected


def test_known_user_reset_token_is_stored_only_as_sha256_hash(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    assert register().status_code == 201
    raw_token = forgot_with_development_token(monkeypatch)

    with SessionLocal() as session:
        stored = session.scalar(
            select(PasswordResetToken).where(
                PasswordResetToken.token_hash == hash_password_reset_token(raw_token)
            )
        )
        assert stored is not None
        assert stored.token_hash != raw_token
        assert len(stored.token_hash) == 64
        assert stored.used_at is None


def test_valid_reset_changes_login_password_and_consumes_token(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    assert register().status_code == 201
    token = forgot_with_development_token(monkeypatch)

    response = reset(token)

    assert response.status_code == 200
    assert login(OLD_PASSWORD).status_code == 401
    assert login(NEW_PASSWORD).status_code == 200
    with SessionLocal() as session:
        stored = session.scalar(
            select(PasswordResetToken).where(
                PasswordResetToken.token_hash == hash_password_reset_token(token)
            )
        )
        assert stored is not None
        assert stored.used_at is not None


def test_invalid_expired_and_reused_tokens_share_safe_error(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    assert register().status_code == 201
    token = forgot_with_development_token(monkeypatch)
    invalid = reset("invalid-token")

    with SessionLocal() as session:
        stored = session.scalar(
            select(PasswordResetToken).where(
                PasswordResetToken.token_hash == hash_password_reset_token(token)
            )
        )
        assert stored is not None
        stored.expires_at = datetime.now(timezone.utc) - timedelta(seconds=1)
        session.commit()
    expired = reset(token)

    fresh_token = forgot_with_development_token(monkeypatch)
    assert reset(fresh_token).status_code == 200
    reused = reset(fresh_token, "another-password")

    expected = {"detail": RESET_PASSWORD_ERROR}
    assert invalid.status_code == expired.status_code == reused.status_code == 400
    assert invalid.json() == expired.json() == reused.json() == expected


def test_new_password_shorter_than_eight_characters_is_rejected(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    assert register().status_code == 201
    token = forgot_with_development_token(monkeypatch)

    response = reset(token, "short")

    assert response.status_code == 422
    assert login(OLD_PASSWORD).status_code == 200


def test_failed_commit_rolls_back_password_and_token_consumption(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    assert register().status_code == 201
    token = forgot_with_development_token(monkeypatch)
    original_commit = Session.commit

    def fail_commit(_session: Session) -> None:
        raise SQLAlchemyError("forced reset failure")

    monkeypatch.setattr(Session, "commit", fail_commit)
    response = reset(token)
    monkeypatch.setattr(Session, "commit", original_commit)

    assert response.status_code == 500
    assert login(OLD_PASSWORD).status_code == 200
    assert login(NEW_PASSWORD).status_code == 401
    with SessionLocal() as session:
        stored = session.scalar(
            select(PasswordResetToken).where(
                PasswordResetToken.token_hash == hash_password_reset_token(token)
            )
        )
        assert stored is not None
        assert stored.used_at is None
