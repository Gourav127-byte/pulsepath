from typing import Annotated

from fastapi import APIRouter, Depends, Query
from sqlalchemy.orm import Session

from app.api.activity import (
    get_activity_engagement,
    get_activity_history,
    get_activity_insights,
)
from app.api.dependencies import get_current_user
from app.db.database import get_db
from app.db.models.user import User
from app.schemas.veya import VeyaFoundationResponse, VeyaProviderRequest
from app.services.veya_evidence import build_evidence_packet
from app.services.veya_provider import (
    VeyaProvider,
    generate_veya_response,
    get_veya_provider,
)


router = APIRouter(prefix="/veya", tags=["veya"])


@router.get("/foundation", response_model=VeyaFoundationResponse)
async def get_veya_foundation(
    db: Annotated[Session, Depends(get_db)],
    user: Annotated[User, Depends(get_current_user)],
    provider: Annotated[VeyaProvider, Depends(get_veya_provider)],
    days: Annotated[int, Query()] = 7,
) -> VeyaFoundationResponse:
    # These existing authenticated handlers remain the authoritative fact source.
    history = get_activity_history(db=db, user=user, days=days)
    insights = get_activity_insights(db=db, user=user, days=days)
    engagement = get_activity_engagement(db=db, user=user)
    evidence = build_evidence_packet(
        days=days,
        history=history,
        insights=insights,
        engagement=engagement,
    )
    response = await generate_veya_response(
        provider,
        VeyaProviderRequest(evidence=evidence),
    )
    return VeyaFoundationResponse(evidence=evidence, response=response)
