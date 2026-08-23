from collections.abc import Sequence
from datetime import date, timedelta

from app.db.models.activity import Activity


def _recorded_dates(activities: Sequence[Activity]) -> list[date]:
    return sorted(
        [
            activity.date
            for activity in activities
            if activity.recording_status == "recorded"
        ]
    )


def _run_lengths(dates: Sequence[date]) -> list[tuple[date, date, int]]:
    if not dates:
        return []

    runs: list[tuple[date, date, int]] = []
    start = previous = dates[0]

    for current in dates[1:]:
        if current - previous == timedelta(days=1):
            previous = current
            continue
        runs.append((start, previous, (previous - start).days + 1))
        start = previous = current

    runs.append((start, previous, (previous - start).days + 1))
    return runs


def calculate_current_streak(
    activities: Sequence[Activity], *, today: date
) -> tuple[int, bool]:
    """Return the confirmed streak and whether today still has grace."""
    statuses = {activity.date: activity.recording_status for activity in activities}
    today_pending = statuses.get(today) != "recorded"
    cursor = today - timedelta(days=1) if today_pending else today
    streak = 0

    while statuses.get(cursor) == "recorded":
        streak += 1
        cursor -= timedelta(days=1)

    return streak, today_pending


def calculate_best_streak(activities: Sequence[Activity]) -> int:
    """Return the longest consecutive run of confirmed recorded days."""
    dates = _recorded_dates(activities)
    if not dates:
        return 0

    best = 0
    current = 0
    previous: date | None = None
    for current_date in dates:
        if previous is not None and current_date - previous == timedelta(days=1):
            current += 1
        else:
            current = 1
        best = max(best, current)
        previous = current_date
    return best


def _unlock_date_for_target(runs: Sequence[tuple[date, date, int]], target: int) -> date | None:
    for run_start, _run_end, run_length in runs:
        if run_length >= target:
            return run_start + timedelta(days=target - 1)
    return None


def _count_milestone_unlock_date(dates: Sequence[date], target: int) -> date | None:
    for index, current_date in enumerate(dates):
        if index + 1 >= target:
            return current_date
    return None


def build_activity_achievements(
    activities: Sequence[Activity], *, today: date
) -> list[dict[str, object]]:
    """Build provable milestone achievements without inventing historical data."""
    recorded_dates = _recorded_dates(activities)
    best_streak = calculate_best_streak(activities)
    runs = _run_lengths(recorded_dates)
    unlockable = [
        {
            "id": "first_confirmed_activity",
            "title": "First confirmed activity",
            "description": "A confirmed recorded day is now in your history.",
            "target": 1,
            "value": len(recorded_dates),
            "metric": "recorded_days",
            "unlock_date": recorded_dates[0] if recorded_dates else None,
        },
        {
            "id": "streak_3",
            "title": "3-day streak",
            "description": "Maintain a three-day run of recorded activity.",
            "target": 3,
            "value": best_streak,
            "metric": "best_streak",
            "unlock_date": _unlock_date_for_target(runs, 3),
        },
        {
            "id": "streak_7",
            "title": "7-day streak",
            "description": "Maintain a seven-day run of recorded activity.",
            "target": 7,
            "value": best_streak,
            "metric": "best_streak",
            "unlock_date": _unlock_date_for_target(runs, 7),
        },
        {
            "id": "streak_14",
            "title": "14-day streak",
            "description": "Maintain a fourteen-day run of recorded activity.",
            "target": 14,
            "value": best_streak,
            "metric": "best_streak",
            "unlock_date": _unlock_date_for_target(runs, 14),
        },
        {
            "id": "streak_30",
            "title": "30-day streak",
            "description": "Maintain a thirty-day run of recorded activity.",
            "target": 30,
            "value": best_streak,
            "metric": "best_streak",
            "unlock_date": _unlock_date_for_target(runs, 30),
        },
        {
            "id": "confirmed_activity_days_30",
            "title": "30 confirmed activity days",
            "description": "Reach thirty confirmed recorded days overall.",
            "target": 30,
            "value": len(recorded_dates),
            "metric": "recorded_days",
            "unlock_date": _count_milestone_unlock_date(recorded_dates, 30),
        },
    ]

    achievements: list[dict[str, object]] = []
    for item in unlockable:
        target = int(item["target"])  # type: ignore[assignment]
        progress = min(float(item["value"]) / float(target), 1.0)
        unlocked = float(item["value"]) >= float(target)
        unlock_date = item["unlock_date"]
        achievements.append(
            {
                "id": item["id"],
                "title": item["title"],
                "description": item["description"],
                "unlocked": unlocked,
                "progress": progress,
                "unlock_date": unlock_date if unlocked else None,
            }
        )
    return achievements
