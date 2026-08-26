"""VEYA AI Usage & Cost Accounting Service (In-Memory).

Note: This in-memory implementation provides single-instance daily quota enforcement
and usage accounting without external database overhead or storing PII/secrets.
For multi-instance/distributed deployments, replace or back this with a Redis/database store.
"""

from dataclasses import dataclass, field
from datetime import date
from uuid import UUID

from fastapi import HTTPException, status

from app.core.config import settings


@dataclass
class DailyUserUsage:
    date: date
    count: int = 0


@dataclass
class UsageMetrics:
    total_calls: int = 0
    successful_calls: int = 0
    failed_calls: int = 0
    timeout_calls: int = 0
    total_duration_ms: float = 0.0
    total_prompt_tokens: int = 0
    total_completion_tokens: int = 0


class VeyaUsageTracker:
    def __init__(self) -> None:
        self._metrics = UsageMetrics()
        self._user_daily: dict[UUID, DailyUserUsage] = {}

    def check_daily_quota(self, user_id: UUID) -> None:
        quota = settings.veya_daily_quota_per_user
        if quota <= 0:
            return

        today = date.today()
        user_usage = self._user_daily.get(user_id)

        if user_usage is None or user_usage.date != today:
            user_usage = DailyUserUsage(date=today, count=0)
            self._user_daily[user_id] = user_usage

        if user_usage.count >= quota:
            raise HTTPException(
                status_code=status.HTTP_429_TOO_MANY_REQUESTS,
                detail=f"Daily VEYA request quota ({quota}) reached for today. Please try again tomorrow.",
            )

    def record_usage(
        self,
        *,
        user_id: UUID | None = None,
        success: bool,
        is_timeout: bool = False,
        duration_ms: float,
        prompt_tokens: int = 0,
        completion_tokens: int = 0,
    ) -> None:
        self._metrics.total_calls += 1
        self._metrics.total_duration_ms += max(duration_ms, 0.0)
        self._metrics.total_prompt_tokens += max(prompt_tokens, 0)
        self._metrics.total_completion_tokens += max(completion_tokens, 0)

        if success:
            self._metrics.successful_calls += 1
        else:
            self._metrics.failed_calls += 1
            if is_timeout:
                self._metrics.timeout_calls += 1

        if user_id is not None:
            today = date.today()
            user_usage = self._user_daily.get(user_id)
            if user_usage is None or user_usage.date != today:
                user_usage = DailyUserUsage(date=today, count=0)
                self._user_daily[user_id] = user_usage
            user_usage.count += 1

    def get_summary(self) -> dict[str, object]:
        return {
            "total_calls": self._metrics.total_calls,
            "successful_calls": self._metrics.successful_calls,
            "failed_calls": self._metrics.failed_calls,
            "timeout_calls": self._metrics.timeout_calls,
            "total_duration_ms": round(self._metrics.total_duration_ms, 2),
            "total_prompt_tokens": self._metrics.total_prompt_tokens,
            "total_completion_tokens": self._metrics.total_completion_tokens,
            "active_users_today": len(self._user_daily),
        }

    def get_user_daily_count(self, user_id: UUID) -> int:
        today = date.today()
        user_usage = self._user_daily.get(user_id)
        if user_usage and user_usage.date == today:
            return user_usage.count
        return 0

    def reset_all(self) -> None:
        self._metrics = UsageMetrics()
        self._user_daily.clear()


veya_usage_tracker = VeyaUsageTracker()
