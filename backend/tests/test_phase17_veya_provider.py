import asyncio
import json
from datetime import date

import httpx
import pytest

from app.core.config import Settings
from app.db.models.activity import Activity
from app.schemas.veya import VeyaProviderRequest, VeyaStructuredResponse
from app.services.veya_evidence import build_evidence_packet
from app.services.veya_provider import (
    HttpVeyaProvider,
    UnavailableVeyaProvider,
    VeyaProviderUnavailableError,
    generate_veya_response,
    get_veya_provider,
)


def _sample_activity() -> Activity:
    return Activity(
        date=date.today(),
        steps=5000,
        active_minutes=30,
        distance=3.5,
        calories=250,
        daily_score=75,
        score_version="v2",
        source="manual",
        recording_status="recorded",
        steps_provenance="manual",
        distance_provenance="system",
        calories_provenance="system",
    )


def _sample_request() -> VeyaProviderRequest:
    packet = build_evidence_packet(
        days=7,
        history=[_sample_activity()],
        insights={
            "days": 7,
            "current_recorded_days": 1,
            "previous_recorded_days": 0,
            "current_legacy_days": 0,
            "previous_legacy_days": 0,
            "total_steps": 5000,
            "average_steps": 5000,
            "total_distance": 3.5,
            "total_active_calories": 250,
            "average_score": 75,
            "steps_change_percent": None,
            "distance_change_percent": None,
            "active_calories_change_percent": None,
            "average_score_change": None,
            "trend": "insufficient_data",
            "consistency_days": 1,
            "strongest_steps_day": None,
            "strongest_score_day": None,
        },
        engagement={
            "current_streak": 1,
            "best_streak": 1,
            "today_pending": False,
            "achievements": [],
        },
    )
    return VeyaProviderRequest(evidence=packet)


def test_provider_factory_selection(monkeypatch: pytest.MonkeyPatch) -> None:
    # 1. Default (unavailable)
    monkeypatch.setattr("app.services.veya_provider.settings", Settings(database_url="sqlite://", veya_provider="unavailable"))
    assert isinstance(get_veya_provider(), UnavailableVeyaProvider)

    # 2. Configured for openai but missing API key
    monkeypatch.setattr("app.services.veya_provider.settings", Settings(database_url="sqlite://", veya_provider="openai", veya_api_key=None))
    assert isinstance(get_veya_provider(), UnavailableVeyaProvider)

    # 3. Configured for openai with API key
    monkeypatch.setattr("app.services.veya_provider.settings", Settings(database_url="sqlite://", veya_provider="openai", veya_api_key="sk-test-key-123"))
    provider = get_veya_provider()
    assert isinstance(provider, HttpVeyaProvider)
    assert provider.api_key == "sk-test-key-123"


def test_http_provider_successful_generation() -> None:
    request_data = _sample_request()
    captured_request: httpx.Request | None = None

    valid_response_payload = {
        "choices": [
            {
                "message": {
                    "content": json.dumps({
                        "status": "generated",
                        "summary": "Consistent 5,000 step activity recorded.",
                        "observations": [
                            {
                                "text": "Daily goal of 5,000 steps reached.",
                                "confidence": "high",
                                "evidence": [{"fact": "steps", "date": str(date.today())}],
                            }
                        ],
                        "limitations": ["Only 1 recorded day available in the 7-day period."],
                        "medical_or_causal_claims": False,
                    })
                }
            }
        ]
    }

    def handler(req: httpx.Request) -> httpx.Response:
        nonlocal captured_request
        captured_request = req
        return httpx.Response(200, json=valid_response_payload)

    client = httpx.AsyncClient(transport=httpx.MockTransport(handler))
    provider = HttpVeyaProvider(api_key="sk-test-key", client=client)

    response = asyncio.run(provider.generate(request_data))

    assert isinstance(response, VeyaStructuredResponse)
    assert response.status == "generated"
    assert "5,000" in response.summary
    assert len(response.observations) == 1
    assert response.observations[0].confidence == "high"
    assert response.medical_or_causal_claims is False

    assert captured_request is not None
    assert captured_request.headers["Authorization"] == "Bearer sk-test-key"
    body_str = captured_request.content.decode("utf-8")
    assert "user_id" not in body_str
    assert "password" not in body_str
    assert "email" not in body_str


