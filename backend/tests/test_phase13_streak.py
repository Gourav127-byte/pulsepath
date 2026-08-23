import asyncio
from collections.abc import Generator
from datetime import date, timedelta

import pytest
from httpx import ASGITransport, AsyncClient, Response
from sqlalchemy import UniqueConstraint, delete

from app.db.database import SessionLocal
from app.db.models.activity import Activity
from app.db.models.user import User
from app.main import app
from app.services.auth import create_access_token, hash_password


EMAILS = ("streak-a@example.com", "streak-b@example.com")


async def _get(
    token: str | None = None, path: str = "/activity/streak"
) -> Response:
    headers = {"Authorization": f"Bearer {token}"} if token else {}
    async with AsyncClient(
        transport=ASGITransport(app=app), base_url="http://test"
    ) as client:
        return await client.get(path, headers=headers)


@pytest.fixture(autouse=True)
def clean_users() -> Generator[None, None, None]:
    def clean() -> None:
        with SessionLocal() as session:
            session.execute(delete(User).where(User.email.in_(EMAILS)))
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


def _activity(user: User, offset: int, status: str) -> None:
    with SessionLocal() as session:
        session.add(
            Activity(
                user_id=user.id,
                date=date.today() - timedelta(days=offset),
                steps=0,
                active_minutes=0,
                distance=0,
                calories=0,
                daily_score=0,
                score_version="v2",
                source="system",
                recording_status=status,
            )
        )
        session.commit()


def test_streak_requires_authentication() -> None:
    assert asyncio.run(_get()).status_code == 401


def test_activity_user_date_uniqueness_constraint_is_preserved() -> None:
    constraints = [
        constraint
        for constraint in Activity.__table__.constraints
        if isinstance(constraint, UniqueConstraint)
    ]
    assert any(
        constraint.name == "uq_activities_user_date"
        and {column.name for column in constraint.columns} == {"user_id", "date"}
        for constraint in constraints
    )


@pytest.mark.parametrize(
    ("rows", "expected_streak", "today_pending"),
    [
        ([(2, "recorded"), (1, "recorded"), (0, "unrecorded")], 2, True),
        ([(2, "recorded"), (1, "recorded"), (0, "recorded")], 3, False),
        ([(2, "recorded"), (0, "unrecorded")], 0, True),
        ([(2, "recorded"), (0, "recorded")], 1, False),
        ([(1, "recorded")], 1, True),
        ([(1, "legacy_unknown"), (0, "unrecorded")], 0, True),
    ],
)
def test_query_time_streak_grace_rule(
    rows: list[tuple[int, str]], expected_streak: int, today_pending: bool
) -> None:
    user, token = _user(EMAILS[0])
    for offset, recording_status in rows:
        _activity(user, offset, recording_status)

    response = asyncio.run(_get(token))

    assert response.status_code == 200
    assert response.json() == {
        "current_streak": expected_streak,
        "today_pending": today_pending,
    }


def test_streak_is_isolated_by_authenticated_user() -> None:
    user_a, token_a = _user(EMAILS[0])
    user_b, token_b = _user(EMAILS[1])
    _activity(user_a, 0, "recorded")
    _activity(user_b, 0, "recorded")
    _activity(user_b, 1, "recorded")

    assert asyncio.run(_get(token_a)).json()["current_streak"] == 1
    assert asyncio.run(_get(token_b)).json()["current_streak"] == 2


def test_engagement_returns_locked_achievements_without_recorded_days() -> None:
    _, token = _user(EMAILS[0])

    payload = asyncio.run(_get(token, "/activity/engagement")).json()

    assert payload["current_streak"] == 0
    assert payload["best_streak"] == 0
    assert payload["today_pending"] is True
    assert len(payload["achievements"]) == 6
    assert all(item["unlocked"] is False for item in payload["achievements"])


def test_best_streak_keeps_historical_achievements_unlocked() -> None:
    user, token = _user(EMAILS[0])
    for offset in range(4, 11):
        _activity(user, offset, "recorded")
    _activity(user, 0, "recorded")

    payload = asyncio.run(_get(token, "/activity/engagement")).json()
    achievements = {item["id"]: item for item in payload["achievements"]}

    assert payload["current_streak"] == 1
    assert payload["best_streak"] == 7
    assert achievements["first_confirmed_activity"]["unlocked"] is True
    assert achievements["streak_3"]["unlocked"] is True
    assert achievements["streak_7"]["unlocked"] is True
    assert achievements["streak_14"]["unlocked"] is False
    assert achievements["streak_7"]["unlock_date"] is not None


def test_engagement_excludes_legacy_and_is_user_isolated() -> None:
    user_a, token_a = _user(EMAILS[0])
    user_b, token_b = _user(EMAILS[1])
    _activity(user_a, 0, "legacy_unknown")
    for offset in range(3):
        _activity(user_b, offset, "recorded")

    payload_a = asyncio.run(_get(token_a, "/activity/engagement")).json()
    payload_b = asyncio.run(_get(token_b, "/activity/engagement")).json()

    assert payload_a["best_streak"] == 0
    assert not any(item["unlocked"] for item in payload_a["achievements"])
    assert payload_b["best_streak"] == 3
    assert next(
        item for item in payload_b["achievements"] if item["id"] == "streak_3"
    )["unlocked"] is True
