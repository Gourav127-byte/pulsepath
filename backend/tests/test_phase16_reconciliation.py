import pytest
import uuid
import jwt
from datetime import datetime, timedelta, timezone
from app.core.config import settings
from app.db.database import SessionLocal
from app.db.models.user import User

@pytest.fixture
def temp_user_token():
    uid = uuid.uuid4()
    with SessionLocal() as db:
        user = User(id=uid, email=f"{uid}@test.com", password_hash="hash")
        db.add(user)
        db.commit()

    expire = datetime.now(timezone.utc) + timedelta(minutes=15)
    to_encode = {"sub": str(uid), "exp": expire}
    return jwt.encode(to_encode, settings.jwt_secret, algorithm=settings.jwt_algorithm)

import pytest
import asyncio
from datetime import date
from httpx import ASGITransport, AsyncClient
from sqlalchemy import select, text
from app.db.models.activity import Activity
from app.core.config import settings
from app.main import app

async def patch(path: str, json: dict, token: str) -> dict:
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        r = await client.patch(path, json=json, headers={"Authorization": f"Bearer {token}"})
        return r

async def get(path: str, token: str) -> dict:
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        r = await client.get(path, headers={"Authorization": f"Bearer {token}"})
        return r


def activity_for_token(token: str) -> Activity:
    payload = jwt.decode(
        token,
        settings.jwt_secret,
        algorithms=[settings.jwt_algorithm],
    )
    user_id = uuid.UUID(payload["sub"])
    with SessionLocal() as db:
        activity = db.scalar(
            select(Activity).where(
                Activity.user_id == user_id,
                Activity.date == date.today(),
            )
        )
        assert activity is not None
        db.expunge(activity)
        return activity

@pytest.mark.anyio
async def test_reconciliation_downward_correction_and_growth(temp_user_token):
    from app.db.database import SessionLocal
    db_session = SessionLocal()


    # 1. HC syncs 20k
    r = await patch("/activity/today", json={"source": "health_connect", "steps": 20000}, token=temp_user_token)
    if r.status_code != 200:
        print(r.json())
    assert r.status_code == 200
    assert r.json()["steps"] == 20000
    assert r.json()["steps_provenance"] == "health_connect"

    # 2. Manual downward correction to 5k
    r = await patch("/activity/today", json={"source": "manual", "steps": 5000}, token=temp_user_token)
    assert r.status_code == 200
    assert r.json()["steps"] == 5000
    assert r.json()["steps_provenance"] == "blended"

    # 3. HC grows to 21k
    r = await patch("/activity/today", json={"source": "health_connect", "steps": 21000}, token=temp_user_token)
    assert r.status_code == 200
    assert r.json()["steps"] == 6000
    assert r.json()["steps_provenance"] == "blended"

@pytest.mark.anyio
async def test_reconciliation_2_read_reduction(temp_user_token):
    from app.db.database import SessionLocal
    db_session = SessionLocal()


    # HC 20k
    await patch("/activity/today", json={"source": "health_connect", "steps": 20000}, token=temp_user_token)

    # 1st read: Drops to 15k
    r = await patch("/activity/today", json={"source": "health_connect", "steps": 15000}, token=temp_user_token)
    assert r.status_code == 200
    assert r.json()["steps"] == 20000 # Unchanged

    # 2nd read: Confirms 15k
    r = await patch("/activity/today", json={"source": "health_connect", "steps": 15000}, token=temp_user_token)
    assert r.status_code == 200
    assert r.json()["steps"] == 15000 # Reduced
    assert r.json()["steps_provenance"] == "health_connect"

@pytest.mark.anyio
async def test_reconciliation_spurious_null_ignored(temp_user_token):
    from app.db.database import SessionLocal
    db_session = SessionLocal()


    # HC 20k
    await patch("/activity/today", json={"source": "health_connect", "steps": 20000}, token=temp_user_token)

    # Spurious explicit null metric payload is rejected with 422
    r_null = await patch("/activity/today", json={"source": "health_connect", "steps": None}, token=temp_user_token)
    assert r_null.status_code == 422

    # Spurious empty/omitted metric sync payload preserves 20k without advancing reduction
    r = await patch("/activity/today", json={"source": "health_connect"}, token=temp_user_token)
    assert r.status_code == 200
    assert r.json()["steps"] == 20000 # Unchanged

    # Next read: 15k. Because omitted metric payload was ignored, 15k is the FIRST read of a reduction!
    r = await patch("/activity/today", json={"source": "health_connect", "steps": 15000}, token=temp_user_token)
    assert r.status_code == 200
    assert r.json()["steps"] == 20000 # Still 20k because 15k needs a 2nd confirmation!

@pytest.mark.anyio
async def test_reset_to_auto(temp_user_token):
    from app.db.database import SessionLocal
    db_session = SessionLocal()


    # HC 20k
    await patch("/activity/today", json={"source": "health_connect", "steps": 20000}, token=temp_user_token)

    # Manual 5k
    await patch("/activity/today", json={"source": "manual", "steps": 5000}, token=temp_user_token)

    # Reset
    r = await patch("/activity/today", json={"reset_steps_to_auto": True}, token=temp_user_token)
    assert r.status_code == 200
    assert r.json()["steps"] == 20000
    assert r.json()["steps_provenance"] == "health_connect"


