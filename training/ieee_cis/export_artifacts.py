"""IEEE-CIS artifact manifest builder."""
from __future__ import annotations

from datetime import datetime, timezone
from typing import Any

from training.ieee_cis.feature_build import (
    IEEE_CIS_ONLINE_FEATURES,
    IEEE_CIS_TRAINING_FEATURES,
)
from training.ieee_cis.identity_join import UID_FIELDS


# Raw fields needed to reconstruct uid + compute features at inference time
IEEE_CIS_REQUIRED_RAW_FIELDS: list[str] = [
    "TransactionDT",
    "TransactionAmt",
    "ProductCD",
    *UID_FIELDS,  # card1, card2, card3, card5, addr1, addr2
    "P_emaildomain",
    "R_emaildomain",
    "DeviceType",
    "DeviceInfo",
    "dist1",
    "id_30",
    "id_31",
    "id_33",
]


def build_ieee_manifest(
    artifact_version: str,
    metrics: dict[str, Any],
) -> dict[str, Any]:
    """Build a manifest dict compatible with training.common.artifact_manifest.ArtifactManifest."""
    return {
        "domain": "ieee_cis",
        "artifact_version": artifact_version,
        "model_family": "xgboost",
        "created_at": datetime.now(timezone.utc).isoformat(),
        "feature_order": IEEE_CIS_TRAINING_FEATURES,
        "required_raw_fields": IEEE_CIS_REQUIRED_RAW_FIELDS,
        "online_features": IEEE_CIS_ONLINE_FEATURES,
        "training_features": IEEE_CIS_TRAINING_FEATURES,
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
