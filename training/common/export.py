"""Artifact bundle export and latest-manifest refresh."""
from __future__ import annotations

import json
import shutil
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

import joblib

REPO_ROOT = Path(__file__).resolve().parents[2]


def export_artifact_bundle(
    output_dir: str | Path,
    *,
    model: Any,
    manifest: dict[str, Any],
    feature_order: list[str],
    feature_defaults: dict[str, float | int],
    thresholds: dict[str, Any],
    metrics: dict[str, Any],
    metadata: dict[str, Any] | None = None,
    anomaly_model: Any | None = None,
) -> Path:
    """Write all expected artifact files to output_dir.

    Expected files per export_spec.md:
      - supervised_model.joblib
      - anomaly_model.joblib (optional)
      - feature_order.json
      - feature_defaults.json
      - thresholds.json
      - metrics.json
      - metadata.json
      - manifest.json
    """
    out = Path(output_dir)
    out.mkdir(parents=True, exist_ok=True)

    # Supervised model (required)
    joblib.dump(model, out / "supervised_model.joblib")

    # Anomaly model (optional)
    if anomaly_model is not None:
        joblib.dump(anomaly_model, out / "anomaly_model.joblib")

    # JSON files
    _write_json(out / "feature_order.json", feature_order)
    _write_json(out / "feature_defaults.json", feature_defaults)
    _write_json(out / "thresholds.json", thresholds)
    _write_json(out / "metrics.json", metrics)
    _write_json(
        out / "metadata.json",
        metadata or {"exported_at": datetime.now(timezone.utc).isoformat()},
    )
    _write_json(out / "manifest.json", manifest)

    return out


def refresh_latest_manifest(domain: str, version_dir: str | Path) -> Path:
    """Copy the versioned manifest.json to artifacts/manifests/<domain>_latest.json.

    This is what the backend's artifact_loader.py reads at startup.
    """
    version_path = Path(version_dir)
    manifest_src = version_path / "manifest.json"
    if not manifest_src.exists():
        raise FileNotFoundError(f"No manifest.json in {version_path}")

    manifests_dir = REPO_ROOT / "artifacts" / "manifests"
    manifests_dir.mkdir(parents=True, exist_ok=True)
    dest = manifests_dir / f"{domain}_latest.json"
    shutil.copy2(manifest_src, dest)
    return dest


def _write_json(path: Path, data: Any) -> None:
    path.write_text(json.dumps(data, indent=2, default=str) + "\n")
