"""Tests for training/common/ utilities."""
from __future__ import annotations

import json
import tempfile
from pathlib import Path

import numpy as np
import pandas as pd
import pytest

from training.common.io import load_dataframe, load_tabular, save_dataframe
from training.common.metrics import compute_classification_metrics, suggest_thresholds
from training.common.splitters import time_based_split, time_order_split
from training.common.validators import (
    validate_feature_names,
    validate_no_leakage,
    validate_required_columns,
)


# --- io tests ---


def test_load_dataframe_csv(tmp_path: Path) -> None:
    csv_file = tmp_path / "test.csv"
    csv_file.write_text("a,b\n1,2\n3,4\n")
    df = load_dataframe(csv_file)
    assert len(df) == 2
    assert list(df.columns) == ["a", "b"]


def test_load_dataframe_parquet(tmp_path: Path) -> None:
    parquet_file = tmp_path / "test.parquet"
    pd.DataFrame({"x": [10, 20]}).to_parquet(parquet_file)
    df = load_dataframe(parquet_file)
    assert len(df) == 2


def test_save_dataframe(tmp_path: Path) -> None:
    df = pd.DataFrame({"c": [1, 2, 3]})
    out = save_dataframe(df, tmp_path / "sub" / "out.parquet")
    assert out.exists()
    loaded = pd.read_parquet(out)
    assert len(loaded) == 3


def test_load_tabular_csv(tmp_path: Path) -> None:
    csv_file = tmp_path / "t.csv"
    csv_file.write_text("col1,col2\na,b\n")
    rows = load_tabular(csv_file)
    assert rows == [{"col1": "a", "col2": "b"}]


# --- validators tests ---


def test_validate_required_columns_pass() -> None:
    validate_required_columns(["a", "b", "c"], ["a", "b"])


def test_validate_required_columns_fail() -> None:
    with pytest.raises(ValueError, match="Missing required columns"):
        validate_required_columns(["a"], ["a", "b"])


def test_validate_no_leakage_pass() -> None:
    df = pd.DataFrame({"feat1": [1], "target": [0]})
    validate_no_leakage(df, "target", ["feat1"])


def test_validate_no_leakage_fail() -> None:
    df = pd.DataFrame({"feat1": [1], "target": [0]})
    with pytest.raises(ValueError, match="leakage"):
        validate_no_leakage(df, "target", ["feat1", "target"])


def test_validate_feature_names_pass() -> None:
    validate_feature_names(["a", "b"], ["b", "a"])


def test_validate_feature_names_fail() -> None:
    with pytest.raises(ValueError, match="mismatch"):
        validate_feature_names(["a"], ["a", "b"])


# --- splitters tests ---


def test_time_order_split() -> None:
    items = list(range(10))
    train, val = time_order_split(items, 0.8)
    assert len(train) == 8
    assert len(val) == 2
    assert train[-1] < val[0]


def test_time_based_split() -> None:
    df = pd.DataFrame({"time": [5, 1, 3, 2, 4], "val": [50, 10, 30, 20, 40]})
    train, val = time_based_split(df, "time", 0.6)
    assert len(train) == 3
    assert len(val) == 2
    # Train should have earlier timestamps
    assert train["time"].max() <= val["time"].min()


def test_time_based_split_missing_col() -> None:
    df = pd.DataFrame({"a": [1, 2]})
    with pytest.raises(ValueError, match="not found"):
        time_based_split(df, "missing_col")


# --- metrics tests ---


def test_compute_classification_metrics() -> None:
    y_true = np.array([0, 0, 1, 1, 1])
    y_proba = np.array([0.1, 0.3, 0.6, 0.8, 0.9])
    m = compute_classification_metrics(y_true, y_proba, threshold=0.5)
    assert "precision" in m
    assert "recall" in m
    assert "f1" in m
    assert "pr_auc" in m
    assert "confusion_matrix" in m
    assert 0.0 <= m["precision"] <= 1.0
    assert 0.0 <= m["recall"] <= 1.0


def test_suggest_thresholds() -> None:
    y_true = np.array([0] * 50 + [1] * 50)
    y_proba = np.concatenate([np.random.uniform(0, 0.5, 50), np.random.uniform(0.5, 1, 50)])
    t = suggest_thresholds(y_true, y_proba)
    assert "level" in t
    assert "decision" in t
    assert "low_to_medium" in t["level"]
    assert "medium_to_high" in t["level"]
    assert "allow_to_review" in t["decision"]
    assert "review_to_block" in t["decision"]


# --- export tests ---


class _MockModel:
    """Module-level mock so joblib can pickle it."""
    pass


def test_export_artifact_bundle(tmp_path: Path) -> None:
    from training.common.export import export_artifact_bundle

    out = export_artifact_bundle(
        tmp_path / "test_bundle",
        model=_MockModel(),
        manifest={"domain": "test", "artifact_version": "v1"},
        feature_order=["f1", "f2"],
        feature_defaults={"f1": 0.0, "f2": 0.0},
        thresholds={"level": {"low_to_medium": 0.4}},
        metrics={"precision": 0.9},
        metadata={"note": "test"},
    )
    assert (out / "supervised_model.joblib").exists()
    assert (out / "manifest.json").exists()
    assert (out / "feature_order.json").exists()
    assert (out / "thresholds.json").exists()
    assert (out / "metrics.json").exists()
    assert (out / "metadata.json").exists()

    # Verify JSON content
    manifest = json.loads((out / "manifest.json").read_text())
    assert manifest["domain"] == "test"
