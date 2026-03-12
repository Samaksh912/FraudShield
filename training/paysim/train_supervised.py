"""PaySim XGBoost supervised training entrypoint."""
from __future__ import annotations

import sys
from datetime import datetime, timezone
from pathlib import Path

import numpy as np
import pandas as pd

from training.common.export import export_artifact_bundle, refresh_latest_manifest
from training.common.io import load_dataframe
from training.common.metrics import (
    compute_classification_metrics,
    print_metrics_report,
    suggest_thresholds,
)
from training.common.splitters import time_based_split
from training.common.validators import validate_no_leakage
from training.paysim.export_artifacts import build_paysim_manifest
from training.paysim.feature_build import (
    PAYSIM_ONLINE_FEATURES,
    PAYSIM_TRAINING_FEATURES,
    build_paysim_features,
)

TARGET_COL = "isFraud"


def _detect_gpu() -> str:
    """Return 'cuda' if GPU available, else 'cpu'."""
    try:
        import xgboost as xgb

        # Try creating a small GPU model — if it fails, fall back to CPU
        test_params = {"device": "cuda", "n_estimators": 1, "max_depth": 1}
        m = xgb.XGBClassifier(**test_params)
        m.fit(np.array([[1, 2]]), np.array([0]))
        return "cuda"
    except Exception:
        return "cpu"


def train_paysim_xgboost(
    data_path: str | Path,
    output_dir: str | Path,
    *,
    artifact_version: str = "v1",
    sample_rows: int | None = None,
    train_ratio: float = 0.8,
    n_estimators: int = 300,
    max_depth: int = 6,
    learning_rate: float = 0.1,
    run_anomaly: bool = False,
) -> Path:
    """Train XGBoost on PaySim data and export artifacts.

    Args:
        data_path: Path to PaySim CSV/parquet.
        output_dir: Where to write artifact bundle.
        artifact_version: Version string for the manifest.
        sample_rows: If set, subsample for quick dry-run validation.
        train_ratio: Fraction of data for training (rest is validation).
        n_estimators: Number of boosting rounds.
        max_depth: Max tree depth.
        learning_rate: XGBoost learning rate.
        run_anomaly: If True, also train Isolation Forest.

    Returns:
        Path to the output directory.
    """
    import xgboost as xgb

    print(f"[PaySim] Loading data from {data_path}")
    df = load_dataframe(data_path)

    if sample_rows is not None:
        print(f"[PaySim] Subsampling to {sample_rows} rows (dry-run mode)")
        df = df.head(sample_rows)

    if TARGET_COL not in df.columns:
        raise ValueError(f"Target column '{TARGET_COL}' not found in data")

    # Feature engineering
    print("[PaySim] Building features...")
    features_df = build_paysim_features(df)

    feature_cols = PAYSIM_TRAINING_FEATURES
    validate_no_leakage(features_df, TARGET_COL, feature_cols)

    # Time-based split (already sorted by step in build_paysim_features)
    print("[PaySim] Splitting data (time-based)...")
    train_df, val_df = time_based_split(
        features_df.reset_index(drop=True),
        time_col=feature_cols[0],  # Will be sorted already, use index split
        train_ratio=train_ratio,
    )
    # Since features_df is already sorted, just do a simple ratio split
    split_idx = int(len(features_df) * train_ratio)
    train_df = features_df.iloc[:split_idx]
    val_df = features_df.iloc[split_idx:]

    X_train = train_df[feature_cols].values
    y_train = train_df[TARGET_COL].values.astype(int)
    X_val = val_df[feature_cols].values
    y_val = val_df[TARGET_COL].values.astype(int)

    # Handle class imbalance
    n_neg = int(np.sum(y_train == 0))
    n_pos = max(int(np.sum(y_train == 1)), 1)
    scale_pos_weight = n_neg / n_pos

    # Detect GPU
    device = _detect_gpu()
    print(f"[PaySim] Training XGBoost ({device}, {n_estimators} rounds)...")

    model = xgb.XGBClassifier(
        n_estimators=n_estimators,
        max_depth=max_depth,
        learning_rate=learning_rate,
        scale_pos_weight=scale_pos_weight,
        device=device,
        eval_metric="aucpr",
        use_label_encoder=False,
        random_state=42,
    )
    model.fit(
        X_train,
        y_train,
        eval_set=[(X_val, y_val)],
        verbose=10,
    )

    # Predict and evaluate
    y_pred_proba = model.predict_proba(X_val)[:, 1]
    metrics = compute_classification_metrics(y_val, y_pred_proba, threshold=0.5)
    print_metrics_report(metrics)

    # Suggest thresholds
    thresholds = suggest_thresholds(y_val, y_pred_proba)
    print(f"[PaySim] Suggested thresholds: {thresholds}")

    # Feature defaults (all zeros — neutral values)
    feature_defaults = {f: 0.0 for f in feature_cols}

    # Build manifest
    manifest = build_paysim_manifest(artifact_version, metrics)

    # Metadata
    metadata = {
        "exported_at": datetime.now(timezone.utc).isoformat(),
        "data_source": str(data_path),
        "sample_rows": sample_rows,
        "train_rows": len(train_df),
        "val_rows": len(val_df),
        "device": device,
        "n_estimators": n_estimators,
        "max_depth": max_depth,
        "learning_rate": learning_rate,
        "scale_pos_weight": round(scale_pos_weight, 2),
    }

    # Optional anomaly model
    anomaly_model = None
    if run_anomaly:
        try:
            from training.paysim.train_anomaly import train_paysim_anomaly

            anomaly_model = train_paysim_anomaly(X_train)
            print("[PaySim] Anomaly model trained successfully")
        except Exception as e:
            print(f"[PaySim] Anomaly training skipped: {e}")

    # Export bundle
    version_dir = Path(output_dir) / "paysim" / artifact_version
    print(f"[PaySim] Exporting artifacts to {version_dir}")
    export_artifact_bundle(
        version_dir,
        model=model,
        manifest=manifest,
        feature_order=feature_cols,
        feature_defaults=feature_defaults,
        thresholds=thresholds,
        metrics=metrics,
        metadata=metadata,
        anomaly_model=anomaly_model,
    )

    # Refresh latest manifest for backend
    latest_path = refresh_latest_manifest("paysim", version_dir)
    print(f"[PaySim] Latest manifest written to {latest_path}")
    print("[PaySim] Training complete!")

    return version_dir


if __name__ == "__main__":
    # CLI entrypoint: python -m training.paysim.train_supervised <data_path> <output_dir> [sample_rows]
    data = sys.argv[1] if len(sys.argv) > 1 else "upi_sample.csv"
    out = sys.argv[2] if len(sys.argv) > 2 else "artifacts"
    sample = int(sys.argv[3]) if len(sys.argv) > 3 else None
    train_paysim_xgboost(data, out, sample_rows=sample)
