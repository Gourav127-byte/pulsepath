from app.db.models.activity import Activity
from app.db.models.goal import Goal
from app.schemas.goal import GoalResponse


def activity_value_for_goal(goal_type: str, activity: Activity | None) -> float:
    if activity is None:
        return 0.0

    values = {
        "steps": activity.steps,
        "active_minutes": activity.active_minutes,
        "calories": activity.calories,
        "distance": activity.distance,
    }
    return float(values.get(goal_type, 0.0))


def derive_goal_status(current_value: float, target_value: float) -> tuple[float, bool]:
    if target_value <= 0:
        return 0.0, False

    progress = min(max(current_value / target_value, 0.0), 1.0)
    return progress, current_value >= target_value


def build_goal_response(goal: Goal, activity: Activity | None) -> GoalResponse:
    current_value = activity_value_for_goal(goal.type, activity)
    progress, is_completed = derive_goal_status(current_value, goal.target_value)
    return GoalResponse(
        id=goal.id,
        type=goal.type,
        target_value=goal.target_value,
        current_value=current_value,
        progress=progress,
        is_completed=is_completed,
    )
