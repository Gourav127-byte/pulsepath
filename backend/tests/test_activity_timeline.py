from datetime import date
import pytest
from httpx import ASGITransport, AsyncClient
from sqlalchemy import select

from app.db.database import SessionLocal
from app.db.models.step_sample import StepSample
from app.db.models.user import User
from app.main import app
from app.services.auth import create_access_token, hash_password


@pytest.mark.anyio
async def test_sync_and_get_activity_timeline() -> None:
    today_str = date.today().isoformat()
    test_email = "timeline-test@example.com"

    with SessionLocal() as db:
        user = db.scalars(select(User).where(User.email == test_email)).first()
        if not user:
            user = User(email=test_email, password_hash=hash_password("Password123!"))
            db.add(user)
            db.commit()
            db.refresh(user)
        token = create_access_token(str(user.id))
        user_id = user.id

    headers = {"Authorization": f"Bearer {token}"}
    sample_1_id = "sample-uuid-001"
    sample_2_id = "sample-uuid-002"

    sync_payload = {
        "date": today_str,
        "samples": [
            {
                "sample_id": sample_1_id,
                "start_time": f"{today_str}T08:00:00Z",
                "end_time": f"{today_str}T08:15:00Z",
                "steps": 450,
                "source_origin": "com.google.android.apps.fitness",
            },
            {
                "sample_id": sample_2_id,
                "start_time": f"{today_str}T09:30:00Z",
                "end_time": f"{today_str}T10:00:00Z",
                "steps": 1200,
                "source_origin": "com.vivo.health",
            },
        ],
    }

    async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as client:
        # 1. Post sync
        response = await client.post("/activity/timeline/sync", json=sync_payload, headers=headers)
        assert response.status_code == 200
        data = response.json()
        assert data["date"] == today_str
        assert data["total_steps"] == 1650
        assert data["samples_count"] == 2
        assert len(data["timeline"]) == 2

        # 2. Idempotency test (Sync same payload again)
        response_retry = await client.post("/activity/timeline/sync", json=sync_payload, headers=headers)
        assert response_retry.status_code == 200
        data_retry = response_retry.json()
        assert data_retry["total_steps"] == 1650
        assert data_retry["samples_count"] == 2

        # 3. GET timeline endpoint
        get_response = await client.get(f"/activity/timeline?date={today_str}", headers=headers)
        assert get_response.status_code == 200
        get_data = get_response.json()
        assert get_data["total_steps"] == 1650
        assert get_data["samples_count"] == 2
        assert get_data["timeline"][0]["sample_id"] == sample_1_id
        assert get_data["timeline"][0]["steps"] == 450
        assert get_data["timeline"][1]["sample_id"] == sample_2_id
        assert get_data["timeline"][1]["steps"] == 1200

    with SessionLocal() as db:
        db_samples = list(
            db.scalars(
                select(StepSample).where(
                    StepSample.user_id == user_id,
                    StepSample.date == date.today(),
                )
            ).all()
        )
        assert len(db_samples) == 2

