import json
from pathlib import Path

from training.common.artifact_manifest import ArtifactManifest


BASE_DIR = Path(__file__).resolve().parents[1]


def test_sample_manifest_validates() -> None:
    raw = json.loads((BASE_DIR / "training" / "kaggle" / "sample_manifest.json").read_text())
    manifest = ArtifactManifest.model_validate(raw)
    assert manifest.domain == "paysim"
    assert manifest.artifact_version == "v1"