@pytest.mark.anyio
async def test_manual_active_minutes_never_writes_health_connect_field(
    temp_user_token,
):
    r = await patch(
        "/activity/today",
        json={"source": "manual", "active_minutes": 42},
        token=temp_user_token,
    )

    assert r.status_code == 200
    assert r.json()["active_minutes"] == 42
    assert r.json()["active_minutes_provenance"] == "manual"
    activity = activity_for_token(temp_user_token)
    assert activity.active_minutes_manual == 42
    assert activity.active_minutes_health_connect is None


@pytest.mark.anyio
async def test_active_minutes_reconcile_manual_and_workout_without_heuristic(
    temp_user_token,
):
    manual = await patch(
        "/activity/today",
        json={"source": "manual", "steps": 10000, "active_minutes": 30},
        token=temp_user_token,
    )
    assert manual.status_code == 200
    assert manual.json()["active_minutes"] == 30

    health_connect = await patch(
        "/activity/today",
        json={"source": "health_connect", "active_minutes": 45},
        token=temp_user_token,
    )

    assert health_connect.status_code == 200
    assert health_connect.json()["active_minutes"] == 45
    activity = activity_for_token(temp_user_token)
    assert activity.active_minutes_manual == 30
    assert activity.active_minutes_health_connect == 45


@pytest.mark.anyio
async def test_steps_only_never_create_active_minutes(temp_user_token):
    response = await patch(
        "/activity/today",
        json={"source": "health_connect", "steps": 10000},
        token=temp_user_token,
    )

    assert response.status_code == 200
    assert response.json()["active_minutes"] is None
    activity = activity_for_token(temp_user_token)
    assert activity.active_minutes_manual is None
    assert activity.active_minutes_health_connect is None


@pytest.mark.anyio
async def test_reset_to_auto_clears_pending_reduction_state(temp_user_token):
    await patch(
        "/activity/today",
        json={"source": "health_connect", "steps": 20000},
        token=temp_user_token,
    )
    await patch(
        "/activity/today",
        json={"source": "health_connect", "steps": 15000},
        token=temp_user_token,
    )
    pending = activity_for_token(temp_user_token)
    assert pending.steps_pending_reduction_value == 15000
    assert pending.steps_pending_reduction_at is not None

    r = await patch(
        "/activity/today",
        json={"reset_steps_to_auto": True},
        token=temp_user_token,
    )

    assert r.status_code == 200
    reset = activity_for_token(temp_user_token)
    assert reset.steps_pending_reduction_value is None
    assert reset.steps_pending_reduction_at is None


@pytest.mark.anyio
async def test_reset_flag_does_not_record_untouched_fresh_activity(temp_user_token):
    initial = await get("/activity/today", token=temp_user_token)
    assert initial.status_code == 200
    assert initial.json()["recording_status"] == "unrecorded"
    assert initial.json()["source"] == "system"

    r = await patch(
        "/activity/today",
        json={"reset_steps_to_auto": True},
        token=temp_user_token,
    )

    assert r.status_code == 200
    assert r.json()["recording_status"] == "unrecorded"
    assert r.json()["source"] == "system"
    assert r.json()["steps_provenance"] == "system"


@pytest.mark.anyio
async def test_fresh_day_and_mixed_metrics(temp_user_token):
    r = await get("/activity/today", token=temp_user_token)
    assert r.status_code == 200
    assert r.json()["steps_provenance"] == "system"
    assert r.json()["steps"] is None

    # HC syncs steps 5000
    await patch("/activity/today", json={"source": "health_connect", "steps": 5000}, token=temp_user_token)

    # Manual syncs calories 400
    r = await patch("/activity/today", json={"source": "manual", "calories": 400}, token=temp_user_token)

    assert r.json()["steps_provenance"] == "health_connect"
    assert r.json()["calories_provenance"] == "manual"
    assert r.json()["steps"] == 5000
    assert r.json()["calories"] == 400
    from sqlalchemy import select
    from datetime import date, timezone, datetime
    import uuid
    db_session = SessionLocal()
    test_user = db_session.scalar(select(User).limit(1))
    # Create raw row with legacy manual source
    db_session.execute(text("""
        INSERT INTO activities (id, user_id, date, steps, steps_manual, steps_health_connect, active_minutes, distance, calories, daily_score, score_version, source, recording_status, steps_downward_offset, steps_provenance, created_at, updated_at, distance_downward_offset, distance_provenance, calories_downward_offset, calories_provenance)
        VALUES (:id, :uid, :dt, 5000, 5000, 20000, 0, 0, 0, 0, 'v2', 'manual', 'recorded', 0, 'system', :now, :now, 0, 'system', 0, 'system')
    """), {"id": str(uuid.uuid4()), "uid": str(test_user.id), "dt": "2020-01-01", "now": datetime.now(timezone.utc)})


    # Run the backfill logic manually as if migration ran
    db_session.execute(text("""
        UPDATE activities SET
        steps_downward_offset = GREATEST(COALESCE(steps_manual, 0), COALESCE(steps_health_connect, 0)) - COALESCE(steps_manual, 0)
        WHERE source = 'manual'
    """))
    db_session.execute(text("""
        UPDATE activities SET
        steps_provenance = CASE WHEN steps_downward_offset > 0 THEN 'blended' ELSE 'manual' END
        WHERE source = 'manual'
    """))


    row = db_session.execute(text("SELECT steps_downward_offset, steps_provenance FROM activities WHERE date = '2020-01-01'")).fetchone()
    assert row[0] == 15000
    assert row[1] == "blended"
    db_session.close()
