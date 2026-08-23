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
                steps_downward_offset=0.0,
                distance_downward_offset=0.0,
                calories_downward_offset=0.0,
                steps_provenance="system",
                distance_provenance="system",
                calories_provenance="system",
            )
            db.add(activity)
        update_data = update.model_dump(exclude_unset=True)
        source = update_data.pop("source", "manual")
        reset_steps_to_auto = update_data.pop("reset_steps_to_auto", False)
        reset_distance_to_auto = update_data.pop("reset_distance_to_auto", False)
        reset_calories_to_auto = update_data.pop("reset_calories_to_auto", False)

        def handle_reset(metric: str) -> bool:
            changed = any(
                (
                    getattr(activity, f"{metric}_manual") is not None,
                    bool(getattr(activity, f"{metric}_downward_offset")),
                    getattr(activity, f"{metric}_pending_reduction_value") is not None,
                    getattr(activity, f"{metric}_pending_reduction_at") is not None,
                )
            )
            setattr(activity, f"{metric}_manual", None)
            setattr(activity, f"{metric}_downward_offset", 0.0)
            setattr(activity, f"{metric}_pending_reduction_value", None)
            setattr(activity, f"{metric}_pending_reduction_at", None)
            return changed

        reset_changed = False
        if reset_steps_to_auto:
            reset_changed = handle_reset("steps") or reset_changed
        if reset_distance_to_auto:
            reset_changed = handle_reset("distance") or reset_changed
        if reset_calories_to_auto:
            reset_changed = handle_reset("calories") or reset_changed

        has_metric_updates = bool(update_data) or reset_changed

        from datetime import datetime, timezone
        
        for field, value in update_data.items():
            if source == "manual":
                if field == "active_minutes":
                    activity.active_minutes_manual = value
                    continue
                # manual edit clears pending reductions
                setattr(activity, f"{field}_pending_reduction_value", None)
                setattr(activity, f"{field}_pending_reduction_at", None)

                hc_val = getattr(activity, f"{field}_health_connect") or 0.0
                offset = max(value, hc_val) - value
                setattr(activity, f"{field}_manual", value)
                setattr(activity, f"{field}_downward_offset", offset)
            
            elif source == "health_connect":
                if field == "active_minutes":
                    activity.active_minutes_health_connect = value
                    continue

                hc_val = getattr(activity, f"{field}_health_connect")
                pending_val = getattr(activity, f"{field}_pending_reduction_value")

                p = value
                if p is None:
                    continue

                c = hc_val

                def apply_hc(p_val):
                    setattr(activity, f"{field}_health_connect", p_val)
                    setattr(activity, f"{field}_pending_reduction_value", None)
                    setattr(activity, f"{field}_pending_reduction_at", None)

                if (p is None and c is None) or (p is not None and c is not None and p >= c) or (p is not None and c is None):
                    apply_hc(p)
                else:
                    if pending_val is None:
                        setattr(activity, f"{field}_pending_reduction_value", p)
                        setattr(activity, f"{field}_pending_reduction_at", datetime.now(timezone.utc))
                    else:
                        if p == pending_val:
                            apply_hc(p)
                        else:
                            setattr(activity, f"{field}_pending_reduction_value", p)
                            setattr(activity, f"{field}_pending_reduction_at", datetime.now(timezone.utc))

        def compute_effective(metric: str) -> float:
            manual = getattr(activity, f"{metric}_manual")
            hc = getattr(activity, f"{metric}_health_connect")
            if metric == "active_minutes":
                if manual is None and hc is None:
                    return activity.active_minutes
                return max(manual or 0, hc or 0)

            offset = getattr(activity, f"{metric}_downward_offset") or 0.0
            if manual is None and hc is None:
                return getattr(activity, metric) or 0.0
            current_max = max(manual or 0, hc or 0)
            return max(manual or 0, current_max - offset)

        def compute_provenance(metric: str) -> str:
            if metric == "active_minutes":
                return "manual" if getattr(activity, "active_minutes_manual") is not None else "system"

            offset = getattr(activity, f"{metric}_downward_offset") or 0.0
            manual = getattr(activity, f"{metric}_manual")
            hc = getattr(activity, f"{metric}_health_connect")

            if offset > 0: return 'blended'
            if hc is not None and hc > (manual or 0): return 'health_connect'
            if manual is not None: return 'manual'
            return 'system'

        activity.steps = compute_effective("steps")
        activity.active_minutes = compute_effective("active_minutes")
        activity.calories = compute_effective("calories")
        activity.distance = compute_effective("distance")

        activity.steps_provenance = compute_provenance("steps")
        activity.calories_provenance = compute_provenance("calories")
        activity.distance_provenance = compute_provenance("distance")
        
        # Only transition to "recorded" and update source if actual metrics
        # were supplied.
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
