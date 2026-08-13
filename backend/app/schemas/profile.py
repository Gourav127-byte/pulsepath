import uuid

from typing import Annotated

from pydantic import (
    BaseModel,
    ConfigDict,
    StrictBool,
    StringConstraints,
    field_validator,
)


TrimmedDisplayName = Annotated[
    str,
    StringConstraints(strip_whitespace=True, min_length=1, max_length=40),
]
TrimmedSubtitle = Annotated[
    str,
    StringConstraints(strip_whitespace=True, max_length=80),
]


class ProfileUpdate(BaseModel):
    model_config = ConfigDict(extra="forbid")

    display_name: TrimmedDisplayName | None = None
    subtitle: TrimmedSubtitle | None = None
    dark_theme: StrictBool | None = None
    reduce_motion: StrictBool | None = None
    haptic_feedback: StrictBool | None = None
    use_metric_units: StrictBool | None = None

    @field_validator("display_name")
    @classmethod
    def display_name_cannot_be_null(cls, value: str | None) -> str:
        if value is None:
            raise ValueError("display_name cannot be null")
        return value

    @field_validator("subtitle")
    @classmethod
    def normalize_null_subtitle(cls, value: str | None) -> str:
        return "" if value is None else value


class ProfileResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    display_name: str
    subtitle: str
    dark_theme: bool
    reduce_motion: bool
    haptic_feedback: bool
    use_metric_units: bool
