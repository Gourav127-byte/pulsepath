import uuid
from typing import Annotated, Literal

from pydantic import BaseModel, ConfigDict, Field


GoalType = Literal["steps", "distance", "active_minutes", "calories"]
PositiveTarget = Annotated[float, Field(strict=True, gt=0, allow_inf_nan=False)]


class GoalCreate(BaseModel):
    model_config = ConfigDict(extra="forbid")

    type: GoalType
    target_value: PositiveTarget


class GoalUpdate(BaseModel):
    model_config = ConfigDict(extra="forbid")

    target_value: PositiveTarget


class GoalResponse(BaseModel):
    id: uuid.UUID
    type: str
    target_value: float
    current_value: float
    progress: float
    is_completed: bool
