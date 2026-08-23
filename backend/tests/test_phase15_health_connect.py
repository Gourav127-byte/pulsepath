"""Phase 15 Batch 2 — Health Connect / Manual coexistence regression tests.

Tests verify:
  - max(manual, health_connect) merge semantics for every metric
  - repeated Health Connect sync is idempotent
  - manual edits after Health Connect sync
  - Health Connect sync after manual edits
  - partial metric sync (only some metrics from HC)
  - missing Health Connect data ≠ zero
  - recording_status correctness through all flows
  - source attribution accuracy
  - empty PATCH safety (no metric data, only source)
  - cross-user isolation
  - Daily Score / Journey consistency after mixed sources
"""

import asyncio
import uuid
from collections.abc import Generator
from datetime import date

import pytest
from httpx import ASGITransport, AsyncClient, Response
from sqlalchemy import select

from app.core.constants import MOCK_USER_ID
from app.db.database import SessionLocal
from app.db.models.activity import Activity
from app.db.models.goal import Goal
from app.db.models.user import User
from app.main import app
from app.services.auth import create_access_token
from app.services.daily_score_v2 import calculate_daily_score_v2


def request(
    method: str, path: str, json: dict[str, object], token: str | None = None
) -> Response:
    return asyncio.run(_request(method, path, json, token))


async def _request(
    method: str, path: str, json: dict[str, object], token: str | None
) -> Response:
    transport = ASGITransport(app=app)
    headers = {"Authorization": f"Bearer {token}"} if token else {}
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        return await client.request(method, path, json=json, headers=headers)


@pytest.fixture(autouse=True)
def restore_activity(mock_user_token: str) -> Generator[None, None, None]:
    """Snapshot and restore the mock user's today activity after each test."""
    with SessionLocal() as session:
        activity = session.scalar(
            select(Activity).where(
                Activity.user_id == MOCK_USER_ID,
                Activity.date == date.today(),
            )
        )
        assert activity is not None
        snapshot = {
            "id": activity.id,
            "user_id": activity.user_id,
            "steps": activity.steps,
            "steps_manual": activity.steps_manual,
            "steps_health_connect": activity.steps_health_connect,
            "active_minutes": activity.active_minutes,
            "active_minutes_manual": activity.active_minutes_manual,
            "active_minutes_health_connect": activity.active_minutes_health_connect,
            "calories": activity.calories,
            "calories_manual": activity.calories_manual,
            "calories_health_connect": activity.calories_health_connect,
            "distance": activity.distance,
            "distance_manual": activity.distance_manual,
            "distance_health_connect": activity.distance_health_connect,
            "daily_score": activity.daily_score,
            "score_version": activity.score_version,
            "source": activity.source,
            "recording_status": activity.recording_status,
        }

    yield

    with SessionLocal() as session:
        activity = session.get(Activity, snapshot["id"])
        assert activity is not None
        for field, value in snapshot.items():
            if field != "id":
                setattr(activity, field, value)
        session.commit()


# ---------------------------------------------------------------------------
# 1. max(manual, health_connect) merge for all four metrics
# ---------------------------------------------------------------------------

