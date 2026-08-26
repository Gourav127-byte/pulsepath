import pytest
from app.services.activity_sanity import (
    estimate_calories_kcal,
    estimate_distance_km,
    validate_metric_sanity,
)


def test_estimate_distance_km() -> None:
    assert estimate_distance_km(0) == 0.0
    assert estimate_distance_km(10_000) == 7.62
    assert estimate_distance_km(5_000) == 3.81


def test_estimate_calories_kcal() -> None:
    assert estimate_calories_kcal(0) == 0.0
    assert estimate_calories_kcal(10_000) == 400.0
    assert estimate_calories_kcal(2_500) == 100.0


def test_negative_steps_raises_value_error() -> None:
    with pytest.raises(ValueError, match="cannot be negative"):
        estimate_distance_km(-100)


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
