import asyncio
from collections.abc import Generator
from datetime import date, timedelta

import pytest
from httpx import ASGITransport, AsyncClient, Response
from sqlalchemy import delete

from app.db.database import SessionLocal
from app.db.models.activity import Activity
from app.db.models.goal import Goal
from app.db.models.user import User
from app.main import app
from app.services.auth import create_access_token, hash_password
from app.services.daily_score_v2 import calculate_daily_score_v2


EMAILS = ("insights-a@example.com", "insights-b@example.com")
TARGETS = {"steps": 10_000.0, "active_minutes": 60.0, "calories": 450.0}


async def _get(path: str, token: str) -> Response:
    async with AsyncClient(
        transport=ASGITransport(app=app), base_url="http://test"
    ) as client:
        return await client.get(path, headers={"Authorization": f"Bearer {token}"})


@pytest.fixture(autouse=True)
def clean_users() -> Generator[None, None, None]:
    def clean() -> None:
        with SessionLocal() as session:
            session.execute(delete(User).where(User.email.in_(EMAILS)))
            session.commit()

    clean()
    yield
    clean()


def _user(email: str, with_goals: bool = False) -> tuple[User, str]:
    with SessionLocal() as session:
        user = User(email=email, password_hash=hash_password("password123"))
        session.add(user)
        session.flush()
        if with_goals:
            session.add_all(
                Goal(user_id=user.id, type=metric, target_value=target)
                for metric, target in TARGETS.items()
            )
        session.commit()
        session.refresh(user)
        session.expunge(user)
    return user, create_access_token(user.id)


def _activity(
    user: User,
    day: date,
    *,
    steps: float,
    score: float,
    active_minutes: float = 0,
    distance: float = 0,
    calories: float = 0,
    recording_status: str = "recorded",
) -> None:
    with SessionLocal() as session:
        session.add(
            Activity(
                user_id=user.id,
                date=day,
                steps=steps,
                active_minutes=active_minutes,
                distance=distance,
                calories=calories,
                daily_score=score,
                score_version="v2",
                source="manual",
                recording_status=recording_status,
            )
        )
        session.commit()


def test_score_explanation_matches_server_formula() -> None:
    user, token = _user(EMAILS[0], with_goals=True)
    score = calculate_daily_score_v2(
        steps=5000,
        active_minutes=30,
        calories=225,
        goal_targets=TARGETS,
    )
    _activity(
        user,
        date.today(),
        steps=5000,
        active_minutes=30,
        calories=225,
        score=score,
    )

    response = asyncio.run(_get("/activity/today/score-explanation", token))
    payload = response.json()

    assert response.status_code == 200
    assert payload["available"] is True
    assert payload["score"] == 50
    assert [item["metric"] for item in payload["components"]] == [
        "steps",
        "active_minutes",
        "calories",
    ]
    assert sum(item["points"] for item in payload["components"]) == 50
    assert [item["weight"] for item in payload["components"]] == [0.5, 0.3, 0.2]


def test_stale_score_returns_honest_unavailable_explanation() -> None:
    user, token = _user(EMAILS[0], with_goals=True)
    _activity(user, date.today(), steps=5000, score=99)

    payload = asyncio.run(
        _get("/activity/today/score-explanation", token)
    ).json()

    assert payload["available"] is False
    assert payload["components"] == []
    assert "earlier goal settings" in payload["message"]


def test_insights_compare_recorded_days_and_find_strongest_day() -> None:
    user, token = _user(EMAILS[0])
    today = date.today()
    _activity(user, today - timedelta(days=9), steps=1000, score=30)
    _activity(user, today - timedelta(days=8), steps=1000, score=40)
    _activity(user, today - timedelta(days=2), steps=1000, score=50)
    _activity(user, today, steps=3000, score=70)

    payload = asyncio.run(_get("/activity/insights?days=7", token)).json()

    assert payload["current_recorded_days"] == 2
    assert payload["previous_recorded_days"] == 2
    assert payload["steps_change_percent"] == 100
    assert payload["average_score_change"] == 25
    assert payload["strongest_score_day"] == {
        "date": today.isoformat(),
        "daily_score": 70,
        "steps": 3000,
    }
    assert payload["strongest_steps_day"] == payload["strongest_score_day"]
    assert payload["average_steps"] == 2000
    assert payload["total_steps"] == 4000


def test_missing_days_are_not_averaged_as_zero() -> None:
    user, token = _user(EMAILS[0])
    today = date.today()
    _activity(user, today - timedelta(days=8), steps=1000, score=20)
    _activity(user, today, steps=1000, score=20)

    payload = asyncio.run(_get("/activity/insights?days=7", token)).json()

    assert payload["steps_change_percent"] == 0
    assert payload["average_score_change"] == 0
    assert payload["current_recorded_days"] == 1
    assert payload["previous_recorded_days"] == 1


def test_insights_report_insufficient_comparison_data() -> None:
    user, token = _user(EMAILS[0])
    _activity(user, date.today(), steps=1000, score=20)

    payload = asyncio.run(_get("/activity/insights?days=7", token)).json()

    assert payload["steps_change_percent"] is None
    assert payload["average_score_change"] is None
    assert payload["previous_recorded_days"] == 0


