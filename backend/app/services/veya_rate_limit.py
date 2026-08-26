import time
from collections import defaultdict
from uuid import UUID

from fastapi import HTTPException, status

from app.core.config import settings


class VeyaRateLimiter:
    def __init__(self) -> None:
        self._history: dict[UUID, list[float]] = defaultdict(list)

    def check_and_record(self, user_id: UUID) -> None:
        limit = settings.veya_rate_limit_per_minute
        if limit <= 0:
            return

        now = time.time()
        window_start = now - 60.0

        # Prune timestamps older than 60 seconds
        user_timestamps = [t for t in self._history[user_id] if t > window_start]
        self._history[user_id] = user_timestamps

        if len(user_timestamps) >= limit:
            raise HTTPException(
                status_code=status.HTTP_429_TOO_MANY_REQUESTS,
                detail=f"VEYA rate limit exceeded. Maximum {limit} requests per minute allowed.",
            )

        user_timestamps.append(now)

    def reset_for_user(self, user_id: UUID) -> None:
        self._history.pop(user_id, None)

    def reset_all(self) -> None:
        self._history.clear()


veya_rate_limiter = VeyaRateLimiter()
