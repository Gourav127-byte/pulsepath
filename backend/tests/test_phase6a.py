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
from app.db.models.profile import Profile
from app.db.models.user import User
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
def restore_seeded_writes() -> Generator[None, None, None]:
    with SessionLocal() as session:
        profile = session.scalar(select(Profile).where(Profile.user_id == MOCK_USER_ID))
        assert profile is not None
        profile_snapshot = {
            "id": profile.id,
            "user_id": profile.user_id,
            "display_name": profile.display_name,
            "subtitle": profile.subtitle,
            "dark_theme": profile.dark_theme,
            "reduce_motion": profile.reduce_motion,
            "haptic_feedback": profile.haptic_feedback,
            "use_metric_units": profile.use_metric_units,
        }
        goals = session.scalars(select(Goal).where(Goal.user_id == MOCK_USER_ID)).all()
        goal_snapshots = {goal.id: goal.target_value for goal in goals}

    yield

    with SessionLocal() as session:
        profile = session.get(Profile, profile_snapshot["id"])
        assert profile is not None
        for field, value in profile_snapshot.items():
            if field != "id":
                setattr(profile, field, value)
        for goal_id, target_value in goal_snapshots.items():
            goal = session.get(Goal, goal_id)
            assert goal is not None
            goal.target_value = target_value
        session.commit()


def goal_id(goal_type: str) -> uuid.UUID:
    with SessionLocal() as session:
        goal = session.scalar(
            select(Goal).where(
                Goal.user_id == MOCK_USER_ID,
                Goal.type == goal_type,
            )
        )
        assert goal is not None
        return goal.id


def test_patch_existing_goal_persists_and_get_reflects_update(
    mock_user_token: str,
) -> None:
    steps_goal_id = goal_id("steps")

    response = request(
        "PATCH",
        f"/goals/{steps_goal_id}",
        {"target_value": 8000},
        token=mock_user_token,
    )

    assert response.status_code == 200
    updated = response.json()
    assert updated["type"] == "steps"
    assert updated["target_value"] == 8000
    assert updated["current_value"] == 7842
    assert updated["progress"] == pytest.approx(0.98025)
    assert updated["is_completed"] is False

    with SessionLocal() as session:
        persisted = session.get(Goal, steps_goal_id)
        assert persisted is not None
        assert persisted.target_value == 8000

    get_response = request("GET", "/goals", {}, token=mock_user_token)
    get_steps = next(goal for goal in get_response.json() if goal["type"] == "steps")
    assert get_steps["target_value"] == 8000


def test_patch_goal_recomputes_completion_server_side(mock_user_token: str) -> None:
    response = request(
        "PATCH",
        f"/goals/{goal_id('steps')}",
        {"target_value": 7000},
        token=mock_user_token,
    )

    assert response.status_code == 200
    assert response.json()["current_value"] == 7842
    assert response.json()["progress"] == 1.0
    assert response.json()["is_completed"] is True


@pytest.mark.parametrize("target_value", [0, -1])
def test_patch_goal_rejects_non_positive_target(
    target_value: int, mock_user_token: str
) -> None:
    response = request(
        "PATCH",
        f"/goals/{goal_id('steps')}",
        {"target_value": target_value},
        token=mock_user_token,
    )

    assert response.status_code == 422


def test_patch_goal_rejects_client_derived_fields(mock_user_token: str) -> None:
    response = request(
        "PATCH",
        f"/goals/{goal_id('steps')}",
        {"target_value": 8000, "progress": 1.0},
        token=mock_user_token,
    )

    assert response.status_code == 422


def test_patch_unknown_well_formed_goal_id_returns_404(
    mock_user_token: str,
) -> None:
    response = request(
        "PATCH",
        f"/goals/{uuid.uuid4()}",
        {"target_value": 8000},
        token=mock_user_token,
    )

    assert response.status_code == 404


def test_patch_profile_fields_and_get_reflects_update(
    mock_user_token: str,
) -> None:
    before = request("GET", "/profile", {}, token=mock_user_token).json()

    response = request(
        "PATCH",
        "/profile",
        {
            "display_name": "  Alex M  ",
            "subtitle": "  Moving every day  ",
            "haptic_feedback": False,
        },
        token=mock_user_token,
    )

    assert response.status_code == 200
    updated = response.json()
    assert updated["display_name"] == "Alex M"
    assert updated["subtitle"] == "Moving every day"
    assert updated["haptic_feedback"] is False
    assert updated["dark_theme"] == before["dark_theme"]
    assert updated["reduce_motion"] == before["reduce_motion"]
    assert updated["use_metric_units"] == before["use_metric_units"]

    get_response = request("GET", "/profile", {}, token=mock_user_token)
    assert get_response.status_code == 200
    assert get_response.json() == updated


def test_patch_profile_boolean_preferences(mock_user_token: str) -> None:
    response = request(
        "PATCH",
        "/profile",
        {
            "dark_theme": False,
            "reduce_motion": True,
            "haptic_feedback": False,
            "use_metric_units": False,
        },
        token=mock_user_token,
    )

    assert response.status_code == 200
    assert response.json()["dark_theme"] is False
    assert response.json()["reduce_motion"] is True
    assert response.json()["haptic_feedback"] is False
    assert response.json()["use_metric_units"] is False


@pytest.mark.parametrize(
    ("payload", "field"),
    [
        ({"display_name": "   "}, "display_name"),
        ({"display_name": "A" * 41}, "display_name"),
        ({"subtitle": "S" * 81}, "subtitle"),
        ({"haptic_feedback": "false"}, "haptic_feedback"),
    ],
)
def test_patch_profile_rejects_invalid_values(
    payload: dict[str, object], field: str, mock_user_token: str
) -> None:
    response = request("PATCH", "/profile", payload, token=mock_user_token)

    assert response.status_code == 422
    assert field in response.text


def test_patch_missing_profile_returns_404(mock_user_token: str) -> None:
    temporary_user_id = uuid.uuid4()
    with SessionLocal() as session:
        session.add(
            User(
                id=temporary_user_id,
                email=f"missing-profile-{temporary_user_id}@example.test",
                password_hash="test-only-not-a-real-password-hash",
            )
        )
        session.flush()
        profile = session.scalar(select(Profile).where(Profile.user_id == MOCK_USER_ID))
        assert profile is not None
        profile.user_id = temporary_user_id
        session.commit()

    try:
        response = request(
            "PATCH", "/profile", {"display_name": "Alex Test"}, token=mock_user_token
        )
        assert response.status_code == 404
    finally:
        with SessionLocal() as session:
            profile = session.scalar(
                select(Profile).where(Profile.user_id == temporary_user_id)
            )
            assert profile is not None
            profile.user_id = MOCK_USER_ID
            temporary_user = session.get(User, temporary_user_id)
            assert temporary_user is not None
            session.delete(temporary_user)
            session.commit()


def test_goal_patch_does_not_recompute_daily_score(
    mock_user_token: str,
) -> None:
    with SessionLocal() as session:
        before = session.scalar(
            select(Activity.daily_score).where(
                Activity.user_id == MOCK_USER_ID,
                Activity.date == date.today(),
            )
        )

    response = request(
        "PATCH",
        f"/goals/{goal_id('steps')}",
        {"target_value": 8000},
        token=mock_user_token,
    )

    assert response.status_code == 200
    with SessionLocal() as session:
        after = session.scalar(
            select(Activity.daily_score).where(
                Activity.user_id == MOCK_USER_ID,
                Activity.date == date.today(),
            )
        )
    assert after == before == 77
