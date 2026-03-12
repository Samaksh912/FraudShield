from __future__ import annotations

from pydantic import BaseModel, Field


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