def test_http_provider_handles_timeout_safely() -> None:
    def handler(req: httpx.Request) -> httpx.Response:
        raise httpx.TimeoutException("Connection timed out", request=req)

    client = httpx.AsyncClient(transport=httpx.MockTransport(handler))
    provider = HttpVeyaProvider(api_key="sk-test-key", client=client)

    res = asyncio.run(generate_veya_response(provider, _sample_request()))

    assert res.status == "provider_unavailable"
    assert res.summary == "VEYA insights are temporarily unavailable."
    assert "No AI interpretation was generated." in res.limitations


def test_http_provider_handles_http_500_error_safely() -> None:
    def handler(_req: httpx.Request) -> httpx.Response:
        return httpx.Response(500, text="Internal Server Error")

    client = httpx.AsyncClient(transport=httpx.MockTransport(handler))
    provider = HttpVeyaProvider(api_key="sk-test-key", client=client)

    res = asyncio.run(generate_veya_response(provider, _sample_request()))

    assert res.status == "provider_unavailable"


def test_http_provider_handles_malformed_json_safely() -> None:
    def handler(_req: httpx.Request) -> httpx.Response:
        return httpx.Response(200, json={"choices": [{"message": {"content": "INVALID JSON {"}}]})

    client = httpx.AsyncClient(transport=httpx.MockTransport(handler))
    provider = HttpVeyaProvider(api_key="sk-test-key", client=client)

    res = asyncio.run(generate_veya_response(provider, _sample_request()))

    assert res.status == "provider_unavailable"


def test_http_provider_rejects_medical_or_causal_claims() -> None:
    # Model returns medical_or_causal_claims = true -> Schema validation MUST fail!
    payload = {
        "choices": [
            {
                "message": {
                    "content": json.dumps({
                        "status": "generated",
                        "summary": "This caused your heart health to improve.",
                        "observations": [],
                        "limitations": [],
                        "medical_or_causal_claims": True,  # Disallowed!
                    })
                }
            }
        ]
    }

    def handler(_req: httpx.Request) -> httpx.Response:
        return httpx.Response(200, json=payload)

    client = httpx.AsyncClient(transport=httpx.MockTransport(handler))
    provider = HttpVeyaProvider(api_key="sk-test-key", client=client)

    res = asyncio.run(generate_veya_response(provider, _sample_request()))

    assert res.status == "provider_unavailable"


def test_http_provider_handles_empty_choices_array_safely() -> None:
    # Choices is empty list [] -> IndexError handled safely
    def handler(_req: httpx.Request) -> httpx.Response:
        return httpx.Response(200, json={"choices": []})

    client = httpx.AsyncClient(transport=httpx.MockTransport(handler))
    provider = HttpVeyaProvider(api_key="sk-secret-key-999", client=client)

    res = asyncio.run(generate_veya_response(provider, _sample_request()))
    assert res.status == "provider_unavailable"


def test_http_provider_handles_null_message_content_safely() -> None:
    # Content is null -> TypeError handled safely
    def handler(_req: httpx.Request) -> httpx.Response:
        return httpx.Response(200, json={"choices": [{"message": {"content": None}}]})

    client = httpx.AsyncClient(transport=httpx.MockTransport(handler))
    provider = HttpVeyaProvider(api_key="sk-secret-key-999", client=client)

    res = asyncio.run(generate_veya_response(provider, _sample_request()))
    assert res.status == "provider_unavailable"


def test_http_provider_sanitizes_exception_and_does_not_leak_secrets() -> None:
    # HTTP status 401 error message should NOT contain the secret API key
    def handler(req: httpx.Request) -> httpx.Response:
        return httpx.Response(401, json={"error": "Unauthorized key sk-secret-key-999"})

    client = httpx.AsyncClient(transport=httpx.MockTransport(handler))
    provider = HttpVeyaProvider(api_key="sk-secret-key-999", client=client)

    with pytest.raises(VeyaProviderUnavailableError) as exc_info:
        asyncio.run(provider.generate(_sample_request()))

    err_msg = str(exc_info.value)
    assert "sk-secret-key-999" not in err_msg
    assert err_msg == "VEYA provider communication failed"


def test_http_provider_endpoint_url_construction_handles_existing_suffix() -> None:
    p1 = HttpVeyaProvider(api_key="key", base_url="https://custom.ai.com/v1")
    assert p1.endpoint == "https://custom.ai.com/v1/chat/completions"

    p2 = HttpVeyaProvider(api_key="key", base_url="https://custom.ai.com/v1/chat/completions")
    assert p2.endpoint == "https://custom.ai.com/v1/chat/completions"
