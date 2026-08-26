SCORE_VERSION = "v1"
WEIGHTS = {"steps": 0.50, "active_minutes": 0.30, "calories": 0.20}
DEFAULT_TARGETS = {"steps": 10_000.0, "active_minutes": 60.0, "calories": 450.0}


def _progress(value: float | None, target: float) -> float | None:
    if value is None:
        return None
    if target <= 0:
        return 0.0
    return min(max(value / target, 0.0), 1.0)


def calculate_daily_score(
    *,
    steps: float | None,
    active_minutes: float | None,
    calories: float | None,
    steps_goal: float = 10_000,
    active_goal: float = 60,
    calorie_goal: float = 450,
) -> float | None:
    explained = explain_daily_score(
        steps=steps,
        active_minutes=active_minutes,
        calories=calories,
        steps_goal=steps_goal,
        active_goal=active_goal,
        calorie_goal=calorie_goal,
    )
    available_points = [
        comp["points"] for comp in explained if comp["points"] is not None
    ]
    if not available_points:
        return None
    return float(round(min(max(sum(available_points), 0.0), 100.0)))


def explain_daily_score(
    *,
    steps: float | None,
    active_minutes: float | None,
    calories: float | None,
    steps_goal: float = DEFAULT_TARGETS["steps"],
    active_goal: float = DEFAULT_TARGETS["active_minutes"],
    calorie_goal: float = DEFAULT_TARGETS["calories"],
) -> list[dict[str, float | str | None]]:
    values: dict[str, float | None] = {
        "steps": steps,
        "active_minutes": active_minutes,
        "calories": calories,
    }
    targets = {
        "steps": steps_goal,
        "active_minutes": active_goal,
        "calories": calorie_goal,
    }
    available_metrics = [m for m, val in values.items() if val is not None]
    total_avail_weight = sum(WEIGHTS[m] for m in available_metrics)

    results = []
    for metric, base_weight in WEIGHTS.items():
        val = values[metric]
        target = targets[metric]
        prog = _progress(val, target)

        if val is None or total_avail_weight == 0:
            results.append({
                "metric": metric,
                "value": None,
                "target": target,
                "progress": None,
                "weight": base_weight,
                "points": None,
                "status": "unrecorded",
            })
        else:
            normalized_weight = base_weight / total_avail_weight
            pts = 100.0 * normalized_weight * (prog or 0.0)
            results.append({
                "metric": metric,
                "value": val,
                "target": target,
                "progress": prog,
                "weight": normalized_weight,
                "points": pts,
                "status": "recorded",
            })
    return results
