import logging
from abc import ABC, abstractmethod
import httpx

from app.core.config import settings

logger = logging.getLogger("pulsepath.sms")


class SMSProvider(ABC):
    @abstractmethod
    def send_sms(self, phone_number: str, message: str) -> None:
        pass


class MockSMSProvider(SMSProvider):
    def send_sms(self, phone_number: str, message: str) -> None:
        # Redact actual message/OTP from log for security compliance
        masked = phone_number[:4] + "****" + phone_number[-2:] if len(phone_number) > 6 else phone_number
        logger.info("MockSMSProvider: SMS dispatch simulated for %s", masked)


class ProductionSMSProvider(SMSProvider):
    def __init__(
        self,
        api_key: str | None = None,
        provider_type: str | None = None,
        api_url: str | None = None,
    ) -> None:
        self.api_key = api_key or settings.sms_api_key
        self.provider_type = (provider_type or settings.sms_provider).lower()
        self.api_url = api_url or settings.sms_api_url

        if not self.api_key:
            raise RuntimeError(
                "Production SMS provider is not configured (missing sms_api_key). "
                "Silently falling back to MockSMSProvider in production mode is strictly forbidden."
            )

    def send_sms(self, phone_number: str, message: str) -> None:
        masked = phone_number[:4] + "****" + phone_number[-2:] if len(phone_number) > 6 else phone_number
        
        try:
            if self.provider_type == "twilio":
                url = self.api_url or "https://api.twilio.com/2010-04-01/Accounts"
                # Standard Twilio HTTP API call
                with httpx.Client(timeout=10.0) as client:
                    resp = client.post(
                        url,
                        data={"To": phone_number, "Body": message},
                        auth=(settings.sms_sender_id or "ACCOUNT_SID", self.api_key),
                    )
                    resp.raise_for_status()

            elif self.provider_type == "fast2sms":
                url = self.api_url or "https://www.fast2sms.com/dev/bulkV2"
                with httpx.Client(timeout=10.0) as client:
                    resp = client.post(
                        url,
                        headers={"authorization": self.api_key},
                        json={"numbers": phone_number, "message": message, "route": "q"},
                    )
                    resp.raise_for_status()

            else:
                # Generic HTTP POST SMS Webhook
                if not self.api_url:
                    raise RuntimeError("sms_api_url is required for generic SMS provider")
                with httpx.Client(timeout=10.0) as client:
                    resp = client.post(
                        self.api_url,
                        headers={"Authorization": f"Bearer {self.api_key}"},
                        json={"to": phone_number, "text": message},
                    )
                    resp.raise_for_status()

            logger.info("ProductionSMSProvider: SMS dispatched successfully to %s", masked)
        except Exception as error:
            logger.error("ProductionSMSProvider: Failed to dispatch SMS to %s: %s", masked, error)
            raise RuntimeError("SMS delivery failed. Please try again.") from error


def get_sms_provider() -> SMSProvider:
    env = getattr(settings, "app_env", "development").lower()
    provider_name = getattr(settings, "sms_provider", "mock").lower()

    if env == "production" or provider_name != "mock":
        return ProductionSMSProvider()
    return MockSMSProvider()
