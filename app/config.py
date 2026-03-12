from __future__ import annotations

from functools import lru_cache
from pathlib import Path

import yaml
from pydantic import BaseModel, Field


class ApiConfig(BaseModel):
    prefix: str = "/v1"


class ThresholdConfig(BaseModel):
    low_to_medium: float = 0.4
    medium_to_high: float = 0.75
    review_to_block: float = 0.9


class ArtifactPathConfig(BaseModel):
    manifests_dir: str
    paysim_latest: str
    ieee_cis_latest: str


class DefaultConfig(BaseModel):
    artifact_version: str = "unavailable"
    fusion_version: str = "default_v1"
    model_mode: str = "heuristic_only"


class AppConfig(BaseModel):
    engine_version: str = "0.1.0"
    api: ApiConfig = Field(default_factory=ApiConfig)
    thresholds: ThresholdConfig = Field(default_factory=ThresholdConfig)
    artifact_paths: ArtifactPathConfig
    defaults: DefaultConfig = Field(default_factory=DefaultConfig)
    supported_domains: list[str] = Field(default_factory=lambda: ["paysim", "ieee_cis"])


@lru_cache(maxsize=1)
def load_config() -> AppConfig:
    config_path = Path(__file__).resolve().parent / "config.yaml"
    raw = yaml.safe_load(config_path.read_text())
    return AppConfig.model_validate(raw)

