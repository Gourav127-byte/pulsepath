import logging
import smtplib
from abc import ABC, abstractmethod
from email.mime.text import MIMEText

import httpx

from app.core.config import settings

logger = logging.getLogger("pulsepath.email")


class EmailProvider(ABC):
    @abstractmethod
    def send_email(self, to_email: str, subject: str, body: str) -> None:
        pass


class MockEmailProvider(EmailProvider):
    def send_email(self, to_email: str, subject: str, body: str) -> None:
        masked = to_email.split("@")[0][:2] + "***@" + to_email.split("@")[1]
        logger.info("MockEmailProvider: Email dispatch simulated for %s (subject: %s)", masked, subject)


class ProductionEmailProvider(EmailProvider):
    def __init__(self) -> None:
        self.provider_type = settings.email_provider.lower()

    def send_email(self, to_email: str, subject: str, body: str) -> None:
        masked = to_email.split("@")[0][:2] + "***@" + to_email.split("@")[1]
        try:
            if self.provider_type == "smtp":
                if not settings.smtp_host:
                    raise RuntimeError("smtp_host is required for SMTP email provider")
                msg = MIMEText(body, "plain", "utf-8")
                msg["Subject"] = subject
                msg["From"] = settings.email_from
                msg["To"] = to_email

                with smtplib.SMTP(settings.smtp_host, settings.smtp_port, timeout=10.0) as server:
                    server.starttls()
                    if settings.smtp_user and settings.smtp_password:
                        server.login(settings.smtp_user, settings.smtp_password)
                    server.send_message(msg)

            elif self.provider_type == "resend":
                if not settings.veya_api_key:  # or email api key
                    raise RuntimeError("Resend API key is required")
                with httpx.Client(timeout=10.0) as client:
                    resp = client.post(
                        "https://api.resend.com/emails",
                        headers={"Authorization": f"Bearer {settings.veya_api_key}"},
                        json={
                            "from": settings.email_from,
                            "to": [to_email],
                            "subject": subject,
                            "text": body,
                        },
                    )
                    resp.raise_for_status()

            logger.info("ProductionEmailProvider: Email dispatched to %s", masked)
        except Exception as error:
            logger.error("ProductionEmailProvider: Failed to send email to %s: %s", masked, error)
            raise RuntimeError("Email delivery failed.") from error


def get_email_provider() -> EmailProvider:
    provider_name = getattr(settings, "email_provider", "mock").lower()
    if provider_name != "mock":
        return ProductionEmailProvider()
    return MockEmailProvider()
