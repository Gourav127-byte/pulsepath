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
from sqlalchemy import text
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
async def test_fresh_day_and_mixed_metrics(temp_user_token):
    from app.db.database import SessionLocal
    db_session = SessionLocal()


    # Fresh day
    r = await get("/activity/today", token=temp_user_token)
    assert r.status_code == 200
    assert r.json()["steps_provenance"] == "system"
    assert r.json()["steps"] == 0

    # HC syncs steps 5000
    await patch("/activity/today", json={"source": "health_connect", "steps": 5000}, token=temp_user_token)

    # Manual syncs calories 400
    r = await patch("/activity/today", json={"source": "manual", "calories": 400}, token=temp_user_token)

    assert r.json()["steps_provenance"] == "health_connect"
    assert r.json()["calories_provenance"] == "manual"
    assert r.json()["steps"] == 5000
    assert r.json()["calories"] == 400

@pytest.mark.anyio
def test_migration_backfill(seeded_database):
    from app.db.database import SessionLocal
    from app.db.models.user import User
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
