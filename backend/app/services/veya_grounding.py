import re
from datetime import date as Date

from app.schemas.veya import (
    VeyaEvidencePacket,
    VeyaObservation,
    VeyaStructuredResponse,
)


class VeyaGroundingError(ValueError):
    """Raised when provider response violates evidence grounding constraints."""


ALLOWED_FACT_NAMES = {
    "steps",
    "active_minutes",
    "distance",
    "active_calories",
    "daily_score",
    "score_version",
    "source",
    "recording_status",
    "steps_provenance",
    "distance_provenance",
    "active_calories_provenance",
    "active_minutes_provenance",
    "trend",
    "consistency_days",
    "current_streak",
    "best_streak",
    "achievements",
    "confirmed_days",
    "legacy_days",
    "missing_days",
}

DAILY_METRIC_FACTS = {
    "steps",
    "active_minutes",
    "distance",
    "active_calories",
    "daily_score",
    "source",
    "recording_status",
    "steps_provenance",
    "distance_provenance",
    "active_calories_provenance",
    "active_minutes_provenance",
}

MEDICAL_CAUSAL_PATTERNS = (
    r"\bdiagnos",
    r"\btreat",
    r"\bcure\b",
    r"\bprescr",
    r"\bdisease",
    r"\billness",
    r"\bpatient",
    r"\bmedical\b",
    r"\bcaused your\b",
    r"\bcaused you\b",
    r"\bthis caused\b",
    r"\bcaused a\b",
    r"\bprevented your\b",
)


def _cap_confidence(current: str, max_allowed: str) -> str:
    levels = {"low": 1, "medium": 2, "high": 3}
    rev_levels = {1: "low", 2: "medium", 3: "high"}
    current_val = levels.get(current, 1)
    max_val = levels.get(max_allowed, 1)
    final_val = min(current_val, max_val)
    return rev_levels[final_val]


def _check_text_guardrails(text: str) -> None:
    lower_text = text.lower()

    # Medical & Causal claims check
    for pattern in MEDICAL_CAUSAL_PATTERNS:
        if re.search(pattern, lower_text):
            raise VeyaGroundingError(
                f"Forbidden medical or causal claim detected in text: '{pattern}'"
            )

    # Active Minutes Health Connect guardrail
    if ("active minutes" in lower_text or "active_minutes" in lower_text) and (
        "health connect" in lower_text or "health_connect" in lower_text
    ):
        raise VeyaGroundingError(
            "Active Minutes cannot be described as Health Connect-derived"
        )

    # Missing / unrecorded days as zero recorded activity guardrail
    if ("missing" in lower_text or "unrecorded" in lower_text or "absent" in lower_text) and (
        "zero" in lower_text or "0 steps" in lower_text or "0 active" in lower_text or "no activity" in lower_text
    ):
        raise VeyaGroundingError(
            "Missing days cannot be described as zero recorded activity"
        )

    # Legacy records as confirmed activity guardrail
    if "legacy" in lower_text and (
        "confirmed" in lower_text or "verified" in lower_text or "authoritative" in lower_text
    ):
        raise VeyaGroundingError(
            "Legacy records cannot be described as confirmed activity"
        )


