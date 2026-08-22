from collections.abc import Mapping


SCORE_VERSION = "v2"
WEIGHTS = {"steps": 0.50, "active_minutes": 0.30, "calories": 0.20}


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
    score = sum(
        component["points"]
        for component in explain_daily_score_v2(
            steps=steps,
            active_minutes=active_minutes,
            calories=calories,
            goal_targets=goal_targets,
        )
    )
    return float(round(min(max(score, 0.0), 100.0)))


def explain_daily_score_v2(
    *,
    steps: float,
    active_minutes: float,
    calories: float,
    goal_targets: Mapping[str, float],
) -> list[dict[str, float | str | None]]:
    values = {"steps": steps, "active_minutes": active_minutes, "calories": calories}
    return [
        {
            "metric": metric,
            "value": values[metric],
            "target": goal_targets.get(metric),
            "progress": _progress(values[metric], goal_targets.get(metric)),
            "weight": weight,
            "points": 100
            * weight
            * _progress(values[metric], goal_targets.get(metric)),
        }
        for metric, weight in WEIGHTS.items()
    ]
