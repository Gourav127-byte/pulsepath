import os
import re
from collections.abc import Generator
from pathlib import Path

import pytest
from alembic import command
from alembic.config import Config
from dotenv import dotenv_values
from sqlalchemy import create_engine, text
from sqlalchemy.engine import make_url


_BACKEND_DIR = Path(__file__).resolve().parents[1]
_ENV_VALUES = dotenv_values(_BACKEND_DIR / ".env")
_development_url = os.environ.get("DATABASE_URL") or _ENV_VALUES.get("DATABASE_URL")
_configured_test_url = os.environ.get("TEST_DATABASE_URL") or _ENV_VALUES.get(
    "TEST_DATABASE_URL"
)

if _configured_test_url:
    _test_url = make_url(_configured_test_url)
elif _development_url:
    _development = make_url(_development_url)
    _test_url = _development.set(database=f"{_development.database}_test")
else:
    raise RuntimeError(
        "Backend tests require TEST_DATABASE_URL or DATABASE_URL to locate a "
        "dedicated PostgreSQL test database."
    )

_test_database_name = _test_url.database or ""
if _test_url.get_backend_name() != "postgresql" or not re.fullmatch(
    r"[A-Za-z0-9_]+_test", _test_database_name
):
    raise RuntimeError(
        "Refusing to run backend tests: the database must be PostgreSQL and "
        "its name must end with '_test'."
    )


def _ensure_test_database_exists() -> None:
    admin_engine = create_engine(
        _test_url.set(database="postgres"),
        isolation_level="AUTOCOMMIT",
    )
    try:
        with admin_engine.connect() as connection:
            exists = connection.execute(
                text("SELECT 1 FROM pg_database WHERE datname = :name"),
                {"name": _test_database_name},
            ).scalar_one_or_none()
            if exists is None:
                connection.exec_driver_sql(f'CREATE DATABASE "{_test_database_name}"')
    finally:
        admin_engine.dispose()


_ensure_test_database_exists()
os.environ["APP_ENV"] = "test"
os.environ["DATABASE_URL"] = _test_url.render_as_string(hide_password=False)
os.environ.setdefault("JWT_SECRET", "TEST-ONLY-pulsepath-pytest-secret")

from app.core.constants import MOCK_USER_ID
from app.db.base import Base
from app.db.database import SessionLocal, engine
from app.db.seed import seed_data
from app.services.auth import create_access_token


def _truncate_test_database() -> None:
    with SessionLocal() as session:
        session.execute(
            text(
                "TRUNCATE TABLE email_otps, phone_otps, password_reset_tokens, refresh_tokens, activities, goals, "
                "profiles, users RESTART IDENTITY CASCADE"
            )
        )
        session.commit()


@pytest.fixture(scope="session")
def mock_user_token() -> str:
    return create_access_token(MOCK_USER_ID)


@pytest.fixture(scope="session", autouse=True)
def seeded_database() -> Generator[None, None, None]:
    alembic_config = Config(_BACKEND_DIR / "alembic.ini")
    command.upgrade(alembic_config, "head")
    _truncate_test_database()
    with SessionLocal() as session:
        seed_data(session)

    yield

    _truncate_test_database()
