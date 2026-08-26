import asyncio
import logging

from httpx import ASGITransport, AsyncClient

from app.api.veya import router
from app.core.config import settings
from app.main import app
from app.services.veya_provider import HttpVeyaProvider, VeyaProviderUnavailableError, generate_veya_response
from app.services.veya_rate_limit import veya_rate_limiter
from tests.test_phase17_veya_foundation import _create_user_with_activity


async def _get(path: str, token: str | None = None):
    headers = {"Authorization": f"Bearer {token}"} if token else {}
    async with AsyncClient(
        transport=ASGITransport(app=app),
        base_url="http://test",
    ) as client:
        return await client.get(path, headers=headers)


async def _post(path: str, body: dict, token: str | None = None):
    headers = {"Authorization": f"Bearer {token}"} if token else {}
    async with AsyncClient(
        transport=ASGITransport(app=app),
        base_url="http://test",
    ) as client:
        return await client.post(path, json=body, headers=headers)


def test_veya_rate_limiting_enforced_per_user() -> None:
    veya_rate_limiter.reset_all()
    _user1_id, token1 = _create_user_with_activity(steps=5000)
    _user2_id, token2 = _create_user_with_activity(steps=8000)

    # Exhaust limit for user 1 (limit is 10 per minute)
    for i in range(settings.veya_rate_limit_per_minute):
        resp = asyncio.run(_get("/veya/foundation?days=7", token=token1))
        assert resp.status_code == 200

    # 11th request for user 1 fails with 429
    blocked_resp = asyncio.run(_get("/veya/foundation?days=7", token=token1))
    assert blocked_resp.status_code == 429
    assert "rate limit exceeded" in blocked_resp.json()["detail"].lower()

    # User 2 is NOT blocked (per-user isolation)
    user2_resp = asyncio.run(_get("/veya/foundation?days=7", token=token2))
    assert user2_resp.status_code == 200

    veya_rate_limiter.reset_all()


def test_veya_chat_empty_and_whitespace_input_rejected() -> None:
    _user_id, token = _create_user_with_activity(steps=5000)

    empty_resp = asyncio.run(_post("/veya/chat", {"message": "   "}, token))
    assert empty_resp.status_code == 422

    blank_resp = asyncio.run(_post("/veya/chat", {"message": ""}, token))
    assert blank_resp.status_code == 422


def test_veya_chat_oversized_input_rejected() -> None:
    _user_id, token = _create_user_with_activity(steps=5000)
    huge_message = "A" * 501
    resp = asyncio.run(_post("/veya/chat", {"message": huge_message}, token))
    assert resp.status_code == 422


def test_veya_telemetry_logs_operation_without_pii_or_secrets(caplog) -> None:
    import logging
    from uuid import UUID
    import app.services.veya_telemetry as vt

    with caplog.at_level(logging.INFO):
        vt.log_provider_call(
            provider_name="HttpVeyaProvider",
            model_name="gpt-4o-mini",
            duration_ms=145.2,
            status="success",
        )
        vt.log_grounding_result(
            duration_ms=1.8,
            status="passed",
        )
        vt.log_rate_limit_rejection(user_id=UUID("12345678-1234-5678-1234-567812345678"))

    for log_msg in caplog.text.splitlines():
        assert "Authorization" not in log_msg
        assert "Bearer" not in log_msg
        assert "sk-" not in log_msg
        assert "password" not in log_msg
        assert "@" not in log_msg


def test_veya_provider_timeout_and_5xx_fail_safely() -> None:
    class Mock500Client:
        async def post(self, *args, **kwargs):
            class MockResponse:
                def raise_for_status(self):
                    import httpx
                    raise httpx.HTTPStatusError("500 Server Error", request=None, response=None)
            return MockResponse()

    provider = HttpVeyaProvider(
        api_key="sk-secret-key-test",
        client=Mock500Client(),
    )
    from app.schemas.veya import VeyaProviderRequest
    from app.services.veya_evidence import build_evidence_packet
    from app.api.activity import get_activity_insights, get_activity_engagement
    from app.db.database import get_db

    db = next(get_db())
    _user_id, user_token = _create_user_with_activity(steps=5000)

    # Fetch real user model from DB
    from app.db.models.user import User
    user = db.query(User).filter(User.id == _user_id).first()

    history = []
    insights = get_activity_insights(db=db, user=user, days=7)
    engagement = get_activity_engagement(db=db, user=user)

    evidence = build_evidence_packet(
        days=7,
        history=history,
        insights=insights,
        engagement=engagement,
    )
    req = VeyaProviderRequest(evidence=evidence)

    try:
        asyncio.run(provider.generate(req))
        assert False, "Should have raised VeyaProviderUnavailableError"
    except VeyaProviderUnavailableError as exc:
        assert "sk-secret-key-test" not in str(exc)
        assert "Authorization" not in str(exc)

    res = asyncio.run(generate_veya_response(provider, req))
    assert res.status == "provider_unavailable"
    assert "temporarily unavailable" in res.summary


