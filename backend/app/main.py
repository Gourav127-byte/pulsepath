from fastapi import FastAPI

from app.api.activity import router as activity_router
from app.api.auth import router as auth_router
from app.api.goals import router as goals_router
from app.api.health import router as health_router
from app.api.profile import router as profile_router
from app.core.config import settings

app = FastAPI(title=settings.app_name)
app.include_router(health_router)
app.include_router(auth_router)
app.include_router(activity_router)
app.include_router(goals_router)
app.include_router(profile_router)
