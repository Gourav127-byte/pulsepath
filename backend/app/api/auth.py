import uuid
from datetime import date, datetime, timedelta, timezone
from typing import Annotated

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import select
from sqlalchemy.exc import IntegrityError, SQLAlchemyError
from sqlalchemy.orm import Session

from app.db.database import get_db
from app.api.dependencies import get_current_user
from app.db.models.activity import Activity
from app.db.models.email_otp import EmailOTP
from app.db.models.goal import Goal
from app.db.models.password_reset_token import PasswordResetToken
from app.db.models.phone_otp import PhoneOTP
from app.db.models.profile import Profile
from app.db.models.refresh_token import RefreshToken
from app.db.models.user import User
from app.services.daily_score import calculate_daily_score, SCORE_VERSION
from app.schemas.auth import (
    AuthResponse,
    EmailOTPRequest,
    EmailOTPResponse,
    EmailOTPVerifyRequest,
    ForgotPasswordRequest,
    ForgotPasswordResponse,
    GoogleAuthRequest,
    LoginRequest,
    PhoneOTPRequest,
    PhoneOTPResponse,
    PhoneOTPVerifyRequest,
    RefreshTokenRequest,
    RegisterRequest,
    ResetPasswordRequest,
    ResetPasswordResponse,
    UserResponse,
)
from app.core.config import settings
from app.services.auth import (
    OTP_COOLDOWN_SECONDS,
    OTP_EXPIRY_MINUTES,
    OTP_MAX_ATTEMPTS,
    PASSWORD_RESET_EXPIRY_MINUTES,
    REFRESH_TOKEN_EXPIRY_DAYS,
    create_access_token,
    create_opaque_refresh_token,
    generate_otp,
    generate_password_reset_token,
    hash_otp,
    hash_password,
    hash_password_reset_token,
    hash_token,
    normalize_e164_phone,
    verify_google_id_token,
    verify_password,
    verify_unknown_user_password,
)
from app.services.sms_provider import get_sms_provider

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
    """Validate a stored access token and return user identity."""
    return UserResponse.model_validate(user)


def _init_user_defaults(db: Session, user_id: uuid.UUID, display_name: str) -> None:
    db.add(
        Profile(
            user_id=user_id,
            display_name=display_name,
            use_metric_units=True,
        )
    )
    db.add_all(
        [
            Goal(user_id=user_id, type="steps", target_value=10000),
            Goal(user_id=user_id, type="active_minutes", target_value=60),
            Goal(user_id=user_id, type="calories", target_value=450),
        ]
    )
    db.add(
        Activity(
            user_id=user_id,
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


def build_auth_response(
    user: User, db: Session, family_id: uuid.UUID | None = None
) -> AuthResponse:
    access_token = create_access_token(user.id)
    raw_refresh = create_opaque_refresh_token()
    token_h = hash_token(raw_refresh)
    f_id = family_id or uuid.uuid4()
    expires_at = datetime.now(timezone.utc) + timedelta(days=REFRESH_TOKEN_EXPIRY_DAYS)

    db_refresh = RefreshToken(
        user_id=user.id,
        family_id=f_id,
        token_hash=token_h,
        expires_at=expires_at,
    )
    db.add(db_refresh)
    db.commit()

    return AuthResponse(
        user=UserResponse.model_validate(user),
        access_token=access_token,
        refresh_token=raw_refresh,
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
        _init_user_defaults(db, user.id, display_name)
        db.flush()
        res = build_auth_response(user, db)
        return res
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


@router.post("/login", response_model=AuthResponse)
def login(
    credentials: LoginRequest,
    db: Annotated[Session, Depends(get_db)],
) -> AuthResponse:
    user = db.scalar(select(User).where(User.email == credentials.email))
    if user is None:
        verify_unknown_user_password(credentials.password)
    if user is None or not verify_password(credentials.password, user.password_hash or ""):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid email or password",
        )
    return build_auth_response(user, db)


@router.post("/refresh", response_model=AuthResponse)
def refresh_token(
    request: RefreshTokenRequest,
    db: Annotated[Session, Depends(get_db)],
) -> AuthResponse:
    token_h = hash_token(request.refresh_token)
    ref_record = db.scalar(
        select(RefreshToken).where(RefreshToken.token_hash == token_h)
    )

    now = datetime.now(timezone.utc)
    if ref_record is None or ref_record.expires_at <= now:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid or expired refresh token",
        )

    # TOKEN REUSE DETECTION
    if ref_record.revoked_at is not None:
        # Revoke all tokens in this family immediately!
        all_family_tokens = db.scalars(
            select(RefreshToken).where(RefreshToken.family_id == ref_record.family_id)
        ).all()
        for tok in all_family_tokens:
            if tok.revoked_at is None:
                tok.revoked_at = now
        db.commit()
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Refresh token reuse detected. Revoked all tokens in session family.",
        )

    # Revoke current token
    ref_record.revoked_at = now
    db.flush()

    user = db.get(User, ref_record.user_id)
    if user is None:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="User not found",
        )

    return build_auth_response(user, db, family_id=ref_record.family_id)


