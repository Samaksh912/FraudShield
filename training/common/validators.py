"""Training-side validation helpers."""
from __future__ import annotations

import pandas as pd


def validate_required_columns(columns: list[str], required: list[str]) -> None:
    """Raise if any required columns are missing."""
    missing = [column for column in required if column not in columns]
    if missing:
        raise ValueError(f"Missing required columns: {missing}")


def validate_no_leakage(
    df: pd.DataFrame, target_col: str, feature_cols: list[str]
) -> None:
    """Assert target column is not accidentally among the features."""
    if target_col in feature_cols:
        raise ValueError(
            f"Target column '{target_col}' found in feature list — leakage risk"
        )
    if target_col in df.columns and target_col in feature_cols:
        raise ValueError(f"Target '{target_col}' present in feature columns")


def validate_feature_names(
    actual: list[str], expected: list[str], label: str = "features"
) -> None:
    """Assert exact set equality between actual and expected feature names."""
    actual_set = set(actual)
    expected_set = set(expected)
    if actual_set != expected_set:
        missing = expected_set - actual_set
        extra = actual_set - expected_set
        parts: list[str] = [f"{label} mismatch"]
        if missing:
            parts.append(f"missing={sorted(missing)}")
        if extra:
            parts.append(f"extra={sorted(extra)}")
        raise ValueError("; ".join(parts))
