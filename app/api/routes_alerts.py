from fastapi import APIRouter

from app.risk.dependencies import get_engine
from app.schemas.responses import AlertsListResponse

router = APIRouter()


@router.get("/alerts", response_model=AlertsListResponse)
def list_alerts() -> AlertsListResponse:
    engine = get_engine()
    return AlertsListResponse(items=engine.list_alerts())
