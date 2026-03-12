from fastapi import APIRouter

from app.risk.artifact_loader import load_artifact_registry
from app.schemas.responses import AdminModelStatusResponse

router = APIRouter()


@router.get("/admin/models", response_model=AdminModelStatusResponse)
def admin_models() -> AdminModelStatusResponse:
    registry = load_artifact_registry()
    return AdminModelStatusResponse(
        items={
            domain: {
                "artifact_version": status.artifact_version,
                "mode": status.mode,
                "manifest": status.manifest,
            }
            for domain, status in registry.items.items()
        }
    )

