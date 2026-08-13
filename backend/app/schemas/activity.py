from datetime import date

from typing import Annotated

from pydantic import BaseModel, ConfigDict, Field, field_validator


ActivityMetric = Annotated[float, Field(strict=True, ge=0, allow_inf_nan=False)]


class ActivityUpdate(BaseModel):
    model_config = ConfigDict(extra="forbid")

    steps: ActivityMetric | None = None
    active_minutes: ActivityMetric | None = None
    calories: ActivityMetric | None = None
    distance: ActivityMetric | None = None

    @field_validator("steps", "active_minutes", "calories", "distance")
    @classmethod
    def supplied_metrics_cannot_be_null(cls, value: float | None) -> float:
        if value is None:
            raise ValueError("activity metrics cannot be null")
        return value


class ActivityResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    date: date
    steps: float
    active_minutes: float
    distance: float
    calories: float
    daily_score: float
    score_version: str
    source: str
