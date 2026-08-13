import uuid

from pydantic import BaseModel, ConfigDict, Field, field_validator


def normalize_email(value: str) -> str:
    normalized = value.strip().lower()
    if (
        not normalized
        or "@" not in normalized
        or normalized.startswith("@")
        or normalized.endswith("@")
    ):
        raise ValueError("Enter a valid email address")
    return normalized


class LoginRequest(BaseModel):
    email: str = Field(min_length=3, max_length=320)
    password: str = Field(min_length=1, max_length=1024)

    @field_validator("email")
    @classmethod
    def normalize_email_field(cls, value: str) -> str:
        return normalize_email(value)


class RegisterRequest(LoginRequest):
    password: str = Field(min_length=8, max_length=1024)


class ForgotPasswordRequest(BaseModel):
    email: str = Field(min_length=3, max_length=320)

    @field_validator("email")
    @classmethod
    def normalize_email_field(cls, value: str) -> str:
        return normalize_email(value)


class ForgotPasswordResponse(BaseModel):
    message: str
    development_reset_token: str | None = None


class ResetPasswordRequest(BaseModel):
    token: str = Field(min_length=1, max_length=512)
    new_password: str = Field(min_length=8, max_length=1024)


class ResetPasswordResponse(BaseModel):
    message: str


class UserResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    email: str


class AuthResponse(BaseModel):
    user: UserResponse
    access_token: str
    token_type: str = "bearer"
