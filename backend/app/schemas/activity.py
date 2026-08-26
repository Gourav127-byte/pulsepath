from datetime import date, datetime
from typing import Annotated

from pydantic import BaseModel, ConfigDict, Field, field_validator


ActivityMetric = Annotated[float, Field(strict=True, ge=0, allow_inf_nan=False)]


class ActivityUpdate(BaseModel):
    """Partial activity update.

    ``active_minutes`` accepts only a direct manual value or the total duration
    of recorded Health Connect workout/exercise sessions. Passive movement and
    steps/cadence/calorie heuristics are not valid Active Minutes sources.
    """

    model_config = ConfigDict(extra="forbid")

    steps: ActivityMetric | None = None
    active_minutes: ActivityMetric | None = None
    calories: ActivityMetric | None = None
    distance: ActivityMetric | None = None
    source: str = "manual"
    reset_steps_to_auto: bool | None = None
    reset_distance_to_auto: bool | None = None
    reset_calories_to_auto: bool | None = None

    @field_validator("steps", "active_minutes", "calories", "distance")
    @classmethod
    def supplied_metrics_cannot_be_null(cls, value: float | None) -> float | None:
        if value is None:
            raise ValueError("activity metrics cannot be null")
        return value

    @field_validator("source")
    @classmethod
    def validate_source(cls, value: str) -> str:
        allowed = {"manual", "health_connect"}
        if value not in allowed:
            raise ValueError(f"source must be one of {allowed}")
        return value


class ActivityResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    date: date
    steps: float | None = None
    active_minutes: float | None = None
    distance: float | None = None
    calories: float | None = None
    daily_score: float | None = None
    score_version: str
    source: str
    recording_status: str
    steps_provenance: str = "system"
    distance_provenance: str = "system"
    calories_provenance: str = "system"
    active_minutes_provenance: str = "system"


class ActivityHistoryResponse(ActivityResponse):
    """A recorded day; absent dates are intentionally omitted."""


class ActivityStreakResponse(BaseModel):
    current_streak: int
    today_pending: bool


class ActivityAchievementResponse(BaseModel):
    id: str
    title: str
    description: str
    unlocked: bool
    progress: float
    unlock_date: date | None = None


class ActivityEngagementResponse(BaseModel):
    current_streak: int
    best_streak: int
    today_pending: bool
    achievements: list[ActivityAchievementResponse]


class ScoreComponentResponse(BaseModel):
    metric: str
    value: float | None = None
    target: float | None = None
    progress: float | None = None
    weight: float
    points: float | None = None
    status: str = "recorded"


class DailyScoreExplanationResponse(BaseModel):
    score: float | None = None
    score_version: str
    available: bool
    message: str | None = None
    components: list[ScoreComponentResponse]


class StrongestDayResponse(BaseModel):
    date: date
    daily_score: float | None = None
    steps: float | None = None


class ActivityInsightsResponse(BaseModel):
    days: int
    current_recorded_days: int
    previous_recorded_days: int
    current_legacy_days: int
    previous_legacy_days: int
    total_steps: float
    average_steps: float | None
    total_distance: float
    total_active_calories: float
    average_score: float | None
    steps_change_percent: float | None
    distance_change_percent: float | None
    active_calories_change_percent: float | None
    average_score_change: float | None
    trend: str
    consistency_days: int
    strongest_steps_day: StrongestDayResponse | None
    strongest_score_day: StrongestDayResponse | None


class StepSampleDTO(BaseModel):
    sample_id: str | None = None
    start_time: datetime
    end_time: datetime
    steps: int = Field(ge=0)
    source_origin: str = "health_connect"


class ActivityTimelineSyncRequest(BaseModel):
    date: date
    samples: list[StepSampleDTO]


class ActivityTimelineResponse(BaseModel):
    date: date
    total_steps: int
    samples_count: int
    timeline: list[StepSampleDTO]
