from fastapi import APIRouter

from app.api.routes_admin import router as admin_router
from app.api.routes_alerts import router as alerts_router
from app.api.routes_batch import router as batch_router
from app.api.routes_health import router as health_router
from app.api.routes_score import router as score_router


def build_api_router() -> APIRouter:
    router = APIRouter()
    router.include_router(score_router)
    router.include_router(batch_router)
    router.include_router(alerts_router)
    router.include_router(health_router)
    router.include_router(admin_router)
    return router

