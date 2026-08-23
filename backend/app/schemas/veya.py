from datetime import date as Date
from typing import Literal

from pydantic import BaseModel, ConfigDict, Field

from app.schemas.activity import (
    ActivityEngagementResponse,
    ActivityInsightsResponse,
)


RecordingStatus = Literal["recorded", "legacy_unknown"]
MetricProvenance = Literal["system", "manual", "health_connect", "blended"]
IntegrityLevel = Literal["solid", "partial", "sparse"]
ObservationCategory = Literal[
    "consistency", "trend", "goal_progress", "routine_recovery"
]


class VeyaActivityFact(BaseModel):
    model_config = ConfigDict(extra="forbid", frozen=True)

    date: Date
    steps: float
    active_minutes: float
    distance: float
    active_calories: float
    daily_score: float
    score_version: str
    source: str
    recording_status: RecordingStatus
    steps_provenance: MetricProvenance
    distance_provenance: MetricProvenance
    active_calories_provenance: MetricProvenance
    active_minutes_provenance: Literal["system", "manual"]


class VeyaIntegrityLens(BaseModel):
    model_config = ConfigDict(extra="forbid", frozen=True)

    level: IntegrityLevel
    confirmed_days: int = Field(ge=0)
    legacy_days: int = Field(ge=0)
    missing_days: int = Field(ge=0)
    confirmed_coverage: float = Field(ge=0, le=1)
    rationale: str


class VeyaEvidencePacket(BaseModel):
    model_config = ConfigDict(extra="forbid", frozen=True)

    schema_version: Literal["1.0"] = "1.0"
    range_days: Literal[7, 30]
    activities: tuple[VeyaActivityFact, ...]
    insights: ActivityInsightsResponse
    engagement: ActivityEngagementResponse
    integrity: VeyaIntegrityLens


class VeyaProviderRequest(BaseModel):
    model_config = ConfigDict(extra="forbid", frozen=True)

    evidence: VeyaEvidencePacket
    constraints: tuple[str, ...] = (
        "Use only facts present in the evidence packet.",
        "Treat missing days as missing, never as zero.",
        "Preserve recording status and metric provenance exactly.",
        "Do not make medical, diagnostic, or causal claims.",
    )


class VeyaEvidenceCitation(BaseModel):
    model_config = ConfigDict(extra="forbid", frozen=True)

    fact: str
    date: Date | None = None


class VeyaObservation(BaseModel):
    model_config = ConfigDict(extra="forbid", frozen=True)

    text: str
    confidence: Literal["high", "medium", "low"]
    category: ObservationCategory = "consistency"
    evidence: tuple[VeyaEvidenceCitation, ...]


class VeyaStructuredResponse(BaseModel):
    model_config = ConfigDict(extra="forbid", frozen=True)

    status: Literal["generated", "provider_unavailable"]
    summary: str
    observations: tuple[VeyaObservation, ...] = ()
    limitations: tuple[str, ...] = ()
    medical_or_causal_claims: Literal[False] = False


class VeyaFoundationResponse(BaseModel):
    model_config = ConfigDict(extra="forbid")

    evidence: VeyaEvidencePacket
    response: VeyaStructuredResponse
