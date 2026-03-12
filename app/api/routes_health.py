from fastapi import APIRouter

from app import __version__
from app.risk.artifact_loader import load_artifact_registry
from app.schemas.common import ApiStatus
from app.schemas.responses import DomainHealth, HealthResponse

router = APIRouter()


@router.get("/health", response_model=HealthResponse)
def health() -> HealthResponse:
    registry = load_artifact_registry()
    return HealthResponse(
        status=ApiStatus.OK,
        engine_version=__version__,
        domains={
            domain: DomainHealth(mode=status.mode, artifact_version=status.artifact_version)
            for domain, status in registry.items.items()
        },
    )

