import asyncio
import uuid
from collections.abc import Generator

import pytest
from httpx import ASGITransport, AsyncClient, Response
from sqlalchemy import delete, select

from app.db.database import SessionLocal
from app.db.models.user import User
from app.db.models.profile import Profile
from app.db.models.goal import Goal
from app.db.models.activity import Activity
from app.db.models.password_reset_token import PasswordResetToken
from app.core.constants import MOCK_USER_ID
from app.main import app

TEST_EMAIL_A = "user_a@example.com"
TEST_EMAIL_B = "user_b@example.com"
PASSWORD = "password123"


async def _request(
    method: str,
    path: str,
    json_body: dict[str, object] | None = None,
    token: str | None = None,
) -> Response:
    transport = ASGITransport(app=app)
    headers = {"Authorization": f"Bearer {token}"} if token else {}
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        return await client.request(method, path, json=json_body, headers=headers)


@pytest.fixture(autouse=True)
def clean_users() -> Generator[None, None, None]:
    def _do_clean():
        with SessionLocal() as session:
            # Delete by email to be absolutely sure
            session.execute(delete(User).where(User.email.in_([TEST_EMAIL_A, TEST_EMAIL_B])))
            session.commit()

    _do_clean()
    yield
    _do_clean()


def register(email: str) -> str:
    response = asyncio.run(_request("POST", "/auth/register", {"email": email, "password": PASSWORD}))
    if response.status_code != 201:
        print(f"Register failed: {response.status_code} - {response.json()}")
    assert response.status_code == 201
    return response.json()["access_token"]


def test_new_user_provisioning() -> None:
    token = register(TEST_EMAIL_A)

    # Check Profile
    response = asyncio.run(_request("GET", "/profile", token=token))
    assert response.status_code == 200
    profile = response.json()
    assert profile["display_name"] == "User_a"
    assert profile["use_metric_units"] is True

    # Check Goals
    response = asyncio.run(_request("GET", "/goals", token=token))
    assert response.status_code == 200
    goals = response.json()
    assert len(goals) == 3

    # Check Activity
    response = asyncio.run(_request("GET", "/activity/today", token=token))
    assert response.status_code == 200
    activity = response.json()
    assert activity["steps"] == 0
    assert activity["daily_score"] == 0


def test_two_user_isolation() -> None:
    token_a = register(TEST_EMAIL_A)
    token_b = register(TEST_EMAIL_B)

    # User A modifies their profile
    asyncio.run(_request("PATCH", "/profile", {"display_name": "Alice"}, token=token_a))

    # User B should still see their default profile
    response_b = asyncio.run(_request("GET", "/profile", token=token_b))
    assert response_b.json()["display_name"] == "User_b"

    # User A modifies their activity
    asyncio.run(_request("PATCH", "/activity/today", {"steps": 5000}, token=token_a))

    # User B should still have zero steps
    response_b = asyncio.run(_request("GET", "/activity/today", token=token_b))
    assert response_b.json()["steps"] == 0

def test_goal_isolation() -> None:
    token_a = register(TEST_EMAIL_A)
    token_b = register(TEST_EMAIL_B)

    goals_b = asyncio.run(_request("GET", "/goals", token=token_b)).json()
    goal_b_id = goals_b[0]["id"]

    # User A tries to DELETE User B's goal
    response = asyncio.run(_request("DELETE", f"/goals/{goal_b_id}", token=token_a))
    assert response.status_code == 404

    # User A tries to PATCH User B's goal
    response = asyncio.run(_request("PATCH", f"/goals/{goal_b_id}", {"target_value": 999}, token=token_a))
    assert response.status_code == 404


def test_daily_score_isolation() -> None:
    token_a = register(TEST_EMAIL_A)
    token_b = register(TEST_EMAIL_B)

    # User A has 10k steps goal. User B has same.
    # Let's change User A's steps goal to 5k.
    goals_a = asyncio.run(_request("GET", "/goals", token=token_a)).json()
    steps_goal_a_id = next(g["id"] for g in goals_a if g["type"] == "steps")
    asyncio.run(_request("PATCH", f"/goals/{steps_goal_a_id}", {"target_value": 5000}, token=token_a))

    # Now User A and User B both report 2500 steps.
    # User A score should be higher because target is lower.

    # But wait, we need Activity to exist.
    # I'll update register to provision activity too.
