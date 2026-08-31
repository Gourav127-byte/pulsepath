"""
Physical Metric Sanity Module for PulsePath.
Provides boundary validation for physical activity metrics.
PulsePath does NOT derive distance or calories from steps.
All metrics must come from recorded evidence (Health Connect) or explicit user input.
"""


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
