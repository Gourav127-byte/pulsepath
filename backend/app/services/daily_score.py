SCORE_VERSION = "v1"
WEIGHTS = {"steps": 0.50, "active_minutes": 0.30, "calories": 0.20}
DEFAULT_TARGETS = {"steps": 10_000.0, "active_minutes": 60.0, "calories": 450.0}


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
    score = sum(
        component["points"]
        for component in explain_daily_score(
            steps=steps,
            active_minutes=active_minutes,
            calories=calories,
            steps_goal=steps_goal,
            active_goal=active_goal,
            calorie_goal=calorie_goal,
        )
    )
    return float(round(min(max(score, 0.0), 100.0)))


def explain_daily_score(
    *,
    steps: float,
    active_minutes: float,
    calories: float,
    steps_goal: float = DEFAULT_TARGETS["steps"],
    active_goal: float = DEFAULT_TARGETS["active_minutes"],
    calorie_goal: float = DEFAULT_TARGETS["calories"],
) -> list[dict[str, float | str]]:
    values = {"steps": steps, "active_minutes": active_minutes, "calories": calories}
    targets = {
        "steps": steps_goal,
        "active_minutes": active_goal,
        "calories": calorie_goal,
    }
    return [
        {
            "metric": metric,
            "value": values[metric],
            "target": targets[metric],
            "progress": _progress(values[metric], targets[metric]),
            "weight": weight,
            "points": 100 * weight * _progress(values[metric], targets[metric]),
        }
        for metric, weight in WEIGHTS.items()
    ]
