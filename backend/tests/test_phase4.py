import asyncio
from datetime import date

import pytest
from httpx import ASGITransport, AsyncClient, Response
from sqlalchemy import select

from app.core.constants import MOCK_USER_ID
from app.db.database import SessionLocal
from app.db.models.activity import Activity
from app.db.seed import seed_data
from app.main import app
from app.services.daily_score import calculate_daily_score
from app.services.goals import derive_goal_status


def request(path: str, token: str | None = None) -> Response:
    return asyncio.run(_request(path, token))


async def _request(path: str, token: str | None) -> Response:
    transport = ASGITransport(app=app)
    headers = {"Authorization": f"Bearer {token}"} if token else {}
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        return await client.get(path, headers=headers)


def test_today_activity_returns_seeded_values_and_score(mock_user_token: str) -> None:
    response = request("/activity/today", token=mock_user_token)

    assert response.status_code == 200
    data = response.json()
    assert data["date"] == date.today().isoformat()
    assert data["steps"] == 7842.0
    assert data["active_minutes"] == 46.0
    assert data["distance"] == 5.6
    assert data["calories"] == 324.0
    assert data["daily_score"] == 77.0
    assert data["score_version"] == "v1"
    assert data["source"] == "manual"
    assert data["recording_status"] == "recorded"
    assert data["steps_provenance"] in ("system", "health_connect", "manual", "blended")
    assert data["distance_provenance"] in ("system", "health_connect", "manual", "blended")
    assert data["calories_provenance"] in ("system", "health_connect", "manual", "blended")
    assert data["active_minutes_provenance"] in ("system", "health_connect", "manual", "blended")


def test_daily_score_v1_matches_locked_calculation() -> None:
    unrounded_score = 100 * (
        0.50 * min(7842 / 10000, 1.0)
        + 0.30 * min(46 / 60, 1.0)
        + 0.20 * min(324 / 450, 1.0)
    )

    assert unrounded_score == pytest.approx(76.61, abs=0.01)
    assert calculate_daily_score(steps=7842, active_minutes=46, calories=324) == 77

    with SessionLocal() as session:
        activity = session.scalar(
            select(Activity).where(
                Activity.user_id == MOCK_USER_ID,
                Activity.date == date.today(),
            )
        )
        assert activity is not None
        assert activity.daily_score == 77


def test_goals_derive_values_from_today_activity(mock_user_token: str) -> None:
    response = request("/goals", token=mock_user_token)

    assert response.status_code == 200
    goals = {goal["type"]: goal for goal in response.json()}
    assert set(goals) == {"steps", "active_minutes", "calories"}
    assert goals["steps"]["current_value"] == 7842.0
    assert goals["active_minutes"]["current_value"] == 46.0
    assert goals["calories"]["current_value"] == 324.0
    assert goals["steps"]["progress"] == pytest.approx(0.7842)


def test_goal_progress_caps_and_completion_uses_greater_or_equal() -> None:
    assert derive_goal_status(120, 100) == (1.0, True)
    assert derive_goal_status(100, 100) == (1.0, True)
    assert derive_goal_status(50, 0) == (0.0, False)


def test_profile_returns_seeded_values(mock_user_token: str) -> None:
    response = request("/profile", token=mock_user_token)

    assert response.status_code == 200
    profile = response.json()
    assert profile["display_name"] == "Alex"
    assert profile["subtitle"] == "Building better daily habits"
    assert profile["dark_theme"] is True
    assert profile["reduce_motion"] is False
    assert profile["haptic_feedback"] is True
    assert profile["use_metric_units"] is True


def test_seed_is_idempotent() -> None:
    with SessionLocal() as session:
        first_counts = seed_data(session)
        second_counts = seed_data(session)

    assert first_counts == second_counts
    assert second_counts.profiles == 1
    assert second_counts.activities == 1
    assert second_counts.goals == 3
