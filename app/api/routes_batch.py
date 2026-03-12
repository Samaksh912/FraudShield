from fastapi import APIRouter

from app.risk.dependencies import get_engine
from app.schemas.requests import BatchScoreRequest
from app.schemas.responses import BatchScoreResponse

router = APIRouter()


@router.post("/batch", response_model=BatchScoreResponse)
def batch_score(request: BatchScoreRequest) -> BatchScoreResponse:
    engine = get_engine()
    return engine.score_batch(request)
