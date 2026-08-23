import asyncio
import uuid
from datetime import date, timedelta

import pytest
from httpx import ASGITransport, AsyncClient
from pydantic import ValidationError
from sqlalchemy import func, select

from app.db.database import SessionLocal
from app.db.models.activity import Activity
from app.db.models.user import User
from app.main import app
from app.schemas.veya import VeyaStructuredResponse
from app.services.auth import create_access_token
from app.services.veya_evidence import build_evidence_packet
from app.services.veya_provider import get_veya_provider


def _activity(
    *,
    day: date,
    status: str = "recorded",
    source: str = "manual",
    steps: float = 1000,
) -> Activity:
    return Activity(
        user_id=uuid.uuid4(),
        date=day,
        steps=steps,
        active_minutes=20,
        distance=1.5,
        calories=120,
        daily_score=35,
        score_version="v2",
        source=source,
        recording_status=status,
        steps_provenance="manual",
        distance_provenance="health_connect",
        calories_provenance="blended",
    )


def _insights(days: int) -> dict[str, object]:
    return {
        "days": days,
        "current_recorded_days": 1,
        "previous_recorded_days": 0,
        "current_legacy_days": 0,
        "previous_legacy_days": 0,
        "total_steps": 1000,
        "average_steps": 1000,
        "total_distance": 1.5,
        "total_active_calories": 120,
        "average_score": 35,
        "steps_change_percent": None,
        "distance_change_percent": None,
        "active_calories_change_percent": None,
        "average_score_change": None,
        "trend": "insufficient_data",
        "consistency_days": 1,
        "strongest_steps_day": None,
        "strongest_score_day": None,
    }


def _engagement() -> dict[str, object]:
    return {
        "current_streak": 1,
        "best_streak": 1,
        "today_pending": False,
        "achievements": [],
    }


def _packet(days: int, history: list[Activity]):
    return build_evidence_packet(
        days=days,
        history=history,
        insights=_insights(days),
        engagement=_engagement(),
    )


async def _get(path: str, token: str | None = None):
    headers = {"Authorization": f"Bearer {token}"} if token else {}
    async with AsyncClient(
        transport=ASGITransport(app=app),
        base_url="http://test",
    ) as client:
        return await client.get(path, headers=headers)


def _create_user_with_activity(*, steps: float) -> tuple[uuid.UUID, str]:
    user_id = uuid.uuid4()
    with SessionLocal() as db:
        user = User(
            id=user_id,
            email=f"{user_id}@veya.test",
            password_hash="not-used-by-this-test",
        )
        db.add(user)
        db.flush()
        activity = _activity(day=date.today(), steps=steps)
        activity.user_id = user_id
        db.add(activity)
        db.commit()
    return user_id, create_access_token(user_id)


def test_evidence_packet_is_deterministic_and_preserves_exact_semantics() -> None:
    today = date.today()
    legacy = _activity(
        day=today - timedelta(days=2),
        status="legacy_unknown",
        source="manual",
        steps=700,
    )
    confirmed = _activity(day=today, steps=1400)

    first = _packet(7, [confirmed, legacy])
    second = _packet(7, [legacy, confirmed])

    assert first == second
    assert [fact.date for fact in first.activities] == [legacy.date, confirmed.date]
    assert first.activities[0].recording_status == "legacy_unknown"
    assert first.activities[0].source == "manual"
    assert first.activities[1].steps_provenance == "manual"
    assert first.activities[1].distance_provenance == "health_connect"
    assert first.activities[1].active_calories_provenance == "blended"
    assert first.activities[1].active_minutes_provenance == "system"
    assert first.integrity.level == "sparse"
    assert first.integrity.confirmed_days == 1
    assert first.integrity.legacy_days == 1
    assert first.integrity.missing_days == 5


@pytest.mark.parametrize(
    ("recorded_days", "expected"),
    [(5, "solid"), (2, "partial"), (1, "sparse")],
)
def test_integrity_lens_has_deterministic_thresholds(
    recorded_days: int, expected: str
) -> None:
    today = date.today()
    history = [
        _activity(day=today - timedelta(days=offset))
        for offset in range(recorded_days)
    ]

    assert _packet(7, history).integrity.level == expected


def test_unrecorded_rows_cannot_be_silently_relabelled_as_evidence() -> None:
    with pytest.raises(ValidationError):
        _packet(7, [_activity(day=date.today(), status="unrecorded")])


def test_foundation_requires_auth_and_rejects_unsupported_ranges() -> None:
    assert asyncio.run(_get("/veya/foundation")).status_code == 401
    _user_id, token = _create_user_with_activity(steps=1234)
    assert asyncio.run(_get("/veya/foundation?days=8", token)).status_code == 422


def test_foundation_is_user_isolated_read_only_and_has_safe_fallback() -> None:
    user_a, token_a = _create_user_with_activity(steps=1111)
    _user_b, _token_b = _create_user_with_activity(steps=9999)
    with SessionLocal() as db:
        before = db.scalar(
            select(func.count()).select_from(Activity).where(Activity.user_id == user_a)
        )

    response = asyncio.run(_get("/veya/foundation?days=7", token_a))

    assert response.status_code == 200
    payload = response.json()
    assert [fact["steps"] for fact in payload["evidence"]["activities"]] == [
        1111.0
    ]
    assert payload["response"] == {
        "status": "provider_unavailable",
        "summary": "VEYA insights are temporarily unavailable.",
        "observations": [],
        "limitations": [
            "No AI interpretation was generated.",
            "Verified PulsePath evidence remains available in this response.",
        ],
        "medical_or_causal_claims": False,
    }
    with SessionLocal() as db:
        after = db.scalar(
            select(func.count()).select_from(Activity).where(Activity.user_id == user_a)
        )
    assert after == before


def test_provider_receives_only_structured_evidence_and_safety_constraints() -> None:
    _user_id, token = _create_user_with_activity(steps=4321)

    class CapturingProvider:
        request = None

        async def generate(self, request):
            self.request = request
            return VeyaStructuredResponse(
                status="generated",
                summary="One confirmed activity day is available.",
                limitations=("Evidence is sparse.",),
            )

    provider = CapturingProvider()
    app.dependency_overrides[get_veya_provider] = lambda: provider
    try:
        response = asyncio.run(_get("/veya/foundation", token))
    finally:
        app.dependency_overrides.pop(get_veya_provider, None)

    assert response.status_code == 200
    assert provider.request is not None
    serialized = provider.request.model_dump(mode="json")
    assert "user_id" not in str(serialized)
    assert "password" not in str(serialized)
    assert any("medical" in constraint for constraint in serialized["constraints"])
    assert any("causal" in constraint for constraint in serialized["constraints"])