class TestMaxMergeSemantics:
    """The main metric column = max(manual_col, health_connect_col)."""

    def test_manual_higher_than_health_connect(self, mock_user_token: str) -> None:
        """When manual > HC, the main column uses manual."""
        # HC sync: steps=3000
        r = request("PATCH", "/activity/today", {"steps": 3000, "source": "health_connect"}, token=mock_user_token)
        assert r.status_code == 200

        # Manual: steps=5000
        r = request("PATCH", "/activity/today", {"steps": 5000, "source": "manual"}, token=mock_user_token)
        assert r.status_code == 200
        assert r.json()["steps"] == 5000

    def test_health_connect_higher_than_manual(self, mock_user_token: str) -> None:
        """When HC > manual, the main column uses HC."""
        # Manual: steps=3000
        r = request("PATCH", "/activity/today", {"steps": 3000, "source": "manual"}, token=mock_user_token)
        assert r.status_code == 200

        # HC: steps=8000
        r = request("PATCH", "/activity/today", {"steps": 8000, "source": "health_connect"}, token=mock_user_token)
        assert r.status_code == 200
        assert r.json()["steps"] == 8000

    def test_equal_values_use_that_value(self, mock_user_token: str) -> None:
        """When manual == HC, the main column uses that value."""
        r = request("PATCH", "/activity/today", {"steps": 5000, "source": "manual"}, token=mock_user_token)
        assert r.status_code == 200
        r = request("PATCH", "/activity/today", {"steps": 5000, "source": "health_connect"}, token=mock_user_token)
        assert r.status_code == 200
        assert r.json()["steps"] == 5000

    def test_max_applies_to_all_four_metrics(self, mock_user_token: str) -> None:
        """max() applies independently per metric, not as a unit."""
        # Manual: steps=5000 active_minutes=30 calories=200 distance=3.0
        r = request("PATCH", "/activity/today", {
            "steps": 5000, "active_minutes": 30, "calories": 200, "distance": 3.0,
            "source": "manual",
        }, token=mock_user_token)
        assert r.status_code == 200

        # HC: steps=3000 active_minutes=45 calories=150 distance=4.0
        r = request("PATCH", "/activity/today", {
            "steps": 3000, "active_minutes": 45, "calories": 150, "distance": 4.0,
            "source": "health_connect",
        }, token=mock_user_token)
        assert r.status_code == 200
        data = r.json()
        assert data["steps"] == 5000          # manual wins
        assert data["active_minutes"] == 45   # HC wins
        assert data["calories"] == 200        # manual wins
        assert data["distance"] == 4.0        # HC wins


# ---------------------------------------------------------------------------
# 2. Repeated Health Connect sync is idempotent
# ---------------------------------------------------------------------------

class TestIdempotentSync:
    """Sending the same HC data multiple times must not change the result."""

    def test_duplicate_health_connect_sync(self, mock_user_token: str) -> None:
        payload = {"steps": 6000, "calories": 350, "distance": 4.5, "source": "health_connect"}
        r1 = request("PATCH", "/activity/today", payload, token=mock_user_token)
        assert r1.status_code == 200
        first = r1.json()

        r2 = request("PATCH", "/activity/today", payload, token=mock_user_token)
        assert r2.status_code == 200
        second = r2.json()

        assert first["steps"] == second["steps"]
        assert first["calories"] == second["calories"]
        assert first["distance"] == second["distance"]
        assert first["daily_score"] == second["daily_score"]
        assert first["recording_status"] == second["recording_status"]

    def test_triple_health_connect_sync(self, mock_user_token: str) -> None:
        """Even three identical syncs are stable."""
        payload = {"steps": 4000, "source": "health_connect"}
        results = []
        for _ in range(3):
            r = request("PATCH", "/activity/today", payload, token=mock_user_token)
            assert r.status_code == 200
            results.append(r.json()["steps"])
        assert results == [4000, 4000, 4000]


# ---------------------------------------------------------------------------
# 3. Manual edits after Health Connect sync
# ---------------------------------------------------------------------------

