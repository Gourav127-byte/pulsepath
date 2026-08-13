from datetime import date
from typing import Annotated
import uuid

from fastapi import APIRouter, Depends, HTTPException, Response, status
from sqlalchemy import select
from sqlalchemy.exc import IntegrityError, SQLAlchemyError
from sqlalchemy.orm import Session

from app.api.dependencies import get_current_user
from app.db.database import get_db
from app.db.models.activity import Activity
from app.db.models.goal import Goal
from app.db.models.user import User
from app.schemas.goal import GoalCreate, GoalResponse, GoalUpdate
from app.services.goals import build_goal_response

router = APIRouter(prefix="/goals", tags=["goals"])


@router.get("", response_model=list[GoalResponse])
def get_goals(
    db: Annotated[Session, Depends(get_db)],
    user: Annotated[User, Depends(get_current_user)],
) -> list[GoalResponse]:
    goals = db.scalars(
        select(Goal)
        .where(Goal.user_id == user.id)
        .order_by(Goal.type)
    ).all()
    activity = db.scalar(
        select(Activity).where(
            Activity.user_id == user.id,
            Activity.date == date.today(),
        )
    )
    return [build_goal_response(goal, activity) for goal in goals]


@router.post("", response_model=GoalResponse, status_code=status.HTTP_201_CREATED)
def create_goal(
    create: GoalCreate,
    db: Annotated[Session, Depends(get_db)],
    user: Annotated[User, Depends(get_current_user)],
) -> GoalResponse:
    existing_goal = db.scalar(
        select(Goal).where(
            Goal.user_id == user.id,
            Goal.type == create.type,
        )
    )
    if existing_goal is not None:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="A goal of this type already exists",
        )

    goal = Goal(
        user_id=user.id,
        type=create.type,
        target_value=create.target_value,
    )
    db.add(goal)
    try:
        db.commit()
        db.refresh(goal)
    except IntegrityError as error:
        db.rollback()
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="A goal of this type already exists",
        ) from error
    except SQLAlchemyError as error:
        db.rollback()
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Could not create goal",
        ) from error

    activity = db.scalar(
        select(Activity).where(
            Activity.user_id == user.id,
            Activity.date == date.today(),
        )
    )
    return build_goal_response(goal, activity)


@router.patch("/{goal_id}", response_model=GoalResponse)
def update_goal(
    goal_id: uuid.UUID,
    update: GoalUpdate,
    db: Annotated[Session, Depends(get_db)],
    user: Annotated[User, Depends(get_current_user)],
) -> GoalResponse:
    goal = db.scalar(
        select(Goal).where(
            Goal.id == goal_id,
            Goal.user_id == user.id,
        )
    )
    if goal is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Goal was not found",
        )

    goal.target_value = update.target_value
    try:
        db.commit()
        db.refresh(goal)
    except SQLAlchemyError as error:
        db.rollback()
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Could not update goal",
        ) from error

    activity = db.scalar(
        select(Activity).where(
            Activity.user_id == user.id,
            Activity.date == date.today(),
        )
    )
    return build_goal_response(goal, activity)


@router.delete("/{goal_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_goal(
    goal_id: uuid.UUID,
    db: Annotated[Session, Depends(get_db)],
    user: Annotated[User, Depends(get_current_user)],
) -> Response:
    goal = db.scalar(
        select(Goal).where(
            Goal.id == goal_id,
            Goal.user_id == user.id,
        )
    )
    if goal is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Goal was not found",
        )

    db.delete(goal)
    try:
        db.commit()
    except SQLAlchemyError as error:
        db.rollback()
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Could not delete goal",
        ) from error

    return Response(status_code=status.HTTP_204_NO_CONTENT)
