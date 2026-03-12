import json
from pathlib import Path

import pytest

from app.risk.artifact_loader import load_artifact_registry
from app.schemas.responses import AlertsListItem, RiskResponse, ScoreBreakdown


BASE_DIR = Path(__file__).resolve().parents[1]


def test_score_fields_enforce_normalized_ranges() -> None:
    with pytest.raises(Exception):
        RiskResponse(score=1.2, level="high", decision="review", confidence=0.5)
    with pytest.raises(Exception):
        ScoreBreakdown(heuristic=0.4, supervised=-0.1, anomaly=None, fusion_version="v1")


def test_invalid_manifest_stays_heuristic_only(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> None:
    manifest_dir = tmp_path / "artifacts" / "manifests"
    manifest_dir.mkdir(parents=True)
    bad_manifest = manifest_dir / "paysim_latest.json"
    good_empty = manifest_dir / "ieee_cis_latest.json"
    bad_manifest.write_text(json.dumps({"artifact_version": "v1"}))
    good_empty.write_text("{}")

    monkeypatch.setenv("PYTHONHASHSEED", "0")

    from app.config import load_config

    load_config.cache_clear()
    config = load_config()
    config.artifact_paths.paysim_latest = str(bad_manifest)
    config.artifact_paths.ieee_cis_latest = str(good_empty)

    registry = load_artifact_registry()
    assert registry.items["paysim"].mode.value == "heuristic_only"
    assert registry.items["paysim"].artifact_version is None


def test_alert_item_enforces_normalized_risk_score() -> None:
    with pytest.raises(Exception):
        AlertsListItem(
            alert_id="a1",
            type="suspicious_transaction",
            priority="high",
            status="open",
            recommended_action="review",
            domain="paysim",
            transaction_id="txn_1",
            risk_score=1.5,
        )
