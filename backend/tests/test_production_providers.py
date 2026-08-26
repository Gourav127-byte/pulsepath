import logging
import pytest
from app.services.sms_provider import ProductionSMSProvider, MockSMSProvider
from app.services.email_provider import ProductionEmailProvider, MockEmailProvider


def test_production_sms_provider_raises_error_when_unconfigured() -> None:
    with pytest.raises(RuntimeError, match="Production SMS provider is not configured"):
        ProductionSMSProvider(api_key=None)


def test_mock_sms_provider_logs_without_raw_secrets(caplog) -> None:
    caplog.set_level(logging.INFO)
    provider = MockSMSProvider()
    provider.send_sms("+919876543210", "Your OTP is 123456")

    assert "123456" not in caplog.text  # OTP code must be redacted


def test_mock_email_provider_logs_without_raw_body(caplog) -> None:
    caplog.set_level(logging.INFO)
    provider = MockEmailProvider()
    provider.send_email("user@example.com", "Password Reset", "Your token is secret-123")

    assert "secret-123" not in caplog.text  # Reset token must be redacted
