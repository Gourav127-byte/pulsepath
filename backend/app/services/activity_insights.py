from collections.abc import Sequence
from statistics import fmean

from app.db.models.activity import Activity

_TREND_THRESHOLD = 5.0


def determine_trend(
    current_recorded_days: int,
    previous_recorded_days: int,
    average_score_change: float | None,
) -> str:
    """Return a deterministic trend label from confirmed recorded data only."""
    if (
        current_recorded_days == 0
        or previous_recorded_days == 0
        or average_score_change is None
    ):
        return "insufficient_data"
    if average_score_change > _TREND_THRESHOLD:
        return "improving"
    if average_score_change < -_TREND_THRESHOLD:
        return "declining"
    return "stable"


def _average(records: Sequence[Activity], field: str) -> float | None:
    vals = [float(getattr(record, field)) for record in records if getattr(record, field) is not None]
    if not vals:
        return None
    return float(fmean(vals))


def _percent_change(current: float | None, previous: float | None) -> float | None:
    if current is None or previous is None or previous == 0:
        return None
    return ((current - previous) / previous) * 100


def build_activity_insights(
    current: Sequence[Activity],
    previous: Sequence[Activity],
    *,
    current_legacy_days: int = 0,
    previous_legacy_days: int = 0,
) -> dict[str, object]:
    current_steps = _average(current, "steps")
    previous_steps = _average(previous, "steps")
    current_score = _average(current, "daily_score")
    previous_score = _average(previous, "daily_score")
    average_score_change: float | None = (
        current_score - previous_score
        if current_score is not None and previous_score is not None
        else None
    )
    strongest_steps = (
        max(current, key=lambda item: (item.steps or 0.0, item.daily_score or 0.0, item.date))
        if current
        else None
    )
    strongest_score = (
        max(current, key=lambda item: (item.daily_score or 0.0, item.steps or 0.0, item.date))
        if current
        else None
    )
    trend = determine_trend(len(current), len(previous), average_score_change)
    return {
        "current_recorded_days": len(current),
        "previous_recorded_days": len(previous),
        "current_legacy_days": current_legacy_days,
        "previous_legacy_days": previous_legacy_days,
        "total_steps": sum(float(item.steps or 0.0) for item in current),
        "average_steps": current_steps,
        "total_distance": sum(float(item.distance or 0.0) for item in current),
        "total_active_calories": sum(float(item.calories or 0.0) for item in current),
        "average_score": current_score,
        "steps_change_percent": _percent_change(current_steps, previous_steps),
        "distance_change_percent": _percent_change(
            sum(float(item.distance) for item in current if item.distance is not None) if current else None,
            sum(float(item.distance) for item in previous if item.distance is not None) if previous else None,
        ),
        "active_calories_change_percent": _percent_change(
            sum(float(item.calories) for item in current if item.calories is not None) if current else None,
            sum(float(item.calories) for item in previous if item.calories is not None) if previous else None,
        ),
        "average_score_change": average_score_change,
        "trend": trend,
        "consistency_days": len(current),
        "strongest_steps_day": strongest_steps,
        "strongest_score_day": strongest_score,
    }
