import json
from typing import Protocol

import httpx
from pydantic import ValidationError

from app.core.config import settings
from app.schemas.veya import VeyaProviderRequest, VeyaStructuredResponse


class VeyaProviderUnavailableError(RuntimeError):
    """Raised when the configured AI provider cannot serve a request."""


class VeyaProvider(Protocol):
    async def generate(self, request: VeyaProviderRequest) -> VeyaStructuredResponse:
        """Generate a structured response from evidence only."""
        ...


class UnavailableVeyaProvider:
    async def generate(self, request: VeyaProviderRequest) -> VeyaStructuredResponse:
        del request
        raise VeyaProviderUnavailableError("No VEYA AI provider is configured")


class HttpVeyaProvider:
    """Production VEYA AI provider using an OpenAI-compatible REST endpoint."""

    def __init__(
        self,
        *,
        api_key: str,
        model: str = "gpt-4o-mini",
        base_url: str | None = None,
        timeout_seconds: float = 10.0,
        client: httpx.AsyncClient | None = None,
    ) -> None:
        self.api_key = api_key
        self.model = model
        if base_url:
            clean_url = base_url.rstrip("/")
            if clean_url.endswith("/chat/completions"):
                self.endpoint = clean_url
            else:
                self.endpoint = clean_url + "/chat/completions"
        else:
            self.endpoint = "https://api.openai.com/v1/chat/completions"
        self.timeout_seconds = timeout_seconds
        self._custom_client = client

    async def generate(self, request: VeyaProviderRequest) -> VeyaStructuredResponse:
        headers = {
            "Authorization": f"Bearer {self.api_key}",
            "Content-Type": "application/json",
        }

        system_instruction = (
            "You are VEYA, an evidence-grounded Activity Intelligence coach for PulsePath.\n"
            "Analyze the provided VeyaEvidencePacket and generate a VeyaStructuredResponse.\n"
            "STRICT CONSTRAINTS:\n"
            "1. Use only facts present in the evidence packet.\n"
            "2. Treat missing days as missing, never as zero.\n"
            "3. Preserve recording status and metric provenance exactly.\n"
            "4. Do not make medical, diagnostic, or causal claims.\n"
            "Output MUST be valid JSON conforming to the VeyaStructuredResponse schema.\n"
            "Set medical_or_causal_claims to false."
        )

        payload = {
            "model": self.model,
            "messages": [
                {"role": "system", "content": system_instruction},
                {"role": "user", "content": request.model_dump_json()},
            ],
            "response_format": {"type": "json_object"},
        }

        try:
            if self._custom_client is not None:
                response = await self._custom_client.post(
                    self.endpoint,
                    json=payload,
                    headers=headers,
                )
            else:
                async with httpx.AsyncClient(timeout=self.timeout_seconds) as client:
                    response = await client.post(
                        self.endpoint,
                        json=payload,
                        headers=headers,
                    )
            response.raise_for_status()
            data = response.json()
            if not isinstance(data, dict):
                raise TypeError("Response root must be a JSON object")

            choices = data.get("choices")
            if not choices or not isinstance(choices, list):
                raise IndexError("Response 'choices' array is missing or empty")

            first_choice = choices[0]
            if not isinstance(first_choice, dict):
                raise TypeError("First choice item must be an object")

            message = first_choice.get("message")
            if not isinstance(message, dict):
                raise TypeError("Choice message must be an object")

            raw_content = message.get("content")
            if not isinstance(raw_content, str):
                raise TypeError("Choice message content must be a string")

            parsed_json = json.loads(raw_content)
            return VeyaStructuredResponse.model_validate(parsed_json)
        except httpx.TimeoutException as exc:
            raise VeyaProviderUnavailableError(
                "VEYA provider request timed out"
            ) from exc
        except (
            httpx.HTTPError,
            KeyError,
            IndexError,
            TypeError,
            ValueError,
            json.JSONDecodeError,
        ) as exc:
            raise VeyaProviderUnavailableError(
                "VEYA provider communication failed"
            ) from exc
        except ValidationError as exc:
            raise VeyaProviderUnavailableError(
                "VEYA provider output failed schema validation"
            ) from exc


def get_veya_provider() -> VeyaProvider:
    provider_type = settings.veya_provider.lower().strip()
    if provider_type in ("openai", "http", "openai-compatible") and settings.veya_api_key:
        return HttpVeyaProvider(
            api_key=settings.veya_api_key,
            model=settings.veya_model,
            base_url=settings.veya_api_url,
            timeout_seconds=settings.veya_timeout_seconds,
        )
    return UnavailableVeyaProvider()


async def generate_veya_response(
    provider: VeyaProvider,
    request: VeyaProviderRequest,
) -> VeyaStructuredResponse:
    try:
        return await provider.generate(request)
    except VeyaProviderUnavailableError:
        return VeyaStructuredResponse(
            status="provider_unavailable",
            summary="VEYA insights are temporarily unavailable.",
            limitations=(
                "No AI interpretation was generated.",
                "Verified PulsePath evidence remains available in this response.",
            ),
        )
