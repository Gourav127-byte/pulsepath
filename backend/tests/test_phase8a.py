import asyncio
import uuid
from collections.abc import Generator
from datetime import date

import pytest
from httpx import ASGITransport, AsyncClient, Response
from pydantic import ValidationError
from sqlalchemy import delete, select

from app.core.constants import MOCK_USER_ID
from app.db.database import SessionLocal
from app.db.models.activity import Activity
from app.db.models.goal import Goal
from app.db.models.user import User
from app.main import app
from app.schemas.goal import GoalCreate


def request(
    method: str,
    path: str,
    json: dict[str, object] | None = None,
    token: str | None = None,
) -> Response:
    return asyncio.run(_request(method, path, json, token))


async def _request(
    method: str,
    path: str,
    json: dict[str, object] | None,
    token: str | None,
) -> Response:
    transport = ASGITransport(app=app)
    headers = {"Authorization": f"Bearer {token}"} if token else {}
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        return await client.request(method, path, json=json, headers=headers)


@pytest.fixture(autouse=True)
def restore_goals() -> Generator[None, None, None]:
    with SessionLocal() as session:
        goals = session.scalars(
            select(Goal).where(Goal.user_id == MOCK_USER_ID)
        ).all()
        snapshots = [
            {
                "id": goal.id,
                "user_id": goal.user_id,
                "type": goal.type,
                "target_value": goal.target_value,
                "created_at": goal.created_at,
                "updated_at": goal.updated_at,
            }
            for goal in goals
        ]

    yield

    with SessionLocal() as session:
        session.execute(delete(Goal).where(Goal.user_id == MOCK_USER_ID))
        session.add_all(Goal(**snapshot) for snapshot in snapshots)
        session.commit()


def create_distance_goal(token: str | None = None) -> Response:
    return request(
        "POST",
        "/goals",
        {"type": "distance", "target_value": 8},
        token=token,
    )


def test_post_creates_and_persists_missing_goal_with_derived_values(
    mock_user_token: str,
) -> None:
    response = create_distance_goal(token=mock_user_token)

    assert response.status_code == 201
    created = response.json()
    assert created["type"] == "distance"
    assert created["target_value"] == 8
    assert created["current_value"] == 5.6
    assert created["progress"] == pytest.approx(0.7)
    assert created["is_completed"] is False

    with SessionLocal() as session:
        persisted = session.scalar(
            select(Goal).where(
                Goal.user_id == MOCK_USER_ID,
                Goal.type == "distance",
            )
        )
        assert persisted is not None
        assert persisted.id == uuid.UUID(created["id"])
        assert persisted.target_value == 8

    listed = request("GET", "/goals", token=mock_user_token).json()
    assert any(goal["id"] == created["id"] for goal in listed)


def test_post_derives_zero_values_when_today_activity_is_missing(
    mock_user_token: str,
) -> None:
    temporary_user_id = uuid.uuid4()
    with SessionLocal() as session:
        session.add(
            User(
                id=temporary_user_id,
                email=f"missing-activity-{temporary_user_id}@example.test",
                password_hash="test-only-not-a-real-password-hash",
            )
        )
        session.flush()
        activity = session.scalar(
            select(Activity).where(
                Activity.user_id == MOCK_USER_ID,
                Activity.date == date.today(),
            )
        )
        assert activity is not None
        activity_id = activity.id
        activity.user_id = temporary_user_id
        session.commit()

    try:
        response = create_distance_goal(token=mock_user_token)
        assert response.status_code == 201
        assert response.json()["current_value"] == 0
        assert response.json()["progress"] == 0
        assert response.json()["is_completed"] is False
    finally:
        with SessionLocal() as session:
            activity = session.get(Activity, activity_id)
            assert activity is not None
            activity.user_id = MOCK_USER_ID
            temporary_user = session.get(User, temporary_user_id)
            assert temporary_user is not None
            session.delete(temporary_user)
            session.commit()


def test_duplicate_goal_type_returns_conflict(mock_user_token: str) -> None:
    response = request(
        "POST",
        "/goals",
        {"type": "steps", "target_value": 12000},
        token=mock_user_token,
    )

    assert response.status_code == 409
    assert "already exists" in response.json()["detail"]


@pytest.mark.parametrize(
    "payload",
    [
        {"type": "sleep", "target_value": 8},
        {"type": "distance", "target_value": 0},
        {"type": "distance", "target_value": -1},
        {"type": "distance", "target_value": 8, "progress": 0.7},
        {"type": "distance", "target_value": 8, "user_id": str(MOCK_USER_ID)},
    ],
)
def test_post_rejects_invalid_or_forbidden_payloads(
    payload: dict[str, object], mock_user_token: str
) -> None:
    response = request("POST", "/goals", payload, token=mock_user_token)

    assert response.status_code == 422


@pytest.mark.parametrize("target_value", [float("nan"), float("inf")])
def test_create_schema_rejects_non_finite_targets(target_value: float) -> None:
    with pytest.raises(ValidationError):
        GoalCreate(type="distance", target_value=target_value)


def test_goal_type_remains_immutable_through_patch(mock_user_token: str) -> None:
    created = create_distance_goal(token=mock_user_token).json()

    response = request(
        "PATCH",
        f"/goals/{created['id']}",
        {"target_value": 10, "type": "steps"},
        token=mock_user_token,
    )

    assert response.status_code == 422
    listed = request("GET", "/goals", token=mock_user_token).json()
    distance = next(goal for goal in listed if goal["id"] == created["id"])
    assert distance["type"] == "distance"
    assert distance["target_value"] == 8


def test_delete_removes_goal_and_get_no_longer_lists_it(
    mock_user_token: str,
) -> None:
    created = create_distance_goal(token=mock_user_token).json()

    response = request("DELETE", f"/goals/{created['id']}", token=mock_user_token)

    assert response.status_code == 204
    assert response.content == b""
    with SessionLocal() as session:
        assert session.get(Goal, uuid.UUID(created["id"])) is None
    listed = request("GET", "/goals", token=mock_user_token).json()
    assert all(goal["id"] != created["id"] for goal in listed)


def test_delete_unknown_well_formed_uuid_returns_not_found(
    mock_user_token: str,
) -> None:
    response = request("DELETE", f"/goals/{uuid.uuid4()}", token=mock_user_token)

    assert response.status_code == 404


def test_repeated_delete_returns_not_found(mock_user_token: str) -> None:
    created = create_distance_goal(token=mock_user_token).json()

    assert request("DELETE", f"/goals/{created['id']}", token=mock_user_token).status_code == 204
    assert request("DELETE", f"/goals/{created['id']}", token=mock_user_token).status_code == 404


def test_create_and_delete_do_not_recompute_stored_daily_score(
    mock_user_token: str,
) -> None:
    with SessionLocal() as session:
        before = session.scalar(
            select(Activity.daily_score).where(
                Activity.user_id == MOCK_USER_ID,
                Activity.date == date.today(),
            )
        )

    created = create_distance_goal(token=mock_user_token).json()
    assert (
        request("DELETE", f"/goals/{created['id']}", token=mock_user_token).status_code
        == 204
    )

    with SessionLocal() as session:
        after = session.scalar(
            select(Activity.daily_score).where(
                Activity.user_id == MOCK_USER_ID,
                Activity.date == date.today(),
            )
        )
    assert after == before
