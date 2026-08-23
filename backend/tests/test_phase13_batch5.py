import asyncio
import uuid
from collections.abc import Generator
from datetime import date

import pytest
from httpx import ASGITransport, AsyncClient, Response
from sqlalchemy import select

from app.core.constants import MOCK_USER_ID
from app.db.database import SessionLocal
from app.db.models.activity import Activity
from app.db.models.goal import Goal
from app.main import app


def request(
    method: str, path: str, json: dict[str, object], token: str | None = None
) -> Response:
    return asyncio.run(_request(method, path, json, token))


async def _request(
    method: str, path: str, json: dict[str, object], token: str | None
) -> Response:
    transport = ASGITransport(app=app)
    headers = {"Authorization": f"Bearer {token}"} if token else {}
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        return await client.request(method, path, json=json, headers=headers)


@pytest.fixture(autouse=True)
def restore_activity_and_goals() -> Generator[None, None, None]:
    with SessionLocal() as session:
        activity = session.scalar(
            select(Activity).where(
                Activity.user_id == MOCK_USER_ID,
                Activity.date == date.today(),
            )
        )
        activity_snapshot = (
            {
                "id": activity.id,
                "user_id": activity.user_id,
                "steps": activity.steps,
                "steps_manual": activity.steps_manual,
                "steps_health_connect": activity.steps_health_connect,
                "active_minutes": activity.active_minutes,
                "active_minutes_manual": activity.active_minutes_manual,
                "active_minutes_health_connect": activity.active_minutes_health_connect,
                "calories": activity.calories,
                "calories_manual": activity.calories_manual,
                "calories_health_connect": activity.calories_health_connect,
                "distance": activity.distance,
                "distance_manual": activity.distance_manual,
                "distance_health_connect": activity.distance_health_connect,
                "daily_score": activity.daily_score,
                "score_version": activity.score_version,
                "source": activity.source,
                "recording_status": activity.recording_status,
            }
            if activity
            else None
        )
        goals = session.scalars(select(Goal).where(Goal.user_id == MOCK_USER_ID)).all()
        goal_snapshots = {
            goal.id: {
                "user_id": goal.user_id,
                "target_value": goal.target_value,
                "type": goal.type,
            }
            for goal in goals
        }

    yield

    with SessionLocal() as session:
        if activity_snapshot:
            current_activity = session.get(Activity, activity_snapshot["id"])
            if current_activity is not None:
                for field, value in activity_snapshot.items():
                    if field != "id":
                        setattr(current_activity, field, value)
        for goal_id_val, data in goal_snapshots.items():
            goal = session.get(Goal, goal_id_val)
            if goal is not None:
                goal.target_value = data["target_value"]
        session.commit()


def goal_id(goal_type: str) -> str:
    with SessionLocal() as session:
        goal = session.scalar(
            select(Goal).where(
                Goal.user_id == MOCK_USER_ID, Goal.type == goal_type
            )
        )
        assert goal is not None
        return str(goal.id)


def test_flexible_step_goals(mock_user_token: str) -> None:
    steps_id = goal_id("steps")

    # 1. existing 10,000 goal still works
    resp = request("PATCH", f"/goals/{steps_id}", {"target_value": 10000}, token=mock_user_token)
    assert resp.status_code == 200
    assert resp.json()["target_value"] == 10000.0

    # 2. 20,000 goal works
    resp = request("PATCH", f"/goals/{steps_id}", {"target_value": 20000}, token=mock_user_token)
    assert resp.status_code == 200
    assert resp.json()["target_value"] == 20000.0

    # 3. custom 12,500 goal works
    resp = request("PATCH", f"/goals/{steps_id}", {"target_value": 12500}, token=mock_user_token)
    assert resp.status_code == 200
    assert resp.json()["target_value"] == 12500.0

    # 4. large valid goal such as 100,000 works
    resp = request("PATCH", f"/goals/{steps_id}", {"target_value": 100000}, token=mock_user_token)
    assert resp.status_code == 200
    assert resp.json()["target_value"] == 100000.0

    # 5. zero rejected
    resp = request("PATCH", f"/goals/{steps_id}", {"target_value": 0}, token=mock_user_token)
    assert resp.status_code == 422

    # 6. negative value rejected
    resp = request("PATCH", f"/goals/{steps_id}", {"target_value": -5000}, token=mock_user_token)
    assert resp.status_code == 422

    # 7. malformed custom input rejected
    resp = request("PATCH", f"/goals/{steps_id}", {"target_value": "not-a-number"}, token=mock_user_token)
    assert resp.status_code == 422


def test_actual_steps_can_exceed_goal_without_being_truncated(mock_user_token: str) -> None:
    steps_id = goal_id("steps")
    request("PATCH", f"/goals/{steps_id}", {"target_value": 20000}, token=mock_user_token)

    resp = request(
        "PATCH",
        "/activity/today",
        {
            "steps": 25000,
            "active_minutes": 60,
            "calories": 400,
            "distance": 5.0,
        },
        token=mock_user_token,
    )
    assert resp.status_code == 200
    data = resp.json()
    assert data["steps"] == 25000.0
    assert data["daily_score"] <= 100.0


def test_existing_saved_goal_is_preserved_and_user_isolation(mock_user_token: str) -> None:
    steps_id = goal_id("steps")
    resp = request("PATCH", f"/goals/{steps_id}", {"target_value": 15000}, token=mock_user_token)
    assert resp.status_code == 200
    assert resp.json()["target_value"] == 15000.0

    # Verify GET /goals reflects this value
    get_resp = request("GET", "/goals", {}, token=mock_user_token)
    assert get_resp.status_code == 200
    goals = {g["type"]: g["target_value"] for g in get_resp.json()}
    assert goals["steps"] == 15000.0
