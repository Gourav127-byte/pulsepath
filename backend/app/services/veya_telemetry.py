import hashlib
import logging
import time
from uuid import UUID

logger = logging.getLogger("veya.telemetry")
logger.setLevel(logging.INFO)
logger.propagate = True


def _hash_user_id(user_id: UUID) -> str:
    """Anonymize user ID for privacy-compliant operational logging."""
    return hashlib.sha256(str(user_id).encode("utf-8")).hexdigest()[:12]


def log_provider_call(
    *,
    provider_name: str,
    model_name: str,
    duration_ms: float,
    status: str,
    error_type: str | None = None,
) -> None:
    """Log high-level operational provider metrics with ZERO PII or secrets."""
    err_str = f" error_type={error_type}" if error_type else ""
    logger.info(
        f"VEYA_PROVIDER_CALL provider={provider_name} model={model_name} "
        f"duration_ms={duration_ms:.2f} status={status}{err_str}"
    )


def log_grounding_result(
    *,
    duration_ms: float,
    status: str,
    error_type: str | None = None,
) -> None:
    """Log grounding validation outcomes with ZERO payload text or prompt data."""
    err_str = f" error_type={error_type}" if error_type else ""
    logger.info(
        f"VEYA_GROUNDING duration_ms={duration_ms:.2f} status={status}{err_str}"
    )


def log_rate_limit_rejection(user_id: UUID) -> None:
    """Log rate limit enforcement with anonymized user identifier."""
    anon_id = _hash_user_id(user_id)
    logger.warning(f"VEYA_RATE_LIMIT_EXCEEDED user_hash={anon_id}")
