from collections.abc import Mapping, Sequence
from math import ceil

from app.db.models.activity import Activity
from app.schemas.activity import ActivityEngagementResponse, ActivityInsightsResponse
from app.schemas.veya import (
    VeyaActivityFact,
    VeyaEvidencePacket,
    VeyaIntegrityLens,
)


def _integrity_lens(
    *, days: int, confirmed_days: int, legacy_days: int
) -> VeyaIntegrityLens:
    missing_days = max(days - confirmed_days - legacy_days, 0)
    coverage = confirmed_days / days
    solid_minimum = ceil(days * 0.70)

    if confirmed_days >= solid_minimum and legacy_days == 0:
        level = "solid"
        rationale = "At least 70% of the period has confirmed recorded data."
    elif confirmed_days >= 2:
        level = "partial"
        rationale = "Some confirmed history is available, but coverage is incomplete."
    else:
        level = "sparse"
        rationale = "Fewer than two confirmed recorded days are available."

    if legacy_days:
        rationale += " Legacy records are visible but do not increase evidence strength."

    return VeyaIntegrityLens(
        level=level,
        confirmed_days=confirmed_days,
        legacy_days=legacy_days,
        missing_days=missing_days,
        confirmed_coverage=coverage,
        rationale=rationale,
    )


def build_evidence_packet(
    *,
    days: int,
    history: Sequence[Activity],
    insights: Mapping[str, object],
    engagement: Mapping[str, object],
) -> VeyaEvidencePacket:
    """Build the deterministic, data-minimized packet exposed to AI providers."""
    if days not in (7, 30):
        raise ValueError("days must be either 7 or 30")

    ordered = sorted(history, key=lambda activity: activity.date)
    facts = tuple(
        VeyaActivityFact(
            date=activity.date,
            steps=activity.steps,
            active_minutes=activity.active_minutes,
            distance=activity.distance,
            active_calories=activity.calories,
            daily_score=activity.daily_score,
            score_version=activity.score_version,
            source=activity.source,
            recording_status=activity.recording_status,
            steps_provenance=activity.steps_provenance,
            distance_provenance=activity.distance_provenance,
            active_calories_provenance=activity.calories_provenance,
            active_minutes_provenance=activity.active_minutes_provenance,
        )
        for activity in ordered
    )
    confirmed_days = sum(fact.recording_status == "recorded" for fact in facts)
    legacy_days = sum(fact.recording_status == "legacy_unknown" for fact in facts)

    return VeyaEvidencePacket(
        range_days=days,
        activities=facts,
        insights=ActivityInsightsResponse.model_validate(insights),
        engagement=ActivityEngagementResponse.model_validate(engagement),
        integrity=_integrity_lens(
            days=days,
            confirmed_days=confirmed_days,
            legacy_days=legacy_days,
        ),
    )
