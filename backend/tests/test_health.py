import asyncio

from httpx import ASGITransport, AsyncClient, Response

from app.main import app


def test_health_check() -> None:
    response = asyncio.run(_get_health())

    assert response.status_code == 200
    assert response.json() == {"status": "ok"}


async def _get_health() -> Response:
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        return await client.get("/health")
