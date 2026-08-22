from datetime import date, timedelta
from typing import Annotated

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy import select
from sqlalchemy.exc import SQLAlchemyError
from sqlalchemy.orm import Session

from app.api.dependencies import get_current_user
from app.db.database import get_db
from app.db.models.activity import Activity
from app.db.models.goal import Goal
from app.db.models.user import User
from app.schemas.activity import (
    ActivityAchievementResponse,
    ActivityEngagementResponse,
    ActivityHistoryResponse,
    ActivityInsightsResponse,
    ActivityResponse,
    ActivityStreakResponse,
    ActivityUpdate,
    DailyScoreExplanationResponse,
)
from app.services.activity_insights import build_activity_insights
from app.services.activity_streak import (
    build_activity_achievements,
    calculate_best_streak,
    calculate_current_streak,
)
from app.services.daily_score import (
    SCORE_VERSION as V1_SCORE_VERSION,
    calculate_daily_score,
    explain_daily_score,
)
from app.services.daily_score_v2 import (
    SCORE_VERSION,
    calculate_daily_score_v2,
    explain_daily_score_v2,
)

router = APIRouter(prefix="/activity", tags=["activity"])


@router.get("/streak", response_model=ActivityStreakResponse)
def get_activity_streak(
    db: Annotated[Session, Depends(get_db)],
    user: Annotated[User, Depends(get_current_user)],
) -> dict[str, object]:
    today = date.today()
    activities = list(
        db.scalars(
            select(Activity)
            .where(
                Activity.user_id == user.id,
                Activity.date <= today,
            )
            .order_by(Activity.date.desc())
        ).all()
    )
    current_streak, today_pending = calculate_current_streak(
        activities,
        today=today,
    )
    return {
        "current_streak": current_streak,
        "today_pending": today_pending,
    }


@router.get("/engagement", response_model=ActivityEngagementResponse)
def get_activity_engagement(
    db: Annotated[Session, Depends(get_db)],
    user: Annotated[User, Depends(get_current_user)],
) -> dict[str, object]:
    today = date.today()
    activities = list(
        db.scalars(
            select(Activity)
            .where(
                Activity.user_id == user.id,
                Activity.date <= today,
            )
            .order_by(Activity.date.asc())
        ).all()
    )
    current_streak, today_pending = calculate_current_streak(activities, today=today)
    best_streak = calculate_best_streak(activities)
    achievements = build_activity_achievements(activities, today=today)
    return {
        "current_streak": current_streak,
        "best_streak": best_streak,
        "achievements": [
            {
                "id": item["id"],
                "title": item["title"],
                "description": item["description"],
                "unlocked": item["unlocked"],
                "progress": item["progress"],
                "unlock_date": item["unlock_date"],
            }
            for item in achievements
        ],
        "today_pending": today_pending,
    }


def _validated_days(days: int) -> int:
    if days not in (7, 30):
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_CONTENT,
            detail="days must be either 7 or 30",
        )
    return days


@router.get("/history", response_model=list[ActivityHistoryResponse])
def get_activity_history(
    db: Annotated[Session, Depends(get_db)],
    user: Annotated[User, Depends(get_current_user)],
    days: Annotated[int, Query()] = 7,
) -> list[Activity]:
    _validated_days(days)

    # PulsePath currently uses the backend's local calendar date consistently.
    # Per-user timezones require a future explicit product/schema decision.
    end_date = date.today()
    start_date = end_date - timedelta(days=days - 1)
    return list(
        db.scalars(
            select(Activity)
            .where(
                Activity.user_id == user.id,
                Activity.date >= start_date,
                Activity.date <= end_date,
                Activity.recording_status != "unrecorded",
            )
            .order_by(Activity.date.asc())
        ).all()
    )