@router.post("/logout")
def logout(
    request: RefreshTokenRequest,
    db: Annotated[Session, Depends(get_db)],
) -> dict:
    token_h = hash_token(request.refresh_token)
    ref_record = db.scalar(
        select(RefreshToken).where(RefreshToken.token_hash == token_h)
    )
    if ref_record is not None:
        now = datetime.now(timezone.utc)
        family_tokens = db.scalars(
            select(RefreshToken).where(RefreshToken.family_id == ref_record.family_id)
        ).all()
        for tok in family_tokens:
            if tok.revoked_at is None:
                tok.revoked_at = now
        db.commit()
    return {"message": "Logged out successfully"}


@router.post("/phone/request-otp", response_model=PhoneOTPResponse)
def request_phone_otp(
    request: PhoneOTPRequest,
    db: Annotated[Session, Depends(get_db)],
) -> PhoneOTPResponse:
    try:
        phone = normalize_e164_phone(request.phone_number)
    except ValueError as err:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=str(err),
        ) from err

    now = datetime.now(timezone.utc)
    recent_otp = db.scalar(
        select(PhoneOTP)
        .where(PhoneOTP.phone_number == phone)
        .order_by(PhoneOTP.created_at.desc())
    )

    if (
        recent_otp is not None
        and recent_otp.cooldown_until is not None
        and recent_otp.cooldown_until > now
    ):
        cooldown_left = int((recent_otp.cooldown_until - now).total_seconds())
        return PhoneOTPResponse(
            message="If this phone number is valid, an OTP has been sent.",
            cooldown_seconds=cooldown_left,
        )

    raw_otp = generate_otp()
    otp_h = hash_otp(raw_otp)
    expires_at = now + timedelta(minutes=OTP_EXPIRY_MINUTES)
    cooldown_until = now + timedelta(seconds=OTP_COOLDOWN_SECONDS)

    otp_record = PhoneOTP(
        phone_number=phone,
        otp_hash=otp_h,
        expires_at=expires_at,
        cooldown_until=cooldown_until,
    )
    db.add(otp_record)
    db.commit()

    sms = get_sms_provider()
    sms.send_sms(phone, f"Your PulsePath verification code is {raw_otp}")

    is_dev = getattr(settings, "app_env", getattr(settings, "environment", "development")).lower() in {"development", "test"}
    dev_otp = raw_otp if is_dev else None

    return PhoneOTPResponse(
        message="If this phone number is valid, an OTP has been sent.",
        cooldown_seconds=OTP_COOLDOWN_SECONDS,
        development_otp=dev_otp,
    )


@router.post("/phone/verify-otp", response_model=AuthResponse)
def verify_phone_otp(
    request: PhoneOTPVerifyRequest,
    db: Annotated[Session, Depends(get_db)],
) -> AuthResponse:
    try:
        phone = normalize_e164_phone(request.phone_number)
    except ValueError as err:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=str(err),
        ) from err

    otp_h = hash_otp(request.otp.strip())
    now = datetime.now(timezone.utc)

    otp_record = db.scalar(
        select(PhoneOTP)
        .where(PhoneOTP.phone_number == phone)
        .order_by(PhoneOTP.created_at.desc())
        .with_for_update()
    )

    if (
        otp_record is None
        or otp_record.expires_at <= now
        or otp_record.attempts >= OTP_MAX_ATTEMPTS
    ):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="OTP is invalid or expired.",
        )

    if otp_record.otp_hash != otp_h:
        otp_record.attempts += 1
        db.commit()
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="OTP is invalid or expired.",
        )

    user = db.scalar(select(User).where(User.phone_number == phone))
    if user is None:
        user = User(phone_number=phone)
        db.add(user)
        db.flush()
        display_name = f"User-{phone[-4:]}"
        _init_user_defaults(db, user.id, display_name)
        db.flush()

    db.commit()
    db.refresh(user)
    return build_auth_response(user, db)


