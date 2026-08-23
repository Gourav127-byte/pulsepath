import asyncio
from collections.abc import Generator
from datetime import date, timedelta

import pytest
from httpx import ASGITransport, AsyncClient, Response
from sqlalchemy import delete, select

from app.db.database import SessionLocal
from app.db.models.activity import Activity
from app.db.models.goal import Goal
from app.db.models.user import User
from app.main import app
from app.services.auth import create_access_token, hash_password


EMAILS = ("phase13-a@example.com", "phase13-b@example.com")


async def _request(method: str, path: str, token: str, json=None) -> Response:
    async with AsyncClient(
        transport=ASGITransport(app=app), base_url="http://test"
    ) as client:
        return await client.request(
            method,
            path,
            headers={"Authorization": f"Bearer {token}"},
            json=json,
        )


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


def test_lazy_today_is_unrecorded_and_absent_from_history() -> None:
    user, token = _user(EMAILS[0])

    today = asyncio.run(_request("GET", "/activity/today", token)).json()
    history = asyncio.run(_request("GET", "/activity/history?days=7", token)).json()

    assert today["recording_status"] == "unrecorded"
    assert today["steps"] == 0
    assert history == []
    with SessionLocal() as session:
        stored = session.scalar(select(Activity).where(Activity.user_id == user.id))
        assert stored is not None
        assert stored.recording_status == "unrecorded"


def test_confirmed_zero_is_recorded_and_visible_in_history() -> None:
    _, token = _user(EMAILS[0])
    asyncio.run(_request("GET", "/activity/today", token))

    updated = asyncio.run(
        _request("PATCH", "/activity/today", token, {"steps": 0})
    ).json()
    history = asyncio.run(_request("GET", "/activity/history?days=7", token)).json()

    assert updated["recording_status"] == "recorded"
    assert updated["steps"] == 0
    assert len(history) == 1
    assert history[0]["steps"] == 0


def test_first_write_creates_today_without_mutating_yesterday() -> None:
    user, token = _user(EMAILS[0])
    yesterday = date.today() - timedelta(days=1)
    with SessionLocal() as session:
        session.add(
            Activity(
                user_id=user.id,
                date=yesterday,
                steps=12450,
                active_minutes=60,
                distance=8,
                calories=500,
                daily_score=100,
                score_version="v2",
                source="manual",
                recording_status="recorded",
            )
        )
        session.add_all(
            [
                Goal(user_id=user.id, type="steps", target_value=10000),
                Goal(user_id=user.id, type="active_minutes", target_value=60),
                Goal(user_id=user.id, type="calories", target_value=450),
            ]
        )
        session.commit()

    response = asyncio.run(
        _request("PATCH", "/activity/today", token, {"steps": 12500})
    )

    assert response.status_code == 200
    assert response.json()["steps"] == 12500
    assert response.json()["daily_score"] == 50
    assert response.json()["recording_status"] == "recorded"
    with SessionLocal() as session:
        records = session.scalars(
            select(Activity)
            .where(Activity.user_id == user.id)
            .order_by(Activity.date)
        ).all()
        assert [(item.date, item.steps) for item in records] == [
            (yesterday, 12450),
            (date.today(), 12500),
        ]
        assert records[0].daily_score == 100


def test_today_write_remains_isolated_between_users() -> None:
    user_a, token_a = _user(EMAILS[0])
    user_b, token_b = _user(EMAILS[1])

    asyncio.run(_request("PATCH", "/activity/today", token_a, {"steps": 111}))
    asyncio.run(_request("PATCH", "/activity/today", token_b, {"steps": 222}))

    with SessionLocal() as session:
        value_a = session.scalar(
            select(Activity.steps).where(Activity.user_id == user_a.id)
        )
        value_b = session.scalar(
            select(Activity.steps).where(Activity.user_id == user_b.id)
        )
    assert value_a == 111
    assert value_b == 222
