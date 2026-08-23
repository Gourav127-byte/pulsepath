import asyncio
from collections.abc import Generator
from datetime import date, timedelta

import pytest
from httpx import ASGITransport, AsyncClient, Response
from sqlalchemy import delete, func, select

from app.db.database import SessionLocal
from app.db.models.activity import Activity
from app.db.models.user import User
from app.main import app
from app.services.auth import create_access_token, hash_password


TEST_EMAILS = ("history-a@example.com", "history-b@example.com")


async def _get(path: str, token: str | None = None) -> Response:
    headers = {"Authorization": f"Bearer {token}"} if token else {}
    async with AsyncClient(
        transport=ASGITransport(app=app), base_url="http://test"
    ) as client:
        return await client.get(path, headers=headers)


@pytest.fixture(autouse=True)
def clean_history_users() -> Generator[None, None, None]:
    def clean() -> None:
        with SessionLocal() as session:
            session.execute(delete(User).where(User.email.in_(TEST_EMAILS)))
            session.commit()

    clean()
    yield
    clean()


def _user(email: str) -> tuple[User, str]:
    with SessionLocal() as session:
        user = User(email=email, password_hash=hash_password("password123"))
        session.add(user)
        session.commit()
        session.refresh(user)
        session.expunge(user)
    return user, create_access_token(user.id)


def _activity(user: User, day: date, steps: float) -> None:
    with SessionLocal() as session:
        session.add(
            Activity(
                user_id=user.id,
                date=day,
                steps=steps,
                distance=steps / 1400,
                active_minutes=steps / 200,
                calories=steps / 25,
                daily_score=min(steps / 100, 100),
                score_version="v2",
                source="manual",
            )
        )
        session.commit()


def test_history_requires_authentication() -> None:
    assert asyncio.run(_get("/activity/history?days=7")).status_code == 401


def test_history_get_does_not_create_missing_activity_rows() -> None:
    user, token = _user(TEST_EMAILS[0])
    with SessionLocal() as session:
        before = session.scalar(
            select(func.count()).select_from(Activity).where(Activity.user_id == user.id)
        )

    response = asyncio.run(_get("/activity/history?days=7", token))

    with SessionLocal() as session:
        after = session.scalar(
            select(func.count()).select_from(Activity).where(Activity.user_id == user.id)
        )
    assert response.status_code == 200
    assert response.json() == []
    assert before == after == 0


def test_history_is_ordered_and_preserves_missing_days_and_real_zero() -> None:
    user, token = _user(TEST_EMAILS[0])
    today = date.today()
    _activity(user, today - timedelta(days=3), 300)
    _activity(user, today - timedelta(days=1), 0)

    response = asyncio.run(_get("/activity/history?days=7", token))

    assert response.status_code == 200
    payload = response.json()
    assert [item["date"] for item in payload] == [
        (today - timedelta(days=3)).isoformat(),
        (today - timedelta(days=1)).isoformat(),
    ]
    assert payload[1]["steps"] == 0
    assert len(payload) == 2  # Missing dates are absent, not fabricated zeros.


@pytest.mark.parametrize("days", [7, 30])
def test_history_range_is_inclusive_and_bounded(days: int) -> None:
    user, token = _user(TEST_EMAILS[0])
    today = date.today()
    _activity(user, today - timedelta(days=days - 1), 100)
    _activity(user, today, 200)
    _activity(user, today - timedelta(days=days), 999)

    response = asyncio.run(_get(f"/activity/history?days={days}", token))

    assert response.status_code == 200
    assert [item["steps"] for item in response.json()] == [100, 200]


def test_history_is_isolated_between_users_on_same_date() -> None:
    user_a, token_a = _user(TEST_EMAILS[0])
    user_b, token_b = _user(TEST_EMAILS[1])
    today = date.today()
    _activity(user_a, today, 111)
    _activity(user_b, today, 222)

    response_a = asyncio.run(_get("/activity/history?days=7", token_a))
    response_b = asyncio.run(_get("/activity/history?days=7", token_b))

    assert [item["steps"] for item in response_a.json()] == [111]
    assert [item["steps"] for item in response_b.json()] == [222]


@pytest.mark.parametrize("days", [0, 1, 8, 31, 365])
def test_history_rejects_unsupported_ranges(days: int) -> None:
    _, token = _user(TEST_EMAILS[0])
    response = asyncio.run(_get(f"/activity/history?days={days}", token))
    assert response.status_code == 422
    assert response.json() == {"detail": "days must be either 7 or 30"}
