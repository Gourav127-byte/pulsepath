import secrets
from dataclasses import dataclass
from datetime import date

from sqlalchemy import func, select
from sqlalchemy.orm import Session

from app.core.constants import MOCK_USER_ID
from app.db.database import SessionLocal
from app.db.models.activity import Activity
from app.db.models.goal import Goal
from app.db.models.profile import Profile
from app.db.models.user import User
from app.services.daily_score import SCORE_VERSION, calculate_daily_score
from app.services.auth import hash_password


@dataclass(frozen=True)
class SeedCounts:
    users: int
    profiles: int
    activities: int
    goals: int


def seed_data(session: Session) -> SeedCounts:
    user = session.get(User, MOCK_USER_ID)
    if user is None:
        user = User(
            id=MOCK_USER_ID,
            email="alex@example.com",
            password_hash=hash_password(secrets.token_urlsafe(32)),
        )
        session.add(user)
        session.flush()

    profile = session.scalar(select(Profile).where(Profile.user_id == MOCK_USER_ID))
    if profile is None:
        session.add(
            Profile(
                user_id=MOCK_USER_ID,
                display_name="Alex",
                subtitle="Building better daily habits",
                dark_theme=True,
                reduce_motion=False,
                haptic_feedback=True,
                use_metric_units=True,
            )
        )

    today = date.today()
    activity = session.scalar(
        select(Activity).where(
            Activity.user_id == MOCK_USER_ID,
            Activity.date == today,
        )
    )
    if activity is None:
        session.add(
            Activity(
                user_id=MOCK_USER_ID,
                date=today,
                steps=7842,
                active_minutes=46,
                distance=5.6,
                calories=324,
                daily_score=calculate_daily_score(
                    steps=7842,
                    active_minutes=46,
                    calories=324,
                ),
                score_version=SCORE_VERSION,
                source="manual",
            )
        )

    existing_goal_types = set(
        session.scalars(
            select(Goal.type).where(Goal.user_id == MOCK_USER_ID)
        ).all()
    )
    goal_targets = {
        "steps": 10_000,
        "active_minutes": 60,
        "calories": 450,
    }
    for goal_type, target_value in goal_targets.items():
        if goal_type not in existing_goal_types:
            session.add(
                Goal(
                    user_id=MOCK_USER_ID,
                    type=goal_type,
                    target_value=target_value,
                )
            )

    session.commit()
    return _counts(session, today)


def _counts(session: Session, today: date) -> SeedCounts:
    users = session.scalar(
        select(func.count()).select_from(User).where(User.id == MOCK_USER_ID)
    )
    profiles = session.scalar(
        select(func.count()).select_from(Profile).where(Profile.user_id == MOCK_USER_ID)
    )
    activities = session.scalar(
        select(func.count())
        .select_from(Activity)
        .where(Activity.user_id == MOCK_USER_ID, Activity.date == today)
    )
    goals = session.scalar(
        select(func.count()).select_from(Goal).where(Goal.user_id == MOCK_USER_ID)
    )
    return SeedCounts(
        users=int(users or 0),
        profiles=int(profiles or 0),
        activities=int(activities or 0),
        goals=int(goals or 0),
    )


def main() -> None:
    with SessionLocal() as session:
        counts = seed_data(session)
    print(
        "Seed complete: "
        f"users={counts.users}, "
        f"profiles={counts.profiles}, "
        f"activities={counts.activities}, "
        f"goals={counts.goals}"
    )


if __name__ == "__main__":
    main()