@router.post("/email/request-otp", response_model=EmailOTPResponse)
def request_email_otp(
    request: EmailOTPRequest,
    db: Annotated[Session, Depends(get_db)],
) -> EmailOTPResponse:
    email = request.email.strip().lower()
    now = datetime.now(timezone.utc)

    recent_otp = db.scalar(
        select(EmailOTP)
        .where(EmailOTP.email == email)
        .order_by(EmailOTP.created_at.desc())
    )

    if (
        recent_otp is not None
        and recent_otp.cooldown_until is not None
        and recent_otp.cooldown_until > now
    ):
        cooldown_left = int((recent_otp.cooldown_until - now).total_seconds())
        return EmailOTPResponse(
            message="If this email is valid, a verification code has been sent.",
            cooldown_seconds=cooldown_left,
        )

    raw_otp = generate_otp()
    otp_h = hash_otp(raw_otp)
    expires_at = now + timedelta(minutes=OTP_EXPIRY_MINUTES)
    cooldown_until = now + timedelta(seconds=OTP_COOLDOWN_SECONDS)

    otp_record = EmailOTP(
        email=email,
        otp_hash=otp_h,
        expires_at=expires_at,
        cooldown_until=cooldown_until,
    )
    db.add(otp_record)
    db.commit()

    from app.services.email_provider import get_email_provider
    get_email_provider().send_email(
        email,
        "PulsePath Email Verification Code",
        f"Your PulsePath verification code is: {raw_otp}\nThis code will expire in {OTP_EXPIRY_MINUTES} minutes.",
    )

    is_dev = getattr(settings, "app_env", getattr(settings, "environment", "development")).lower() in {"development", "test"}
    dev_otp = raw_otp if is_dev else None

    return EmailOTPResponse(
        message="If this email is valid, a verification code has been sent.",
        cooldown_seconds=OTP_COOLDOWN_SECONDS,
        development_otp=dev_otp,
    )


@router.post("/email/verify-otp", response_model=AuthResponse)
def verify_email_otp(
    request: EmailOTPVerifyRequest,
    db: Annotated[Session, Depends(get_db)],
) -> AuthResponse:
    email = request.email.strip().lower()
    otp_h = hash_otp(request.otp.strip())
    now = datetime.now(timezone.utc)

    otp_record = db.scalar(
        select(EmailOTP)
        .where(EmailOTP.email == email)
        .order_by(EmailOTP.created_at.desc())
        .with_for_update()
    )

    if (
        otp_record is None
        or otp_record.expires_at <= now
        or otp_record.attempts >= OTP_MAX_ATTEMPTS
    ):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="OTP is invalid or expired.",
        )

    if otp_record.otp_hash != otp_h:
        otp_record.attempts += 1
        db.commit()
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="OTP is invalid or expired.",
        )

    user = db.scalar(select(User).where(User.email == email))
    if user is None:
        user = User(email=email)
        db.add(user)
        db.flush()
        display_name = email.split("@")[0].capitalize()[:40]
        _init_user_defaults(db, user.id, display_name)
        db.flush()

    db.commit()
    db.refresh(user)
    return build_auth_response(user, db)


@router.post("/google", response_model=AuthResponse)
def google_auth(
    request: GoogleAuthRequest,
    db: Annotated[Session, Depends(get_db)],
) -> AuthResponse:
    try:
        payload = verify_google_id_token(request.id_token)
    except ValueError as err:
        print(f"\n[GOOGLE_AUTH_ERROR] Token verification failed: {err}\n", flush=True)
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail=str(err),
        ) from err

    google_sub = payload["sub"]
    email = payload.get("email")

    user = db.scalar(select(User).where(User.google_sub == google_sub))
    if user is None and email:
        user = db.scalar(select(User).where(User.email == email))
        if user is not None:
            user.google_sub = google_sub
            db.flush()

    if user is None:
        user = User(email=email, google_sub=google_sub)
        db.add(user)
        db.flush()
        display_name = (email.split("@")[0].capitalize()[:40]) if email else "GoogleUser"
        _init_user_defaults(db, user.id, display_name)
        db.flush()

    db.commit()
    db.refresh(user)
    return build_auth_response(user, db)


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

    from app.services.email_provider import get_email_provider

    reset_token = PasswordResetToken(
        user_id=user.id,
        token_hash=hash_password_reset_token(raw_token),
        expires_at=datetime.now(timezone.utc)
        + timedelta(minutes=PASSWORD_RESET_EXPIRY_MINUTES),
    )
    db.add(reset_token)
    try:
        db.commit()
        get_email_provider().send_email(
            user.email,
            "PulsePath Password Reset Instructions",
            f"Your password reset token is: {raw_token}\nThis token will expire in {PASSWORD_RESET_EXPIRY_MINUTES} minutes.",
        )
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