@router.get("/insights", response_model=ActivityInsightsResponse)
def get_activity_insights(
    db: Annotated[Session, Depends(get_db)],
    user: Annotated[User, Depends(get_current_user)],
    days: Annotated[int, Query()] = 7,
) -> dict[str, object]:
    _validated_days(days)
    end_date = date.today()
    current_start = end_date - timedelta(days=days - 1)
    previous_start = current_start - timedelta(days=days)
    records = list(
        db.scalars(
            select(Activity)
            .where(
                Activity.user_id == user.id,
                Activity.date >= previous_start,
                Activity.date <= end_date,
                Activity.recording_status != "unrecorded",
            )
            .order_by(Activity.date.asc())
        ).all()
    )
    current_all = [record for record in records if record.date >= current_start]
    previous_all = [record for record in records if record.date < current_start]

    # Only explicitly recorded rows drive comparisons. Legacy rows remain visible
    # in history, but are not silently relabelled as confirmed recorded days.
    current = [
        record for record in current_all if record.recording_status == "recorded"
    ]
    previous = [
        record for record in previous_all if record.recording_status == "recorded"
    ]
    insights = build_activity_insights(
        current,
        previous,
        current_legacy_days=sum(
            record.recording_status == "legacy_unknown" for record in current_all
        ),
        previous_legacy_days=sum(
            record.recording_status == "legacy_unknown" for record in previous_all
        ),
    )
    strongest_steps = insights.pop("strongest_steps_day")
    strongest_score = insights.pop("strongest_score_day")

    def strongest_payload(record: object) -> dict[str, object] | None:
        if not isinstance(record, Activity):
            return None
        return {
            "date": record.date,
            "daily_score": record.daily_score,
            "steps": record.steps,
        }

    return {
        "days": days,
        **insights,
        "strongest_steps_day": strongest_payload(strongest_steps),
        "strongest_score_day": strongest_payload(strongest_score),
    }


@router.get(
    "/today/score-explanation",
    response_model=DailyScoreExplanationResponse,
)
def get_today_score_explanation(
    db: Annotated[Session, Depends(get_db)],
    user: Annotated[User, Depends(get_current_user)],
) -> dict[str, object]:
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
    if activity.recording_status == "unrecorded":
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="No activity has been recorded today",
        )

    if activity.score_version == V1_SCORE_VERSION:
        components = explain_daily_score(
            steps=activity.steps,
            active_minutes=activity.active_minutes,
            calories=activity.calories,
        )
        calculated = calculate_daily_score(
            steps=activity.steps,
            active_minutes=activity.active_minutes,
            calories=activity.calories,
        )
    elif activity.score_version == SCORE_VERSION:
        goals = db.scalars(
            select(Goal).where(
                Goal.user_id == user.id,
                Goal.type.in_(("steps", "active_minutes", "calories")),
            )
        ).all()
        targets = {goal.type: goal.target_value for goal in goals}
        components = explain_daily_score_v2(
            steps=activity.steps,
            active_minutes=activity.active_minutes,
            calories=activity.calories,
            goal_targets=targets,
        )
        calculated = calculate_daily_score_v2(
            steps=activity.steps,
            active_minutes=activity.active_minutes,
            calories=activity.calories,
            goal_targets=targets,
        )
    else:
        return {
            "score": activity.daily_score,
            "score_version": activity.score_version,
            "available": False,
            "message": "This score version cannot be explained yet.",
            "components": [],
        }

    available = calculated == activity.daily_score
    return {
        "score": activity.daily_score,
        "score_version": activity.score_version,
        "available": available,
        "message": (
            None
            if available
            else "This score used earlier goal settings, so its exact breakdown is unavailable."
        ),
        "components": components if available else [],
    }


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
            recording_status="unrecorded",
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
    try:
        if activity is None:
            activity = Activity(
                user_id=user.id,
                date=date.today(),
                steps=0,
                active_minutes=0,
                calories=0,
                distance=0,
                daily_score=0,
                score_version=SCORE_VERSION,
                source="system",
                recording_status="unrecorded",
            )
            db.add(activity)
        update_data = update.model_dump(exclude_unset=True)
        source = update_data.pop("source", "manual")
        
        # Apply the update to the specific source columns
        has_metric_updates = bool(update_data)
        for field, value in update_data.items():
            setattr(activity, f"{field}_{source}", value)
            
        # Recompute the main columns as max of manual and health_connect,
        # falling back to legacy values if both source columns are still None
        def compute_metric(manual: float | None, hc: float | None, legacy: float) -> float:
            if manual is None and hc is None:
                return legacy
            return max(manual or 0, hc or 0)

        activity.steps = compute_metric(activity.steps_manual, activity.steps_health_connect, activity.steps)
        activity.active_minutes = compute_metric(activity.active_minutes_manual, activity.active_minutes_health_connect, activity.active_minutes)
        activity.calories = compute_metric(activity.calories_manual, activity.calories_health_connect, activity.calories)
        activity.distance = compute_metric(activity.distance_manual, activity.distance_health_connect, activity.distance)
        
        # Only transition to "recorded" and update source if actual metrics
        # were supplied.  An empty recompute-only PATCH preserves the
        # existing recording_status and source attribution.
        if has_metric_updates:
            activity.recording_status = "recorded"
            activity.source = source

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
