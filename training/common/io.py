"""Training-side I/O helpers for CSV and parquet files."""
from __future__ import annotations

import csv
from pathlib import Path
from typing import Any

import pandas as pd


def load_tabular(path: str | Path) -> list[dict[str, Any]]:
    """Load CSV or parquet as a list of dicts (legacy helper)."""
    file_path = Path(path)
    suffix = file_path.suffix.lower()
    if suffix == ".csv":
        with file_path.open(newline="") as handle:
            return list(csv.DictReader(handle))
    if suffix == ".parquet":
        return pd.read_parquet(file_path).to_dict(orient="records")
    raise ValueError(f"Unsupported file type: {suffix}")


def load_dataframe(path: str | Path) -> pd.DataFrame:
    """Load CSV or parquet into a pandas DataFrame."""
    file_path = Path(path)
    suffix = file_path.suffix.lower()
    if suffix == ".csv":
        return pd.read_csv(file_path)
    if suffix == ".parquet":
        return pd.read_parquet(file_path)
    raise ValueError(f"Unsupported file type: {suffix}")


def save_dataframe(df: pd.DataFrame, path: str | Path) -> Path:
    """Save DataFrame as parquet. Creates parent dirs."""
    file_path = Path(path)
    file_path.parent.mkdir(parents=True, exist_ok=True)
    df.to_parquet(file_path, index=False)
    return file_path