def validate_and_ground_veya_response(
    response: VeyaStructuredResponse,
    evidence: VeyaEvidencePacket,
) -> VeyaStructuredResponse:
    """Deterministically ground and validate AI observations against verified evidence."""
    if response.status == "provider_unavailable":
        return response

    if response.medical_or_causal_claims:
        raise VeyaGroundingError("Medical or causal claims flag must be false")

    # Validate Summary text
    if not response.summary or not response.summary.strip():
        raise VeyaGroundingError("Response summary cannot be empty")
    _check_text_guardrails(response.summary)

    activities_by_date = {act.date: act for act in evidence.activities}
    valid_dates: set[Date] = set(activities_by_date.keys())
    legacy_dates: set[Date] = {
        act.date for act in evidence.activities if act.recording_status == "legacy_unknown"
    }

    # Determine max allowed confidence from integrity lens
    integrity_level = evidence.integrity.level
    if integrity_level == "solid":
        base_max_confidence = "high"
    elif integrity_level == "partial":
        base_max_confidence = "medium"
    else:
        base_max_confidence = "low"

    grounded_observations: list[VeyaObservation] = []

    for obs in response.observations:
        if not obs.text or not obs.text.strip():
            raise VeyaGroundingError("Observation text cannot be empty")

        if not obs.evidence:
            raise VeyaGroundingError(
                f"Observation '{obs.text}' lacks mandatory evidence citations"
            )

        _check_text_guardrails(obs.text)
        lower_obs_text = obs.text.lower()

        # Trend Entailment Guardrail
        if "improving trend" in lower_obs_text or "trend is improving" in lower_obs_text:
            if evidence.insights.trend != "improving":
                raise VeyaGroundingError(
                    f"Observation claims improving trend, but evidence trend is '{evidence.insights.trend}'"
                )
        if "declining trend" in lower_obs_text or "trend is declining" in lower_obs_text:
            if evidence.insights.trend != "declining":
                raise VeyaGroundingError(
                    f"Observation claims declining trend, but evidence trend is '{evidence.insights.trend}'"
                )

        obs_max_confidence = base_max_confidence

        for citation in obs.evidence:
            fact_name = citation.fact.lower().strip()
            if fact_name not in ALLOWED_FACT_NAMES:
                raise VeyaGroundingError(
                    f"Observation cites unsupported or hallucinated fact: '{citation.fact}'"
                )

            # Daily metric facts must be anchored with a date
            if fact_name in DAILY_METRIC_FACTS and citation.date is None:
                raise VeyaGroundingError(
                    f"Daily activity metric fact '{citation.fact}' must cite a specific date"
                )

            if citation.date is not None:
                if citation.date not in valid_dates:
                    raise VeyaGroundingError(
                        f"Observation cites hallucinated or out-of-range date: {citation.date}"
                    )
                if citation.date in legacy_dates:
                    obs_max_confidence = "low"

                # Verify numeric value entailment for daily step facts
                if fact_name == "steps":
                    fact_obj = activities_by_date[citation.date]
                    actual_steps = int(fact_obj.steps)
                    # Extract numbers mentioned in text
                    numbers_in_text = [
                        int(num.replace(",", ""))
                        for num in re.findall(r"\b\d{1,3}(?:,\d{3})*|\b\d+\b", obs.text)
                    ]
                    # If large step numbers are mentioned (>500), ensure at least one matches actual_steps or packet totals
                    large_numbers = [n for n in numbers_in_text if n >= 500]
                    if large_numbers:
                        valid_step_numbers = {
                            actual_steps,
                            int(evidence.insights.total_steps),
                            int(evidence.insights.average_steps),
                        }
                        if not any(num in valid_step_numbers for num in large_numbers):
                            raise VeyaGroundingError(
                                f"Observation text contains ungrounded step count value {large_numbers} for date {citation.date}"
                            )

        # Deterministically apply confidence capping based on Integrity Lens
        final_confidence = _cap_confidence(obs.confidence, obs_max_confidence)

        grounded_observations.append(
            VeyaObservation(
                text=obs.text,
                confidence=final_confidence,  # type: ignore[arg-type]
                category=obs.category,
                evidence=obs.evidence,
            )
        )

    limitations_list = list(response.limitations)
    if integrity_level == "sparse":
        sparse_warning = (
            "Evidence is sparse with fewer than 2 confirmed recorded days; observations are low confidence."
        )
        if not any("sparse" in lim.lower() for lim in limitations_list):
            limitations_list.append(sparse_warning)

    return VeyaStructuredResponse(
        status="generated",
        summary=response.summary,
        observations=tuple(grounded_observations),
        limitations=tuple(limitations_list),
        medical_or_causal_claims=False,
    )
