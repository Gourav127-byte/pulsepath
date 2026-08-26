"""
Physical Metric Sanity Module for PulsePath.
Provides physical conversion formulas and validation boundaries for physical activity metrics.
- Distance (km): 1 step = 0.000762 km (stride ~0.762m)
- Calories (kcal): 0.04 kcal/step

Active Minutes intentionally have no estimator. They come only from recorded
Health Connect workout/exercise duration or valid manual input.
"""


def estimate_distance_km(steps: float | int) -> float:
    """Estimates walking distance in kilometers based on steps (stride ~0.762m)."""
    if steps < 0:
        raise ValueError("Steps cannot be negative")
    return round(float(steps) * 0.000762, 2)


def estimate_calories_kcal(steps: float | int) -> float:
    """Estimates active calories burned based on steps (0.04 kcal/step)."""
    if steps < 0:
        raise ValueError("Steps cannot be negative")
    return round(float(steps) * 0.04, 1)


def validate_metric_sanity(
    *,
    steps: float | None = None,
    distance_km: float | None = None,
    active_minutes: float | None = None,
    calories_kcal: float | None = None,
) -> dict[str, bool]:
    """
    Validates physical metric boundaries:
    - Max human steps/day <= 120,000
    - Max human distance/day <= 100 km
    - Max human active minutes/day <= 1440 mins
    - Max human active calories/day <= 10,000 kcal
    """
    return {
        "steps_sane": steps is None or (0 <= steps <= 120_000),
        "distance_sane": distance_km is None or (0 <= distance_km <= 100.0),
        "active_minutes_sane": active_minutes is None or (0 <= active_minutes <= 1440),
        "calories_sane": calories_kcal is None or (0 <= calories_kcal <= 10_000),
    }
