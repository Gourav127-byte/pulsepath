import pytest
from pydantic import ValidationError

from app.core.config import Settings
from app.schemas.goal import GoalUpdate


def test_settings_rejects_dev_secret_in_production() -> None:
    with pytest.raises(ValidationError, match="JWT_SECRET must be configured outside development"):
        Settings(
            app_env="production",
            database_url="postgresql+psycopg://user:pass@localhost:5432/db",
            jwt_secret="DEV-ONLY-sample-secret",
        )


def test_settings_accepts_valid_secret_in_production() -> None:
    settings = Settings(
        app_env="production",
        database_url="postgresql+psycopg://user:pass@localhost:5432/db",
        jwt_secret="a-secure-production-secret-key-that-is-long-enough",
    )
    assert settings.app_env == "production"
    assert settings.jwt_secret == "a-secure-production-secret-key-that-is-long-enough"


def test_settings_rejects_expose_password_reset_in_production() -> None:
    with pytest.raises(
        ValidationError,
        match="EXPOSE_PASSWORD_RESET_TOKEN is only allowed in development or test",
    ):
        Settings(
            app_env="production",
            database_url="postgresql+psycopg://user:pass@localhost:5432/db",
            jwt_secret="a-secure-production-secret-key-that-is-long-enough",
            expose_password_reset_token=True,
        )


def test_goal_update_strict_validation() -> None:
    # Valid positive float/int
    valid = GoalUpdate(target_value=12000)
    assert valid.target_value == 12000.0

    # Reject non-numeric strings
    with pytest.raises(ValidationError):
        GoalUpdate(target_value="invalid")  # type: ignore[arg-type]

    # Reject non-positive values
    with pytest.raises(ValidationError):
        GoalUpdate(target_value=0)

    with pytest.raises(ValidationError):
        GoalUpdate(target_value=-100)
