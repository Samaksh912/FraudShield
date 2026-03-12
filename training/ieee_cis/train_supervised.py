"""IEEE-CIS XGBoost supervised training entrypoint."""
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
from training.common.validators import validate_no_leakage
from training.ieee_cis.export_artifacts import build_ieee_manifest
from training.ieee_cis.feature_build import (
    IEEE_CIS_ONLINE_FEATURES,
    IEEE_CIS_TRAINING_FEATURES,
    build_ieee_features,
)
from training.ieee_cis.identity_join import join_transaction_identity

TARGET_COL = "isFraud"


def _detect_gpu() -> str:
    """Return 'cuda' if GPU available, else 'cpu'."""
    try:
        import xgboost as xgb

        test_params = {"device": "cuda", "n_estimators": 1, "max_depth": 1}
        m = xgb.XGBClassifier(**test_params)
        m.fit(np.array([[1, 2]]), np.array([0]))
        return "cuda"
    except Exception:
        return "cpu"


def train_ieee_xgboost(
    txn_path: str | Path,
    output_dir: str | Path,
    *,
    identity_path: str | Path | None = None,
    artifact_version: str = "v1",
    sample_rows: int | None = None,
    train_ratio: float = 0.8,
    n_estimators: int = 300,
    max_depth: int = 6,
    learning_rate: float = 0.1,
    run_anomaly: bool = False,
) -> Path:
    """Train XGBoost on IEEE-CIS data and export artifacts.

    Args:
        txn_path: Path to transaction CSV/parquet.
        output_dir: Where to write artifact bundle.
        identity_path: Optional path to identity CSV/parquet for join.
        artifact_version: Version string for the manifest.
        sample_rows: If set, subsample for quick dry-run validation.
        train_ratio: Fraction of data for training.
        n_estimators: Number of boosting rounds.
        max_depth: Max tree depth.
        learning_rate: XGBoost learning rate.
        run_anomaly: If True, also train Isolation Forest.

    Returns:
        Path to the output directory.
    """
    import xgboost as xgb

    print(f"[IEEE-CIS] Loading transaction data from {txn_path}")
    txn_df = load_dataframe(txn_path)

    identity_df = None
    if identity_path is not None:
        print(f"[IEEE-CIS] Loading identity data from {identity_path}")
        identity_df = load_dataframe(identity_path)

    if sample_rows is not None:
        print(f"[IEEE-CIS] Subsampling to {sample_rows} rows (dry-run mode)")
        txn_df = txn_df.head(sample_rows)
        if identity_df is not None:
            # Keep only identity rows matching sampled transactions
            identity_df = identity_df[
                identity_df["TransactionID"].isin(txn_df["TransactionID"])
            ]

    if TARGET_COL not in txn_df.columns:
        raise ValueError(f"Target column '{TARGET_COL}' not found in data")

    # Join transaction + identity
    print("[IEEE-CIS] Joining transaction + identity...")
    joined_df = join_transaction_identity(txn_df, identity_df)

    # Feature engineering
    print("[IEEE-CIS] Building features...")
    features_df = build_ieee_features(joined_df)

    feature_cols = IEEE_CIS_TRAINING_FEATURES
    validate_no_leakage(features_df, TARGET_COL, feature_cols)

    # Time-based split: features_df is already sorted by TransactionDT
    print("[IEEE-CIS] Splitting data (time-based)...")
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
    print(f"[IEEE-CIS] Training XGBoost ({device}, {n_estimators} rounds)...")

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
    print(f"[IEEE-CIS] Suggested thresholds: {thresholds}")

    # Feature defaults
    feature_defaults = {f: 0.0 for f in feature_cols}

    # Build manifest
    manifest = build_ieee_manifest(artifact_version, metrics)

    # Metadata
    metadata = {
        "exported_at": datetime.now(timezone.utc).isoformat(),
        "txn_data_source": str(txn_path),
        "identity_data_source": str(identity_path) if identity_path else None,
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
            from training.ieee_cis.train_anomaly import train_ieee_anomaly

            anomaly_model = train_ieee_anomaly(X_train)
            print("[IEEE-CIS] Anomaly model trained successfully")
        except Exception as e:
            print(f"[IEEE-CIS] Anomaly training skipped: {e}")

    # Export bundle
    version_dir = Path(output_dir) / "ieee_cis" / artifact_version
    print(f"[IEEE-CIS] Exporting artifacts to {version_dir}")
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
    latest_path = refresh_latest_manifest("ieee_cis", version_dir)
    print(f"[IEEE-CIS] Latest manifest written to {latest_path}")
    print("[IEEE-CIS] Training complete!")

    return version_dir


if __name__ == "__main__":
    # CLI: python -m training.ieee_cis.train_supervised <txn_path> <output_dir> [identity_path] [sample_rows]
    txn = sys.argv[1] if len(sys.argv) > 1 else "ieee_transaction_sample.csv"
    out = sys.argv[2] if len(sys.argv) > 2 else "artifacts"
    identity = sys.argv[3] if len(sys.argv) > 3 else None
    sample = int(sys.argv[4]) if len(sys.argv) > 4 else None
    train_ieee_xgboost(txn, out, identity_path=identity, sample_rows=sample)
