from pydantic import Field, model_validator
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    app_name: str = "PulsePath API"
    app_env: str = "development"
    database_url: str = Field(repr=False)
    jwt_secret: str = Field(
        default="DEV-ONLY-pulsepath-change-before-production",
        repr=False,
    )
    jwt_algorithm: str = "HS256"
    jwt_expiry_hours: int = 24
    expose_password_reset_token: bool = False
    cors_allowed_origins: list[str] = Field(default_factory=list)

    veya_provider: str = "unavailable"
    veya_api_key: str | None = Field(default=None, repr=False)
    veya_api_url: str | None = Field(default=None, repr=False)
    veya_model: str = "gpt-4o-mini"
    veya_timeout_seconds: float = 10.0

    @model_validator(mode="after")
    def reject_development_secret_outside_development(self) -> "Settings":
        if self.app_env != "development" and self.jwt_secret.startswith("DEV-ONLY-"):
            raise ValueError("JWT_SECRET must be configured outside development")
        if self.app_env not in {"development", "test"} and self.expose_password_reset_token:
            raise ValueError(
                "EXPOSE_PASSWORD_RESET_TOKEN is only allowed in development or test"
            )
        return self

    model_config = SettingsConfigDict(env_file=".env", extra="ignore")


settings = Settings()
