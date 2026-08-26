import asyncio
import uuid
from datetime import date
import pytest
from httpx import ASGITransport, AsyncClient, Response

from app.db.database import SessionLocal
from app.db.models.activity import Activity
from app.db.models.user import User
from app.main import app
from app.services.auth import create_access_token
from app.services.daily_score_v2 import calculate_daily_score_v2, explain_daily_score_v2
from app.services.veya_evidence import build_evidence_packet


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


@pytest.fixture
def auth_user():
    user_id = uuid.uuid4()
    with SessionLocal() as session:
        user = User(
            id=user_id,
            email=f"integrity_{user_id}@example.com",
            password_hash="hashed_pw",
        )
        session.add(user)
        session.commit()

    token = create_access_token(user_id)
    return token, user_id


def test_missing_metrics_remain_null_in_db_and_api(auth_user):
    token, user_id = auth_user

    # 1. Health Connect sync with steps and distance present, calories and active_minutes absent
    response = request(
        "PATCH",
        "/activity/today",
        {
            "source": "health_connect",
            "steps": 1085.0,
            "distance": 0.8,
        },
        token=token,
    )
    assert response.status_code == 200
    data = response.json()

    # 2. Verify missing calories and active_minutes remain None (null) in API response
    assert data["steps"] == 1085.0
    assert data["distance"] == 0.8
    assert data["calories"] is None
    assert data["active_minutes"] is None

    # 3. Verify Daily Score uses weight re-normalization for steps (1085 / 10000 = 10.85% -> 11 score)
    assert data["daily_score"] is not None
    assert data["daily_score"] == 11.0


def test_explicit_recorded_zero_is_distinguishable_from_missing(auth_user):
    token, user_id = auth_user

    # Log explicit manual zero for calories
    response = request(
        "PATCH",
        "/activity/today",
        {
            "source": "manual",
            "calories": 0.0,
        },
        token=token,
    )
    assert response.status_code == 200
    data = response.json()

    # Explicit 0.0 must be 0.0, NOT None
    assert data["calories"] == 0.0
    # Unsupplied steps and active_minutes remain None
    assert data["steps"] is None
    assert data["active_minutes"] is None


def test_daily_score_weight_renormalization():
    targets = {"steps": 10000.0, "active_minutes": 60.0, "calories": 450.0}
    score = calculate_daily_score_v2(
        steps=10000.0,
        active_minutes=None,
        calories=None,
        goal_targets=targets,
    )
    assert score == 100.0

    explanation = explain_daily_score_v2(
        steps=10000.0,
        active_minutes=None,
        calories=None,
        goal_targets=targets,
    )
    steps_comp = next(c for c in explanation if c["metric"] == "steps")
    cal_comp = next(c for c in explanation if c["metric"] == "calories")

    assert steps_comp["status"] == "recorded"
    assert steps_comp["points"] == 100.0

    assert cal_comp["status"] == "unrecorded"
    assert cal_comp["value"] is None
    assert cal_comp["points"] is None


def test_partial_sync_preserves_unrelated_valid_metrics(auth_user):
    token, user_id = auth_user

    # First log manual calories = 300.0
    request(
        "PATCH",
        "/activity/today",
        {"source": "manual", "calories": 300.0},
        token=token,
    )

    # Then sync steps from Health Connect (omitting calories)
    response = request(
        "PATCH",
        "/activity/today",
        {"source": "health_connect", "steps": 5000.0},
        token=token,
    )
    assert response.status_code == 200
    data = response.json()

    # Steps updated, manual calories preserved cleanly
    assert data["steps"] == 5000.0
    assert data["calories"] == 300.0


def test_veya_evidence_packet_preserves_null_metrics():
    act = Activity(
        user_id=uuid.uuid4(),
        date=date(2026, 8, 24),
        steps=1085.0,
        active_minutes=None,
        distance=0.8,
        calories=None,
        daily_score=11.0,
        score_version="v2",
        source="health_connect",
        recording_status="recorded",
        steps_provenance="health_connect",
        distance_provenance="health_connect",
        calories_provenance="system",
    )

    packet = build_evidence_packet(
        days=7,
        history=[act],
        insights={
            "days": 7,
            "current_recorded_days": 1,
            "previous_recorded_days": 0,
            "current_legacy_days": 0,
            "previous_legacy_days": 0,
            "total_steps": 1085.0,
            "average_steps": 1085.0,
            "total_distance": 0.8,
            "total_active_calories": 0.0,
            "average_score": 11.0,
            "steps_change_percent": None,
            "distance_change_percent": None,
            "active_calories_change_percent": None,
            "average_score_change": None,
            "trend": "insufficient_data",
            "consistency_days": 1,
            "strongest_steps_day": None,
            "strongest_score_day": None,
        },
        engagement={
            "current_streak": 1,
            "best_streak": 1,
            "today_pending": False,
            "achievements": [],
        },
    )

    fact = packet.activities[0]
    assert fact.steps == 1085.0
    assert fact.active_calories is None
    assert fact.active_minutes is None
