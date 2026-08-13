SCORE_VERSION = "v1"


def _progress(value: float, target: float) -> float:
    if target <= 0:
        return 0.0
    return min(max(value / target, 0.0), 1.0)


def calculate_daily_score(
    *,
    steps: float,
    active_minutes: float,
    calories: float,
    steps_goal: float = 10_000,
    active_goal: float = 60,
    calorie_goal: float = 450,
) -> float:
    score = 100 * (
        0.50 * _progress(steps, steps_goal)
        + 0.30 * _progress(active_minutes, active_goal)
        + 0.20 * _progress(calories, calorie_goal)
    )
    return float(round(min(max(score, 0.0), 100.0)))
