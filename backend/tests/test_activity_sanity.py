from app.services.activity_sanity import (
    validate_metric_sanity,
)


def test_validate_metric_sanity_valid_boundaries() -> None:
    results = validate_metric_sanity(
        steps=10_000,
        distance_km=7.62,
        active_minutes=100,
        calories_kcal=400.0,
    )
    assert all(results.values())


def test_validate_metric_sanity_detects_insane_values() -> None:
    results = validate_metric_sanity(
        steps=150_000,
        distance_km=150.0,
        active_minutes=2000,
        calories_kcal=20_000.0,
    )
    assert not results["steps_sane"]
    assert not results["distance_sane"]
    assert not results["active_minutes_sane"]
    assert not results["calories_sane"]
