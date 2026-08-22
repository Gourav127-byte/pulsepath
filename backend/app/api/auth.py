from datetime import date, datetime, timedelta, timezone
from typing import Annotated

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import select
from sqlalchemy.exc import IntegrityError, SQLAlchemyError
from sqlalchemy.orm import Session

from app.db.database import get_db
from app.api.dependencies import get_current_user
from app.db.models.activity import Activity
from app.db.models.goal import Goal
from app.db.models.password_reset_token import PasswordResetToken
from app.db.models.profile import Profile
from app.db.models.user import User
from app.services.daily_score import calculate_daily_score, SCORE_VERSION
from app.schemas.auth import (
    AuthResponse,
    ForgotPasswordRequest,
    ForgotPasswordResponse,
    LoginRequest,
    RegisterRequest,
    ResetPasswordRequest,
    ResetPasswordResponse,
    UserResponse,
)
from app.core.config import settings
from app.services.auth import (
    PASSWORD_RESET_EXPIRY_MINUTES,
    create_access_token,
    generate_password_reset_token,
    hash_password,
    hash_password_reset_token,
    verify_password,
    verify_unknown_user_password,
)

router = APIRouter(prefix="/auth", tags=["auth"])
FORGOT_PASSWORD_MESSAGE = (
    "If an account exists for that email, password reset instructions have been sent."
)
RESET_PASSWORD_MESSAGE = "Password has been reset successfully."
RESET_PASSWORD_ERROR = "The password reset token is invalid or expired."


@router.get("/me", response_model=UserResponse)
def current_user(
    user: Annotated[User, Depends(get_current_user)],
) -> UserResponse:
    """Validate a stored access token without protecting domain routes yet."""
    return UserResponse.model_validate(user)


def build_auth_response(user: User) -> AuthResponse:
    return AuthResponse(
        user=UserResponse.model_validate(user),
        access_token=create_access_token(user.id),
    )


@router.post(
    "/register",
    response_model=AuthResponse,
    status_code=status.HTTP_201_CREATED,
)
def register(
    credentials: RegisterRequest,
    db: Annotated[Session, Depends(get_db)],
) -> AuthResponse:
    existing = db.scalar(select(User).where(User.email == credentials.email))
    if existing is not None:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="An account with this email already exists",
        )

    try:
        user = User(
            email=credentials.email,
            password_hash=hash_password(credentials.password),
        )
        db.add(user)
        db.flush()

        display_name = credentials.email.split("@")[0].capitalize()[:40]
        db.add(
            Profile(
                user_id=user.id,
                display_name=display_name,
                use_metric_units=True,
            )
        )
        db.add_all(
            [
                Goal(user_id=user.id, type="steps", target_value=10000),
                Goal(user_id=user.id, type="active_minutes", target_value=60),
                Goal(user_id=user.id, type="calories", target_value=450),
            ]
        )
        db.add(
            Activity(
                user_id=user.id,
                date=date.today(),
                steps=0,
                active_minutes=0,
                calories=0,
                distance=0,
                daily_score=0,
                score_version=SCORE_VERSION,
                source="system",
            )
        )
        db.commit()
        db.refresh(user)
    except IntegrityError as error:
        db.rollback()
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="An account with this email already exists",
        ) from error
    except SQLAlchemyError as error:
        db.rollback()
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Could not create account",
        ) from error
    return build_auth_response(user)


@router.post("/login", response_model=AuthResponse)
def login(
    credentials: LoginRequest,
    db: Annotated[Session, Depends(get_db)],
) -> AuthResponse:
    user = db.scalar(select(User).where(User.email == credentials.email))
    if user is None:
        verify_unknown_user_password(credentials.password)
    if user is None or not verify_password(credentials.password, user.password_hash):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid email or password",
        )
    return build_auth_response(user)


@router.post(
    "/forgot-password",
    response_model=ForgotPasswordResponse,
    response_model_exclude_none=True,
)
def forgot_password(
    request: ForgotPasswordRequest,
    db: Annotated[Session, Depends(get_db)],
) -> ForgotPasswordResponse:
    raw_token = generate_password_reset_token()
    user = db.scalar(select(User).where(User.email == request.email))
    if user is None:
        return ForgotPasswordResponse(message=FORGOT_PASSWORD_MESSAGE)

    reset_token = PasswordResetToken(
        user_id=user.id,
        token_hash=hash_password_reset_token(raw_token),
        expires_at=datetime.now(timezone.utc)
        + timedelta(minutes=PASSWORD_RESET_EXPIRY_MINUTES),
    )
    db.add(reset_token)
    try:
        db.commit()
    except SQLAlchemyError as error:
        db.rollback()
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Could not process password reset request",
        ) from error

    return ForgotPasswordResponse(
        message=FORGOT_PASSWORD_MESSAGE,
        development_reset_token=(
            raw_token if settings.expose_password_reset_token else None
        ),
    )


@router.post("/reset-password", response_model=ResetPasswordResponse)
def reset_password(
    request: ResetPasswordRequest,
    db: Annotated[Session, Depends(get_db)],
) -> ResetPasswordResponse:
    token_hash = hash_password_reset_token(request.token)
    reset_token = db.scalar(
        select(PasswordResetToken)
        .where(PasswordResetToken.token_hash == token_hash)
        .with_for_update()
    )
    now = datetime.now(timezone.utc)
    if (
        reset_token is None
        or reset_token.used_at is not None
        or reset_token.expires_at <= now
    ):
        db.rollback()
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=RESET_PASSWORD_ERROR,
        )

    user = db.get(User, reset_token.user_id)
    if user is None:
        db.rollback()
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=RESET_PASSWORD_ERROR,
        )

    new_password_hash = hash_password(request.new_password)
    user.password_hash = new_password_hash
    reset_token.used_at = now
    try:
        db.commit()
    except SQLAlchemyError as error:
        db.rollback()
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Could not reset password",
        ) from error
    return ResetPasswordResponse(message=RESET_PASSWORD_MESSAGE)
