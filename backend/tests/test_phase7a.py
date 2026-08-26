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
from app.db.models.user import User
from app.main import app
from app.services.daily_score_v2 import calculate_daily_score_v2
from app.services.auth import create_access_token


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
        assert activity is not None
        activity_snapshot = {
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
        goals = session.scalars(select(Goal).where(Goal.user_id == MOCK_USER_ID)).all()
        goal_snapshots = {
            goal.id: {
                "user_id": goal.user_id,
                "target_value": goal.target_value,
            }
            for goal in goals
        }

    yield

    with SessionLocal() as session:
        activity = session.get(Activity, activity_snapshot["id"])
        assert activity is not None
        for field, value in activity_snapshot.items():
            if field != "id":
                setattr(activity, field, value)
        for goal_id, snapshot in goal_snapshots.items():
            goal = session.get(Goal, goal_id)
            assert goal is not None
            goal.user_id = snapshot["user_id"]
            goal.target_value = snapshot["target_value"]
        session.commit()


def get_goal(goal_type: str) -> Goal:
    with SessionLocal() as session:
        goal = session.scalar(
            select(Goal).where(
                Goal.user_id == MOCK_USER_ID,
                Goal.type == goal_type,
            )
        )
        assert goal is not None
        session.expunge(goal)
        return goal


def test_patch_single_metric_preserves_others_and_persists_v2(
    mock_user_token: str,
) -> None:
    response = request("PATCH", "/activity/today", {"steps": 9000}, token=mock_user_token)

    assert response.status_code == 200
    updated = response.json()
    assert updated["steps"] == 9000
    assert updated["active_minutes"] == 46
    assert updated["calories"] == 324
    assert updated["distance"] == 5.6
    assert updated["daily_score"] == 82
    assert updated["score_version"] == "v2"

    with SessionLocal() as session:
        persisted = session.scalar(
            select(Activity).where(
                Activity.user_id == MOCK_USER_ID,
                Activity.date == date.today(),
            )
        )
        assert persisted is not None
        assert persisted.steps == 9000
        assert persisted.active_minutes == 46
        assert persisted.calories == 324
        assert persisted.distance == 5.6
        assert persisted.daily_score == 82
        assert persisted.score_version == "v2"

    get_response = request("GET", "/activity/today", {}, token=mock_user_token)
    assert get_response.json() == updated


def test_empty_patch_recomputes_and_transitions_to_v2(
    mock_user_token: str,
) -> None:
    response = request("PATCH", "/activity/today", {}, token=mock_user_token)

    assert response.status_code == 200
    assert response.json()["score_version"] == "v2"
    assert response.json()["daily_score"] == 77


def test_recompute_reads_updated_live_goal_target(mock_user_token: str) -> None:
    steps_goal = get_goal("steps")
    goal_response = request(
        "PATCH",
        f"/goals/{steps_goal.id}",
        {"target_value": 8000},
        token=mock_user_token,
    )
    assert goal_response.status_code == 200

    response = request("PATCH", "/activity/today", {}, token=mock_user_token)

    assert response.status_code == 200
    assert response.json()["steps"] == 7842
    assert response.json()["daily_score"] == 86
    assert response.json()["score_version"] == "v2"


def test_missing_goal_contributes_zero_without_redistribution(
    mock_user_token: str,
) -> None:
    calories_goal = get_goal("calories")
    temporary_user_id = uuid.uuid4()
    with SessionLocal() as session:
        session.add(
            User(
                id=temporary_user_id,
                email=f"missing-goal-{temporary_user_id}@example.test",
                password_hash="test-only-not-a-real-password-hash",
            )
        )
        session.flush()
        goal = session.get(Goal, calories_goal.id)
        assert goal is not None
        goal.user_id = temporary_user_id
        session.commit()

    try:
        response = request("PATCH", "/activity/today", {}, token=mock_user_token)
        assert response.status_code == 200
        assert response.json()["daily_score"] is not None
    finally:
        with SessionLocal() as session:
            goal = session.get(Goal, calories_goal.id)
            assert goal is not None
            goal.user_id = MOCK_USER_ID
            temporary_user = session.get(User, temporary_user_id)
            assert temporary_user is not None
            session.delete(temporary_user)
            session.commit()


@pytest.mark.parametrize("target", [0.0, 1e-300])
def test_zero_or_near_zero_goal_target_does_not_divide_by_zero(
    target: float, mock_user_token: str
) -> None:
    steps_goal = get_goal("steps")
    with SessionLocal() as session:
        goal = session.get(Goal, steps_goal.id)
        assert goal is not None
        goal.target_value = target
        session.commit()

    response = request("PATCH", "/activity/today", {}, token=mock_user_token)

    assert response.status_code == 200
    assert 0 <= response.json()["daily_score"] <= 100


@pytest.mark.parametrize(
    "payload",
    [
        {"steps": -1},
        {"active_minutes": -1},
        {"calories": -1},
        {"distance": -1},
        {"steps": "9000"},
        {"steps": None},
    ],
)
def test_invalid_activity_metrics_are_rejected(
    payload: dict[str, object], mock_user_token: str
) -> None:
    response = request("PATCH", "/activity/today", payload, token=mock_user_token)

    assert response.status_code == 422


@pytest.mark.parametrize(
    "field",
    ["daily_score", "score_version", "user_id", "date", "source", "id"],
)
def test_forbidden_activity_fields_are_rejected(
    field: str, mock_user_token: str
) -> None:
    response = request("PATCH", "/activity/today", {field: 1}, token=mock_user_token)

    assert response.status_code == 422


def test_missing_today_activity_is_created_by_first_partial_write() -> None:
    temporary_user_id = uuid.uuid4()
    with SessionLocal() as session:
        session.add(
            User(
                id=temporary_user_id,
                email=f"missing-activity-{temporary_user_id}@example.test",
                password_hash="test-only-not-a-real-password-hash",
            )
        )
        session.commit()

    try:
        token = create_access_token(temporary_user_id)
        response = request(
            "PATCH", "/activity/today", {"steps": 9000}, token=token
        )
        assert response.status_code == 200
        assert response.json()["steps"] == 9000
        assert response.json()["active_minutes"] is None
        assert response.json()["recording_status"] == "recorded"
    finally:
        with SessionLocal() as session:
            temporary_user = session.get(User, temporary_user_id)
            assert temporary_user is not None
            session.delete(temporary_user)
            session.commit()


def test_score_failure_rolls_back_in_memory_metric_changes(
    monkeypatch, mock_user_token: str
) -> None:
    def fail_score_computation(**_kwargs) -> float:
        raise RuntimeError("forced score failure")

    monkeypatch.setattr(
        "app.api.activity.calculate_daily_score_v2",
        fail_score_computation,
    )

    response = request("PATCH", "/activity/today", {"steps": 9000}, token=mock_user_token)

    assert response.status_code == 500
    assert response.json() == {"detail": "Could not update today's activity"}
    with SessionLocal() as session:
        activity = session.scalar(
            select(Activity).where(
                Activity.user_id == MOCK_USER_ID,
                Activity.date == date.today(),
            )
        )
        assert activity is not None
        assert activity.steps == 7842
        assert activity.daily_score == 77
        assert activity.score_version == "v1"


def test_v2_formula_guards_missing_and_non_positive_targets() -> None:
    score = calculate_daily_score_v2(
        steps=9000,
        active_minutes=46,
        calories=324,
        goal_targets={"steps": 0, "active_minutes": 60},
    )

    assert score == 37
