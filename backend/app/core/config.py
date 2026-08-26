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
    veya_rate_limit_per_minute: int = 10
    veya_daily_quota_per_user: int = 50

    # Auth Credentials & Provider Settings
    google_client_id: str | None = Field(
        default="203075262869-97sdh39dl408s9omi6m1q2co5t6s1nvt.apps.googleusercontent.com",
        repr=False,
    )

    sms_provider: str = "mock"  # "mock", "twilio", "fast2sms", "generic"
    sms_api_key: str | None = Field(default=None, repr=False)
    sms_api_url: str | None = Field(default=None, repr=False)
    sms_sender_id: str | None = Field(default=None, repr=False)

    email_provider: str = "mock"  # "mock", "smtp", "sendgrid", "resend"
    smtp_host: str | None = Field(default=None, repr=False)
    smtp_port: int = 587
    smtp_user: str | None = Field(default=None, repr=False)
    smtp_password: str | None = Field(default=None, repr=False)
    email_from: str = "noreply@pulsepath.app"

    @model_validator(mode="after")
    def reject_development_secret_outside_development(self) -> "Settings":
        if self.app_env != "development" and self.jwt_secret.startswith("DEV-ONLY-"):
            raise ValueError("JWT_SECRET must be configured outside development")
        if self.app_env not in {"development", "test"} and self.expose_password_reset_token:
            raise ValueError(
                "EXPOSE_PASSWORD_RESET_TOKEN is only allowed in development or test"
            )
        if self.app_env == "production":
            if self.sms_provider != "mock" and not self.sms_api_key:
                raise ValueError("sms_api_key must be configured for production SMS provider")
            if self.email_provider != "mock" and not (self.smtp_host or self.veya_api_key):
                raise ValueError("smtp_host or Resend API key must be configured for production email provider")
        return self

    model_config = SettingsConfigDict(env_file=".env", extra="ignore")


settings = Settings()
