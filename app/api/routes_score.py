from fastapi import APIRouter

from app.risk.dependencies import get_engine
from app.schemas.requests import ScoreRequest
from app.schemas.responses import ScoreResponse

router = APIRouter()


@router.post("/score", response_model=ScoreResponse)
def score(request: ScoreRequest) -> ScoreResponse:
    engine = get_engine()
    return engine.score(request)
