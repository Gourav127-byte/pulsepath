from datetime import date, timedelta

import pytest

from app.db.models.activity import Activity
from app.schemas.veya import (
    VeyaEvidenceCitation,
    VeyaObservation,
    VeyaStructuredResponse,
)
from app.services.veya_evidence import build_evidence_packet
from app.services.veya_grounding import (
    VeyaGroundingError,
    validate_and_ground_veya_response,
)


def _activity(
    *,
    day: date,
    status: str = "recorded",
    source: str = "manual",
    steps: float = 1000,
) -> Activity:
    return Activity(
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
        distance_provenance="system",
        calories_provenance="system",
    )


def _sample_packet(*, confirmed_count: int, legacy_count: int = 0):
    today = date.today()
    history = []
    for offset in range(confirmed_count):
        history.append(_activity(day=today - timedelta(days=offset), status="recorded"))
    for offset in range(legacy_count):
        history.append(_activity(day=today - timedelta(days=10 + offset), status="legacy_unknown"))

    return build_evidence_packet(
        days=7,
        history=history,
        insights={
            "days": 7,
            "current_recorded_days": confirmed_count,
            "previous_recorded_days": 0,
            "current_legacy_days": legacy_count,
            "previous_legacy_days": 0,
            "total_steps": 5000,
            "average_steps": 5000,
            "total_distance": 3.5,
            "total_active_calories": 250,
            "average_score": 75,
            "steps_change_percent": None,
            "distance_change_percent": None,
            "active_calories_change_percent": None,
            "average_score_change": None,
            "trend": "insufficient_data",
            "consistency_days": confirmed_count,
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


def test_confidence_capping_by_integrity_level() -> None:
    today = date.today()
    obs = VeyaObservation(
        text="Consistent steps completed.",
        confidence="high",
        category="consistency",
        evidence=(VeyaEvidenceCitation(fact="steps", date=today),),
    )
    raw = VeyaStructuredResponse(status="generated", summary="Summary", observations=(obs,))

    # 1. Solid integrity (5 confirmed) -> retains high
    packet_solid = _sample_packet(confirmed_count=5)
    res_solid = validate_and_ground_veya_response(raw, packet_solid)
    assert res_solid.observations[0].confidence == "high"

    # 2. Partial integrity (2 confirmed) -> capped at medium
    packet_partial = _sample_packet(confirmed_count=2)
    res_partial = validate_and_ground_veya_response(raw, packet_partial)
    assert res_partial.observations[0].confidence == "medium"

    # 3. Sparse integrity (1 confirmed) -> capped at low
    packet_sparse = _sample_packet(confirmed_count=1)
    res_sparse = validate_and_ground_veya_response(raw, packet_sparse)
    assert res_sparse.observations[0].confidence == "low"
    assert any("sparse" in lim.lower() for lim in res_sparse.limitations)


def test_rejection_of_hallucinated_dates() -> None:
    packet = _sample_packet(confirmed_count=5)
    fake_date = date.today() - timedelta(days=99)
    obs = VeyaObservation(
        text="Walked steps.",
        confidence="high",
        category="trend",
        evidence=(VeyaEvidenceCitation(fact="steps", date=fake_date),),
    )
    raw = VeyaStructuredResponse(status="generated", summary="Summary", observations=(obs,))

    with pytest.raises(VeyaGroundingError, match="hallucinated or out-of-range date"):
        validate_and_ground_veya_response(raw, packet)


def test_rejection_of_hallucinated_facts() -> None:
    packet = _sample_packet(confirmed_count=5)
    obs = VeyaObservation(
        text="Sleep duration was good.",
        confidence="high",
        category="routine_recovery",
        evidence=(VeyaEvidenceCitation(fact="sleep_hours", date=date.today()),),
    )
    raw = VeyaStructuredResponse(status="generated", summary="Summary", observations=(obs,))

    with pytest.raises(VeyaGroundingError, match="unsupported or hallucinated fact"):
        validate_and_ground_veya_response(raw, packet)


def test_active_minutes_health_connect_guardrail() -> None:
    packet = _sample_packet(confirmed_count=5)
    obs = VeyaObservation(
        text="Active minutes from Health Connect reached 30.",
        confidence="high",
        category="goal_progress",
        evidence=(VeyaEvidenceCitation(fact="active_minutes", date=date.today()),),
    )
    raw = VeyaStructuredResponse(status="generated", summary="Summary", observations=(obs,))

    with pytest.raises(VeyaGroundingError, match="Active Minutes cannot be described as Health Connect"):
        validate_and_ground_veya_response(raw, packet)


def test_missing_days_not_described_as_zero_recorded() -> None:
    packet = _sample_packet(confirmed_count=5)
    obs = VeyaObservation(
        text="On missing days you walked 0 steps.",
        confidence="high",
        category="consistency",
        evidence=(VeyaEvidenceCitation(fact="steps", date=date.today()),),
    )
    raw = VeyaStructuredResponse(status="generated", summary="Summary", observations=(obs,))

    with pytest.raises(VeyaGroundingError, match="Missing days cannot be described as zero"):
        validate_and_ground_veya_response(raw, packet)


def test_legacy_days_cap_confidence_to_low() -> None:
    packet = _sample_packet(confirmed_count=2, legacy_count=1)
    legacy_date = date.today() - timedelta(days=10)
    obs = VeyaObservation(
        text="Legacy steps logged.",
        confidence="high",
        category="routine_recovery",
        evidence=(VeyaEvidenceCitation(fact="steps", date=legacy_date),),
    )
    raw = VeyaStructuredResponse(status="generated", summary="Summary", observations=(obs,))

    res = validate_and_ground_veya_response(raw, packet)
    assert res.observations[0].confidence == "low"


def test_rejection_of_medical_causal_text_in_summary_or_obs() -> None:
    packet = _sample_packet(confirmed_count=5)
    obs = VeyaObservation(
        text="This step increase caused a reduction in your fatigue.",
        confidence="high",
        category="trend",
        evidence=(VeyaEvidenceCitation(fact="steps", date=date.today()),),
    )
    raw = VeyaStructuredResponse(status="generated", summary="Activity summary", observations=(obs,))

    with pytest.raises(VeyaGroundingError, match="Forbidden medical or causal claim"):
        validate_and_ground_veya_response(raw, packet)


def test_rejection_of_unanchored_daily_metric_citation() -> None:
    packet = _sample_packet(confirmed_count=5)
    obs = VeyaObservation(
        text="Walked 1,000 steps.",
        confidence="high",
        category="consistency",
        evidence=(VeyaEvidenceCitation(fact="steps", date=None),),
    )
    raw = VeyaStructuredResponse(status="generated", summary="Summary", observations=(obs,))

    with pytest.raises(VeyaGroundingError, match="must cite a specific date"):
        validate_and_ground_veya_response(raw, packet)


def test_rejection_of_ungrounded_numeric_step_value() -> None:
    packet = _sample_packet(confirmed_count=5)
    today = date.today()
    # Actual steps is 1000, text claims 50,000 steps on that date
    obs = VeyaObservation(
        text="Walked 50,000 steps today.",
        confidence="high",
        category="consistency",
        evidence=(VeyaEvidenceCitation(fact="steps", date=today),),
    )
    raw = VeyaStructuredResponse(status="generated", summary="Summary", observations=(obs,))

    with pytest.raises(VeyaGroundingError, match="ungrounded step count value"):
        validate_and_ground_veya_response(raw, packet)


def test_rejection_of_unsupported_trend_claim() -> None:
    packet = _sample_packet(confirmed_count=5)
    assert packet.insights.trend == "insufficient_data"
    obs = VeyaObservation(
        text="Your overall trend is improving.",
        confidence="high",
        category="trend",
        evidence=(VeyaEvidenceCitation(fact="trend"),),
    )
    raw = VeyaStructuredResponse(status="generated", summary="Summary", observations=(obs,))

    with pytest.raises(VeyaGroundingError, match="claims improving trend"):
        validate_and_ground_veya_response(raw, packet)
