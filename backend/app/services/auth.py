import uuid
import hashlib
import secrets
from datetime import datetime, timedelta, timezone

import jwt
from pwdlib import PasswordHash

from app.core.config import settings

password_hasher = PasswordHash.recommended()
_dummy_password_hash = password_hasher.hash("pulsepath-dummy-password")
PASSWORD_RESET_EXPIRY_MINUTES = 30


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