def test_veya_endpoints_are_read_only() -> None:
    veya_rate_limiter.reset_all()
    _user_id, token = _create_user_with_activity(steps=5000)

    # Calling VEYA endpoints must not alter database user state or activity records
    resp1 = asyncio.run(_get("/veya/foundation?days=7", token=token))
    assert resp1.status_code == 200

    resp2 = asyncio.run(_post("/veya/chat", {"message": "Hello VEYA"}, token))
    assert resp2.status_code == 200

    veya_rate_limiter.reset_all()


def test_veya_daily_quota_enforced_per_user() -> None:
    from app.services.veya_usage import veya_usage_tracker
    veya_rate_limiter.reset_all()
    veya_usage_tracker.reset_all()

    _user1_id, token1 = _create_user_with_activity(steps=5000)
    _user2_id, token2 = _create_user_with_activity(steps=8000)

    # Simulate user 1 hitting daily quota (default 50)
    for _ in range(settings.veya_daily_quota_per_user):
        veya_rate_limiter.reset_all()
        resp = asyncio.run(_get("/veya/foundation?days=7", token=token1))
        assert resp.status_code == 200

    # Next request for user 1 fails with 429 daily quota
    veya_rate_limiter.reset_all()
    quota_resp = asyncio.run(_get("/veya/foundation?days=7", token=token1))
    assert quota_resp.status_code == 429
    assert "daily veya request quota" in quota_resp.json()["detail"].lower()

    # User 2 is not affected (quota isolation)
    veya_rate_limiter.reset_all()
    user2_resp = asyncio.run(_get("/veya/foundation?days=7", token=token2))
    assert user2_resp.status_code == 200

    veya_rate_limiter.reset_all()
    veya_usage_tracker.reset_all()


def test_veya_usage_tracking_metrics_and_token_accounting() -> None:
    from app.services.veya_usage import veya_usage_tracker
    veya_usage_tracker.reset_all()

    class MockTokenUsageClient:
        async def post(self, *args, **kwargs):
            class MockResponse:
                def raise_for_status(self):
                    pass
                def json(self):
                    return {
                        "usage": {"prompt_tokens": 120, "completion_tokens": 45},
                        "choices": [
                            {
                                "message": {
                                    "content": '{"status": "generated", "summary": "Active day.", "observations": [], "limitations": [], "medical_or_causal_claims": false}'
                                }
                            }
                        ],
                    }
            return MockResponse()

    provider = HttpVeyaProvider(
        api_key="sk-test-key-usage",
        client=MockTokenUsageClient(),
    )
    from app.schemas.veya import VeyaProviderRequest
    from app.services.veya_evidence import build_evidence_packet
    from app.api.activity import get_activity_insights, get_activity_engagement
    from app.db.database import get_db
    from app.db.models.user import User

    db = next(get_db())
    _user_id, token = _create_user_with_activity(steps=5000)
    user = db.query(User).filter(User.id == _user_id).first()

    evidence = build_evidence_packet(
        days=7,
        history=[],
        insights=get_activity_insights(db=db, user=user, days=7),
        engagement=get_activity_engagement(db=db, user=user),
    )
    req = VeyaProviderRequest(evidence=evidence)

    res = asyncio.run(generate_veya_response(provider, req, user_id=user.id))
    assert res.status == "generated"

    summary = veya_usage_tracker.get_summary()
    assert summary["total_calls"] == 1
    assert summary["successful_calls"] == 1
    assert summary["total_prompt_tokens"] == 120
    assert summary["total_completion_tokens"] == 45
    assert summary["active_users_today"] == 1

    veya_usage_tracker.reset_all()


def test_no_secret_or_pii_leakage_in_usage_summary() -> None:
    from app.services.veya_usage import veya_usage_tracker
    veya_usage_tracker.record_usage(
        user_id=None,
        success=True,
        duration_ms=150.0,
        prompt_tokens=100,
        completion_tokens=50,
    )
    summary_str = str(veya_usage_tracker.get_summary())

    assert "Authorization" not in summary_str
    assert "Bearer" not in summary_str
    assert "sk-" not in summary_str
    assert "password" not in summary_str
    assert "@" not in summary_str

    veya_usage_tracker.reset_all()

