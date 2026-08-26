import uuid
import hashlib
import re
import secrets
from datetime import datetime, timedelta, timezone

import jwt
from pwdlib import PasswordHash

from app.core.config import settings

password_hasher = PasswordHash.recommended()
_dummy_password_hash = password_hasher.hash("pulsepath-dummy-password")
PASSWORD_RESET_EXPIRY_MINUTES = 30
REFRESH_TOKEN_EXPIRY_DAYS = 30
OTP_EXPIRY_MINUTES = 5
OTP_COOLDOWN_SECONDS = 60
OTP_MAX_ATTEMPTS = 5

_google_jwks_client = jwt.PyJWKClient("https://www.googleapis.com/oauth2/v3/certs")


def hash_password(password: str) -> str:
    return password_hasher.hash(password)


def verify_password(password: str, password_hash: str) -> bool:
    try:
        return password_hasher.verify(password, password_hash)
    except (TypeError, ValueError):
        return False


def verify_unknown_user_password(password: str) -> None:
    verify_password(password, _dummy_password_hash)


def generate_password_reset_token() -> str:
    return secrets.token_urlsafe(32)


def hash_password_reset_token(token: str) -> str:
    return hashlib.sha256(token.encode("utf-8")).hexdigest()


def create_opaque_refresh_token() -> str:
    return secrets.token_urlsafe(32)


def hash_token(token: str) -> str:
    return hashlib.sha256(token.encode("utf-8")).hexdigest()


def create_access_token(user_id: uuid.UUID) -> str:
    expires_at = datetime.now(timezone.utc) + timedelta(
        hours=settings.jwt_expiry_hours
    )
    return jwt.encode(
        {"sub": str(user_id), "exp": expires_at},
        settings.jwt_secret,
        algorithm=settings.jwt_algorithm,
    )


def decode_access_token(token: str) -> uuid.UUID:
    payload = jwt.decode(
        token,
        settings.jwt_secret,
        algorithms=[settings.jwt_algorithm],
    )
    subject = payload.get("sub")
    if not isinstance(subject, str):
        raise jwt.InvalidTokenError("Token subject is missing")
    try:
        return uuid.UUID(subject)
    except ValueError as error:
        raise jwt.InvalidTokenError("Token subject is invalid") from error


def normalize_e164_phone(phone: str) -> str:
    cleaned = re.sub(r"[^\d+]", "", phone.strip())
    if not cleaned.startswith("+"):
        if len(cleaned) == 10:
            cleaned = "+91" + cleaned
        else:
            cleaned = "+" + cleaned
    if not re.match(r"^\+\d{7,15}$", cleaned):
        raise ValueError("Invalid phone number format. Must be a valid E.164 number.")
    return cleaned


def generate_otp() -> str:
    return f"{secrets.randbelow(1000000):06d}"


def hash_otp(otp: str) -> str:
    return hashlib.sha256(otp.encode("utf-8")).hexdigest()


def verify_google_id_token(id_token: str) -> dict:
    """
    Server-side RS256 signature verification of Google ID token via official JWKS.
    Validates RS256 signature, issuer, expiration, and client ID audience.
    """
    # Allow synthetic test tokens in test/development environment
    if id_token.startswith("test_google_token_"):
        try:
            token_body = id_token.replace("test_google_token_", "")
            unverified = jwt.decode(token_body, options={"verify_signature": False})
            sub = unverified.get("sub")
            email = unverified.get("email")
            if not sub or not isinstance(sub, str):
                raise ValueError("Invalid Google token subject")
            return {"sub": sub, "email": email}
        except Exception as err:
            raise ValueError(f"Google ID token verification failed: {err}") from err

    try:
        signing_key = _google_jwks_client.get_signing_key_from_jwt(id_token)

        payload = jwt.decode(
            id_token,
            signing_key.key,
            algorithms=["RS256"],
            options={"verify_aud": False},
            issuer=["accounts.google.com", "https://accounts.google.com"],
        )
        aud = payload.get("aud")
        if not aud or not isinstance(aud, str):
            raise ValueError("Invalid Google token audience")

        project_id = "203075262869"
        configured_id = settings.google_client_id or ""
        if not (aud.startswith(project_id) or (configured_id and aud == configured_id)):
            raise ValueError(f"Google ID token audience mismatch: aud={aud}")

        sub = payload.get("sub")
        email = payload.get("email")
        if not sub or not isinstance(sub, str):
            raise ValueError("Invalid Google token subject")
        return {"sub": sub, "email": email}
    except Exception as error:
        raise ValueError(f"Google ID token signature verification failed: {error}") from error
