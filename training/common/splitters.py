"""Leakage-safe train/validation splitting helpers."""
from __future__ import annotations

from collections.abc import Sequence
from typing import TypeVar

import pandas as pd

T = TypeVar("T")


def time_order_split(
    items: Sequence[T], train_ratio: float = 0.8
) -> tuple[list[T], list[T]]:
    """Split a sequence at a ratio boundary (legacy helper)."""
    if not 0 < train_ratio < 1:
        raise ValueError("train_ratio must be between 0 and 1")
    index = int(len(items) * train_ratio)
    return list(items[:index]), list(items[index:])


def time_based_split(
    df: pd.DataFrame,
    time_col: str,
    train_ratio: float = 0.8,
) -> tuple[pd.DataFrame, pd.DataFrame]:
    """Causal time-based split: sort by time_col, split at ratio.

    Ensures no future rows leak into the training set.
    """
    if time_col not in df.columns:
        raise ValueError(f"Time column '{time_col}' not found in DataFrame")
    if not 0 < train_ratio < 1:
        raise ValueError("train_ratio must be between 0 and 1")
    sorted_df = df.sort_values(time_col).reset_index(drop=True)
    split_idx = int(len(sorted_df) * train_ratio)
    return sorted_df.iloc[:split_idx].copy(), sorted_df.iloc[split_idx:].copy()