class TestManualAfterHealthConnect:

    def test_manual_overrides_lower_hc_steps(self, mock_user_token: str) -> None:
        """User manually enters higher steps after HC sync."""
        request("PATCH", "/activity/today", {"steps": 3000, "source": "health_connect"}, token=mock_user_token)
        r = request("PATCH", "/activity/today", {"steps": 9000, "source": "manual"}, token=mock_user_token)
        assert r.status_code == 200
        assert r.json()["steps"] == 9000
        assert r.json()["source"] == "manual"

    def test_manual_lower_than_hc_reconciles_downward(self, mock_user_token: str) -> None:
        """User manually enters fewer steps than HC — downward offset reconciles to manual value with blended provenance."""
        request("PATCH", "/activity/today", {"steps": 8000, "source": "health_connect"}, token=mock_user_token)
        r = request("PATCH", "/activity/today", {"steps": 2000, "source": "manual"}, token=mock_user_token)
        assert r.status_code == 200
        assert r.json()["steps"] == 2000.0  # Downward offset reconciles to 2000
        assert r.json()["steps_provenance"] == "blended"
        # Source reflects the last source that provided metrics
        assert r.json()["source"] == "manual"

    def test_manual_preserves_hc_only_metrics(self, mock_user_token: str) -> None:
        """Manual edit of steps doesn't zero out HC-only calories."""
        request("PATCH", "/activity/today", {
            "steps": 3000, "calories": 400, "source": "health_connect",
        }, token=mock_user_token)
        r = request("PATCH", "/activity/today", {"steps": 5000, "source": "manual"}, token=mock_user_token)
        assert r.status_code == 200
        assert r.json()["steps"] == 5000
        assert r.json()["calories"] == 400  # HC calories preserved


# ---------------------------------------------------------------------------
# 4. Health Connect sync after manual edits
# ---------------------------------------------------------------------------

class TestHealthConnectAfterManual:

    def test_hc_overrides_lower_manual(self, mock_user_token: str) -> None:
        request("PATCH", "/activity/today", {"steps": 3000, "source": "manual"}, token=mock_user_token)
        r = request("PATCH", "/activity/today", {"steps": 10000, "source": "health_connect"}, token=mock_user_token)
        assert r.status_code == 200
        assert r.json()["steps"] == 10000

    def test_hc_lower_than_manual_keeps_manual(self, mock_user_token: str) -> None:
        """HC sync with lower value doesn't reduce the main column."""
        request("PATCH", "/activity/today", {"steps": 9000, "source": "manual"}, token=mock_user_token)
        r = request("PATCH", "/activity/today", {"steps": 5000, "source": "health_connect"}, token=mock_user_token)
        assert r.status_code == 200
        assert r.json()["steps"] == 9000  # manual still wins

    def test_hc_preserves_manual_only_metrics(self, mock_user_token: str) -> None:
        """HC sync of steps doesn't affect manual-only active_minutes."""
        request("PATCH", "/activity/today", {
            "steps": 2000, "active_minutes": 60, "source": "manual",
        }, token=mock_user_token)
        r = request("PATCH", "/activity/today", {"steps": 5000, "source": "health_connect"}, token=mock_user_token)
        assert r.status_code == 200
        assert r.json()["steps"] == 5000
        assert r.json()["active_minutes"] == 60  # manual active_minutes preserved


# ---------------------------------------------------------------------------
# 5. Partial metric sync
# ---------------------------------------------------------------------------

class TestPartialMetricSync:

    def test_hc_sends_only_steps(self, mock_user_token: str) -> None:
        """HC sync that only sends steps doesn't affect other metrics."""
        request("PATCH", "/activity/today", {
            "steps": 5000, "active_minutes": 30, "calories": 200, "distance": 3.0,
            "source": "manual",
        }, token=mock_user_token)
        r = request("PATCH", "/activity/today", {"steps": 8000, "source": "health_connect"}, token=mock_user_token)
        assert r.status_code == 200
        data = r.json()
        assert data["steps"] == 8000
        assert data["active_minutes"] == 30  # untouched
        assert data["calories"] == 200       # untouched
        assert data["distance"] == 3.0       # untouched

    def test_hc_sends_steps_and_distance_only(self, mock_user_token: str) -> None:
        """Partial HC sync updates only provided metrics."""
        request("PATCH", "/activity/today", {
            "steps": 5000, "calories": 300, "source": "manual",
        }, token=mock_user_token)
        r = request("PATCH", "/activity/today", {
            "steps": 7000, "distance": 5.5, "source": "health_connect",
        }, token=mock_user_token)
        assert r.status_code == 200
        data = r.json()
        assert data["steps"] == 7000     # HC wins
        assert data["distance"] == 5.5   # HC wins (manual distance was not set)
        assert data["calories"] == 300   # manual preserved


