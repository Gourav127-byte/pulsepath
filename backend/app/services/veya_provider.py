from typing import Protocol

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


def get_veya_provider() -> VeyaProvider:
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
