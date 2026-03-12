"""PaySim artifact manifest builder."""
from __future__ import annotations

from datetime import datetime, timezone
from typing import Any

from training.paysim.feature_build import (
    PAYSIM_ONLINE_FEATURES,
    PAYSIM_REQUIRED_RAW_FIELDS,
    PAYSIM_TRAINING_FEATURES,
)


def build_paysim_manifest(
    artifact_version: str,
    metrics: dict[str, Any],
) -> dict[str, Any]:
    """Build a manifest dict compatible with training.common.artifact_manifest.ArtifactManifest.

    This manifest is what the backend's artifact_loader.py reads.
    """
    return {
        "domain": "paysim",
        "artifact_version": artifact_version,
        "model_family": "xgboost",
        "created_at": datetime.now(timezone.utc).isoformat(),
        "feature_order": PAYSIM_TRAINING_FEATURES,
        "required_raw_fields": PAYSIM_REQUIRED_RAW_FIELDS,
        "online_features": PAYSIM_ONLINE_FEATURES,
        "training_features": PAYSIM_TRAINING_FEATURES,
        "score_mapping": {
            "fraud_probability": "risk.score",
        },
        "alert_thresholds": {
            "review": 0.4,
            "block": 0.9,
        },
        "metrics_summary": {
            "pr_auc": metrics.get("pr_auc"),
            "f1": metrics.get("f1"),
        },
    }