# ---------------------------------------------------------------------------
# 6. Missing Health Connect data ≠ zero
# ---------------------------------------------------------------------------

class TestMissingDataNotZero:

    def test_absent_hc_metric_does_not_zero_manual(self, mock_user_token: str) -> None:
        """If HC doesn't send steps, the manual steps must not be zeroed."""
        request("PATCH", "/activity/today", {"steps": 7000, "source": "manual"}, token=mock_user_token)
        # HC sends only calories, no steps
        r = request("PATCH", "/activity/today", {"calories": 250, "source": "health_connect"}, token=mock_user_token)
        assert r.status_code == 200
        assert r.json()["steps"] == 7000  # NOT zeroed

    def test_absent_manual_metric_does_not_zero_hc(self, mock_user_token: str) -> None:
        """If manual doesn't send calories, the HC calories must not be zeroed."""
        request("PATCH", "/activity/today", {"calories": 500, "source": "health_connect"}, token=mock_user_token)
        # Manual sends only steps
        r = request("PATCH", "/activity/today", {"steps": 3000, "source": "manual"}, token=mock_user_token)
        assert r.status_code == 200
        assert r.json()["calories"] == 500  # NOT zeroed

    def test_legacy_data_preserved_when_both_sources_null(self, mock_user_token: str) -> None:
        """Legacy (pre-HC schema) row has only main columns; both source cols are None.
        An empty PATCH should preserve legacy values via the fallback."""
        # The seeded activity has steps=7842, both _manual and _health_connect are None.
        r = request("PATCH", "/activity/today", {}, token=mock_user_token)
        assert r.status_code == 200
        assert r.json()["steps"] == 7842


# ---------------------------------------------------------------------------
# 7. recording_status correctness
# ---------------------------------------------------------------------------

class TestRecordingStatus:

    def test_manual_patch_sets_recorded(self, mock_user_token: str) -> None:
        r = request("PATCH", "/activity/today", {"steps": 100, "source": "manual"}, token=mock_user_token)
        assert r.json()["recording_status"] == "recorded"

    def test_hc_patch_sets_recorded(self, mock_user_token: str) -> None:
        r = request("PATCH", "/activity/today", {"steps": 100, "source": "health_connect"}, token=mock_user_token)
        assert r.json()["recording_status"] == "recorded"

    def test_empty_patch_preserves_existing_recording_status(self, mock_user_token: str) -> None:
        """An empty PATCH (no metrics, only recompute) must NOT flip an
        unrecorded row to 'recorded'."""
        # Get the current GET (which lazy-creates an unrecorded row if missing)
        get_r = request("GET", "/activity/today", {}, token=mock_user_token)
        original_status = get_r.json()["recording_status"]

        # Empty PATCH (no metrics)
        r = request("PATCH", "/activity/today", {}, token=mock_user_token)
        assert r.status_code == 200
        assert r.json()["recording_status"] == original_status

    def test_hc_zero_steps_is_recorded_not_unrecorded(self, mock_user_token: str) -> None:
        """Explicitly sending steps=0 from HC means 'user had 0 steps', not missing.
        Once a source column is set (even to 0), the legacy fallback is disabled."""
        r = request("PATCH", "/activity/today", {"steps": 0, "source": "health_connect"}, token=mock_user_token)
        assert r.status_code == 200
        assert r.json()["recording_status"] == "recorded"
        # HC explicitly said 0, and manual is None (→ 0), so max(0, 0) = 0.
        # The legacy value (7842) is NOT used because hc is no longer None.
        assert r.json()["steps"] == 0


# ---------------------------------------------------------------------------
# 8. Source attribution
# ---------------------------------------------------------------------------

