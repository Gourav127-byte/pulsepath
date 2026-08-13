from datetime import date
from typing import Annotated

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import select
from sqlalchemy.exc import SQLAlchemyError
from sqlalchemy.orm import Session

from app.api.dependencies import get_current_user
from app.db.database import get_db
from app.db.models.activity import Activity
from app.db.models.goal import Goal
from app.db.models.user import User
from app.schemas.activity import ActivityResponse, ActivityUpdate
from app.services.daily_score_v2 import SCORE_VERSION, calculate_daily_score_v2

router = APIRouter(prefix="/activity", tags=["activity"])


@router.get("/today", response_model=ActivityResponse)
def get_today_activity(
    db: Annotated[Session, Depends(get_db)],
    user: Annotated[User, Depends(get_current_user)],
) -> Activity:
    today = date.today()
    activity = db.scalar(
        select(Activity).where(
            Activity.user_id == user.id,
            Activity.date == today,
        )
    )

    if activity is None:
        # Lazily initialize today's activity for the user
        activity = Activity(
            user_id=user.id,
            date=today,
            steps=0,
            active_minutes=0,
            calories=0,
            distance=0,
            daily_score=0,
            score_version=SCORE_VERSION,
            source="system",
        )
        db.add(activity)
        try:
            db.commit()
            db.refresh(activity)
        except SQLAlchemyError as error:
            db.rollback()
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail="Could not initialize today's activity",
            ) from error

    return activity


@router.patch("/today", response_model=ActivityResponse)
def update_today_activity(
    update: ActivityUpdate,
    db: Annotated[Session, Depends(get_db)],
    user: Annotated[User, Depends(get_current_user)],
) -> Activity:
    activity = db.scalar(
        select(Activity).where(
            Activity.user_id == user.id,
            Activity.date == date.today(),
        )
    )
    if activity is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Today's activity was not found",
        )

    try:
        for field, value in update.model_dump(exclude_unset=True).items():
            setattr(activity, field, value)

        goals = db.scalars(
            select(Goal).where(
                Goal.user_id == user.id,
                Goal.type.in_(("steps", "active_minutes", "calories")),
            )
        ).all()
        goal_targets = {goal.type: goal.target_value for goal in goals}
        activity.daily_score = calculate_daily_score_v2(
            steps=activity.steps,
            active_minutes=activity.active_minutes,
            calories=activity.calories,
            goal_targets=goal_targets,
        )
        activity.score_version = SCORE_VERSION

        db.commit()
        db.refresh(activity)
    except SQLAlchemyError as error:
        db.rollback()
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Could not update today's activity",
        ) from error
    except Exception as error:
        db.rollback()
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Could not update today's activity",
        ) from error

    return activity
