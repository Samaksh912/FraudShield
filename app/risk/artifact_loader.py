from __future__ import annotations

import json
from pathlib import Path
from typing import Any

from pydantic import BaseModel, Field, ValidationError

from app.config import load_config
from app.schemas.common import ModelMode

REPO_ROOT = Path(__file__).resolve().parents[2]


class ArtifactManifest(BaseModel):
    domain: str
    artifact_version: str
    model_family: str
    created_at: str
    feature_order: list[str] = Field(default_factory=list)
    required_raw_fields: list[str] = Field(default_factory=list)
    online_features: list[str] = Field(default_factory=list)
    training_features: list[str] = Field(default_factory=list)
    score_mapping: dict[str, str] = Field(default_factory=dict)
    alert_thresholds: dict[str, float] = Field(default_factory=dict)


class ArtifactStatus(BaseModel):
    artifact_version: str | None = None
    mode: ModelMode
    manifest: dict[str, Any] = Field(default_factory=dict)


class ArtifactRegistry(BaseModel):
    items: dict[str, ArtifactStatus]


def _load_json(path: Path) -> dict[str, Any]:
    if not path.exists():
        return {}
    return json.loads(path.read_text())


def _resolve_repo_path(path_str: str) -> Path:
    path = Path(path_str)
    if path.is_absolute():
        return path
    return REPO_ROOT / path


def load_artifact_registry() -> ArtifactRegistry:
    config = load_config()
    paths = {
        "paysim": _resolve_repo_path(config.artifact_paths.paysim_latest),
        "ieee_cis": _resolve_repo_path(config.artifact_paths.ieee_cis_latest),
    }
    items: dict[str, ArtifactStatus] = {}
    for domain, path in paths.items():
        raw_manifest = _load_json(path)
        try:
            manifest = ArtifactManifest.model_validate(raw_manifest).model_dump(mode="python")
        except ValidationError:
            manifest = {}
        artifact_version = manifest.get("artifact_version")
        mode = ModelMode.MODEL_PLUS_RULES if artifact_version else ModelMode.HEURISTIC_ONLY
        items[domain] = ArtifactStatus(
            artifact_version=artifact_version,
            mode=mode,
            manifest=manifest,
        )
    return ArtifactRegistry(items=items)