class TestSourceAttribution:

    def test_manual_only_source_is_manual(self, mock_user_token: str) -> None:
        r = request("PATCH", "/activity/today", {"steps": 5000, "source": "manual"}, token=mock_user_token)
        assert r.json()["source"] == "manual"

    def test_hc_only_source_is_health_connect(self, mock_user_token: str) -> None:
        r = request("PATCH", "/activity/today", {"steps": 5000, "source": "health_connect"}, token=mock_user_token)
        assert r.json()["source"] == "health_connect"

    def test_empty_patch_does_not_change_source(self, mock_user_token: str) -> None:
        """Empty PATCH should not change the source field."""
        request("PATCH", "/activity/today", {"steps": 5000, "source": "manual"}, token=mock_user_token)
        r = request("PATCH", "/activity/today", {}, token=mock_user_token)
        assert r.json()["source"] == "manual"

    def test_invalid_source_rejected(self, mock_user_token: str) -> None:
        r = request("PATCH", "/activity/today", {"steps": 5000, "source": "garmin"}, token=mock_user_token)
        assert r.status_code == 422


# ---------------------------------------------------------------------------
# 9. Daily Score consistency with mixed sources
# ---------------------------------------------------------------------------

class TestDailyScoreConsistency:

    def test_score_uses_computed_max_values(self, mock_user_token: str) -> None:
        """The daily score must be computed from the max-merged values, not
        from a single source's values."""
        # Manual: steps=5000, active_minutes=60, calories=300
        request("PATCH", "/activity/today", {
            "steps": 5000, "active_minutes": 60, "calories": 300,
            "source": "manual",
        }, token=mock_user_token)
        # HC: steps=8000 (higher), no active_minutes or calories
        r = request("PATCH", "/activity/today", {
            "steps": 8000, "source": "health_connect",
        }, token=mock_user_token)
        data = r.json()

        # The score should be based on steps=8000, active_minutes=60, calories=300
        with SessionLocal() as session:
            goals = session.scalars(
                select(Goal).where(
                    Goal.user_id == MOCK_USER_ID,
                    Goal.type.in_(("steps", "active_minutes", "calories")),
                )
            ).all()
            targets = {g.type: g.target_value for g in goals}

        expected_score = calculate_daily_score_v2(
            steps=8000, active_minutes=60, calories=300, goal_targets=targets,
        )
        assert data["daily_score"] == expected_score

    def test_score_explanation_matches_after_mixed_source(self, mock_user_token: str) -> None:
        """Score explanation endpoint should work after mixed-source writes."""
        request("PATCH", "/activity/today", {"steps": 5000, "source": "manual"}, token=mock_user_token)
        request("PATCH", "/activity/today", {"steps": 8000, "source": "health_connect"}, token=mock_user_token)
        r = request("GET", "/activity/today/score-explanation", {}, token=mock_user_token)
        assert r.status_code == 200
        assert r.json()["available"] is True


# ---------------------------------------------------------------------------
# 10. Cross-user isolation
# ---------------------------------------------------------------------------

class TestCrossUserIsolation:

    def test_hc_sync_does_not_leak_to_other_user(self, mock_user_token: str) -> None:
        """User A's HC sync must not affect User B's activity."""
        temp_user_id = uuid.uuid4()
        with SessionLocal() as session:
            session.add(User(
                id=temp_user_id,
                email=f"isolation-{temp_user_id}@example.test",
                password_hash="test-only-not-a-real-password-hash",
            ))
            session.commit()

        try:
            temp_token = create_access_token(temp_user_id)

            # User A (mock user) writes HC data
            request("PATCH", "/activity/today", {
                "steps": 12000, "source": "health_connect",
            }, token=mock_user_token)

            # User B gets their activity — should not see User A's 12000 steps
            r = request("GET", "/activity/today", {}, token=temp_token)
            assert r.status_code == 200
            assert r.json()["steps"] == 0
            assert r.json()["recording_status"] == "unrecorded"
        finally:
            with SessionLocal() as session:
                temp_user = session.get(User, temp_user_id)
                if temp_user:
                    session.delete(temp_user)
                    session.commit()

    def test_manual_edit_does_not_leak_to_other_user(self, mock_user_token: str) -> None:
        """User A's manual edit must not affect User B."""
        temp_user_id = uuid.uuid4()
        with SessionLocal() as session:
            session.add(User(
                id=temp_user_id,
                email=f"isolation2-{temp_user_id}@example.test",
                password_hash="test-only-not-a-real-password-hash",
            ))
            session.commit()

        try:
            temp_token = create_access_token(temp_user_id)

            # User A manual edit
            request("PATCH", "/activity/today", {
                "steps": 9999, "source": "manual",
            }, token=mock_user_token)

            # User B — still zero
            r = request("GET", "/activity/today", {}, token=temp_token)
            assert r.status_code == 200
            assert r.json()["steps"] == 0
        finally:
            with SessionLocal() as session:
                temp_user = session.get(User, temp_user_id)
                if temp_user:
                    session.delete(temp_user)
                    session.commit()