def test_insights_are_isolated_by_authenticated_user() -> None:
    user_a, token_a = _user(EMAILS[0])
    user_b, _ = _user(EMAILS[1])
    today = date.today()
    _activity(user_a, today, steps=100, score=10)
    _activity(user_b, today, steps=99999, score=100)

    payload = asyncio.run(_get("/activity/insights?days=7", token_a)).json()

    assert payload["current_recorded_days"] == 1
    assert payload["strongest_steps_day"]["steps"] == 100


def test_legacy_rows_remain_out_of_confirmed_comparisons() -> None:
    user, token = _user(EMAILS[0])
    today = date.today()
    _activity(
        user,
        today,
        steps=99999,
        score=100,
        recording_status="legacy_unknown",
    )

    payload = asyncio.run(_get("/activity/insights?days=7", token)).json()

    assert payload["current_recorded_days"] == 0
    assert payload["current_legacy_days"] == 1
    assert payload["average_steps"] is None
    assert payload["strongest_steps_day"] is None


def test_zero_previous_denominator_does_not_invent_percentage() -> None:
    user, token = _user(EMAILS[0])
    today = date.today()
    _activity(user, today - timedelta(days=8), steps=0, score=0)
    _activity(user, today, steps=1000, score=50)

    payload = asyncio.run(_get("/activity/insights?days=7", token)).json()

    assert payload["steps_change_percent"] is None
    assert payload["distance_change_percent"] is None
    assert payload["active_calories_change_percent"] is None
    assert payload["average_score_change"] == 50


def test_30_day_comparison_uses_only_bounded_confirmed_periods() -> None:
    user, token = _user(EMAILS[0])
    today = date.today()
    _activity(
        user,
        today - timedelta(days=31),
        steps=1000,
        distance=2,
        calories=100,
        score=40,
    )
    _activity(
        user,
        today,
        steps=2000,
        distance=3,
        calories=150,
        score=50,
    )

    payload = asyncio.run(_get("/activity/insights?days=30", token)).json()

    assert payload["steps_change_percent"] == 100
    assert payload["distance_change_percent"] == 50
    assert payload["active_calories_change_percent"] == 50
    assert payload["average_score_change"] == 10


def test_trend_improving_with_score_increase() -> None:
    user, token = _user(EMAILS[0])
    today = date.today()
    # Previous period: avg score 30
    _activity(user, today - timedelta(days=8), steps=1000, score=30)
    # Current period: avg score 70 â†’ change = +40 > 5
    _activity(user, today, steps=2000, score=70)

    payload = asyncio.run(_get("/activity/insights?days=7", token)).json()

    assert payload["trend"] == "improving"
    assert payload["consistency_days"] == 1


def test_trend_declining_with_score_decrease() -> None:
    user, token = _user(EMAILS[0])
    today = date.today()
    # Previous period: avg score 80
    _activity(user, today - timedelta(days=8), steps=5000, score=80)
    # Current period: avg score 20 â†’ change = -60 < -5
    _activity(user, today, steps=500, score=20)

    payload = asyncio.run(_get("/activity/insights?days=7", token)).json()

    assert payload["trend"] == "declining"


def test_trend_stable_within_threshold() -> None:
    user, token = _user(EMAILS[0])
    today = date.today()
    # Previous period: avg score 50
    _activity(user, today - timedelta(days=8), steps=1000, score=50)
    # Current period: avg score 53 â†’ change = +3, within Â±5
    _activity(user, today, steps=1000, score=53)

    payload = asyncio.run(_get("/activity/insights?days=7", token)).json()

    assert payload["trend"] == "stable"


def test_trend_insufficient_data_no_previous_period() -> None:
    user, token = _user(EMAILS[0])
    _activity(user, date.today(), steps=1000, score=50)

    payload = asyncio.run(_get("/activity/insights?days=7", token)).json()

    assert payload["trend"] == "insufficient_data"
    assert payload["consistency_days"] == 1


def test_consistency_days_counts_confirmed_only_excludes_legacy() -> None:
    user, token = _user(EMAILS[0])
    today = date.today()
    # Confirmed recorded zero: should count
    _activity(user, today - timedelta(days=1), steps=0, score=0)
    # Confirmed recorded: should count
    _activity(user, today, steps=1000, score=50)
    # Legacy: should NOT count toward consistency
    _activity(
        user,
        today - timedelta(days=2),
        steps=5000,
        score=80,
        recording_status="legacy_unknown",
    )

    payload = asyncio.run(_get("/activity/insights?days=7", token)).json()

    assert payload["consistency_days"] == 2
    assert payload["current_recorded_days"] == 2


def test_trend_and_consistency_isolated_by_user() -> None:
    user_a, token_a = _user(EMAILS[0])
    user_b, _ = _user(EMAILS[1])
    today = date.today()
    # User A: one current day only
    _activity(user_a, today, steps=100, score=10)
    # User B: lots of recorded days (should not leak)
    for offset in range(14):
        _activity(user_b, today - timedelta(days=offset), steps=9999, score=99)

    payload = asyncio.run(_get("/activity/insights?days=7", token_a)).json()

    assert payload["trend"] == "insufficient_data"
    assert payload["consistency_days"] == 1
