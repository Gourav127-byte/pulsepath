from collections.abc import Mapping


SCORE_VERSION = "v2"


def _progress(value: float, target: float | None) -> float:
    if target is None or target <= 0:
        return 0.0
    return min(max(value / target, 0.0), 1.0)


def calculate_daily_score_v2(
    *,
    steps: float,
    active_minutes: float,
    calories: float,
    goal_targets: Mapping[str, float],
) -> float:
    score = 100 * (
        0.50 * _progress(steps, goal_targets.get("steps"))
        + 0.30 * _progress(
            active_minutes,
            goal_targets.get("active_minutes"),
        )
        + 0.20 * _progress(calories, goal_targets.get("calories"))
    )
    return float(round(min(max(score, 0.0), 100.0)))