# ---------------------------------------------------------------------------
# 11. Edge cases
# ---------------------------------------------------------------------------

class TestEdgeCases:

    def test_zero_manual_reconciles_downward(self, mock_user_token: str) -> None:
        """User manually enters 0 steps; downward offset reconciles value to 0 with blended provenance."""
        request("PATCH", "/activity/today", {"steps": 5000, "source": "health_connect"}, token=mock_user_token)
        r = request("PATCH", "/activity/today", {"steps": 0, "source": "manual"}, token=mock_user_token)
        assert r.status_code == 200
        assert r.json()["steps"] == 0.0  # Downward offset reconciles to 0
        assert r.json()["steps_provenance"] == "blended"

    def test_zero_hc_does_not_erase_manual(self, mock_user_token: str) -> None:
        """HC reports 0 steps; manual value of 5000 should still win."""
        request("PATCH", "/activity/today", {"steps": 5000, "source": "manual"}, token=mock_user_token)
        r = request("PATCH", "/activity/today", {"steps": 0, "source": "health_connect"}, token=mock_user_token)
        assert r.json()["steps"] == 5000  # max(5000, 0)

    def test_very_large_hc_value(self, mock_user_token: str) -> None:
        """Very large HC values should be accepted and stored."""
        r = request("PATCH", "/activity/today", {"steps": 99999, "source": "health_connect"}, token=mock_user_token)
        assert r.status_code == 200
        assert r.json()["steps"] == 99999

    def test_db_columns_match_api_response(self, mock_user_token: str) -> None:
        """Verify the DB source columns and main columns are consistent."""
        request("PATCH", "/activity/today", {
            "steps": 3000, "calories": 200, "source": "manual",
        }, token=mock_user_token)
        request("PATCH", "/activity/today", {
            "steps": 5000, "calories": 100, "source": "health_connect",
        }, token=mock_user_token)

        with SessionLocal() as session:
            activity = session.scalar(
                select(Activity).where(
                    Activity.user_id == MOCK_USER_ID,
                    Activity.date == date.today(),
                )
            )
            assert activity is not None
            assert activity.steps_manual == 3000
            assert activity.steps_health_connect == 5000
            assert activity.steps == 5000  # max(3000, 5000)
            assert activity.calories_manual == 200
            assert activity.calories_health_connect == 100
            assert activity.calories == 200  # max(200, 100)

    def test_malformed_data_rejected_safely(self, mock_user_token: str) -> None:
        """Malformed data (e.g., negative metrics, strings) must be rejected with 422 
        and must not overwrite existing data."""
        request("PATCH", "/activity/today", {"steps": 1000, "source": "health_connect"}, token=mock_user_token)
        
        # Try negative step count
        r1 = request("PATCH", "/activity/today", {"steps": -50, "source": "health_connect"}, token=mock_user_token)
        assert r1.status_code == 422
        
        # Try string instead of number
        r2 = request("PATCH", "/activity/today", {"steps": "a lot", "source": "health_connect"}, token=mock_user_token)
        assert r2.status_code == 422
        
        # Verify previous data is intact
        r_verify = request("GET", "/activity/today", {}, token=mock_user_token)
        assert r_verify.json()["steps"] == 1000
