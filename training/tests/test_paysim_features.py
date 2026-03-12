"""Tests for PaySim causal feature engineering."""
from __future__ import annotations

import numpy as np
import pandas as pd
import pytest

from training.paysim.feature_build import (
    PAYSIM_TRAINING_FEATURES,
    build_paysim_features,
)


def _make_paysim_df(rows: list[dict]) -> pd.DataFrame:
    """Create a minimal PaySim DataFrame from row dicts."""
    defaults = {
        "step": 1,
        "type": "TRANSFER",
        "amount": 100.0,
        "nameOrig": "C_sender",
        "oldbalanceOrg": 1000.0,
        "newbalanceOrig": 900.0,
        "nameDest": "C_receiver",
        "oldbalanceDest": 500.0,
        "newbalanceDest": 600.0,
        "isFraud": 0,
    }
    full_rows = [{**defaults, **r} for r in rows]
    return pd.DataFrame(full_rows)


def test_all_9_features_present() -> None:
    df = _make_paysim_df([{}])
    result = build_paysim_features(df)
    for feat in PAYSIM_TRAINING_FEATURES:
        assert feat in result.columns, f"Missing feature: {feat}"


def test_type_risk_flag() -> None:
    df = _make_paysim_df([
        {"type": "TRANSFER"},
        {"type": "CASH_OUT"},
        {"type": "PAYMENT"},
        {"type": "CASH_IN"},
        {"type": "DEBIT"},
    ])
    result = build_paysim_features(df)
    assert list(result["type_risk_flag"]) == [1, 1, 0, 0, 0]


def test_amount_to_orig_balance_ratio() -> None:
    df = _make_paysim_df([
        {"amount": 500, "oldbalanceOrg": 1000},  # ratio = 0.5
        {"amount": 2000, "oldbalanceOrg": 1000},  # capped at 1.0
        {"amount": 0, "oldbalanceOrg": 1000},  # ratio = 0.0
    ])
    result = build_paysim_features(df)
    ratios = list(result["amount_to_orig_balance_ratio"])
    assert abs(ratios[0] - 0.5) < 0.01
    assert ratios[1] == 1.0
    assert ratios[2] == 0.0


def test_orig_balance_consistency_error() -> None:
    # Consistent: 1000 - 100 = 900 → error = 0
    df = _make_paysim_df([
        {"oldbalanceOrg": 1000, "amount": 100, "newbalanceOrig": 900},
    ])
    result = build_paysim_features(df)
    assert result["orig_balance_consistency_error"].iloc[0] < 0.01

    # Inconsistent: 1000 - 100 ≠ 500 → error > 0
    df2 = _make_paysim_df([
        {"oldbalanceOrg": 1000, "amount": 100, "newbalanceOrig": 500},
    ])
    result2 = build_paysim_features(df2)
    assert result2["orig_balance_consistency_error"].iloc[0] > 0.01


def test_dest_balance_consistency_error_merchant_neutral() -> None:
    """Merchant destinations (M-prefixed) should have 0.0 error."""
    df = _make_paysim_df([
        {"nameDest": "M_merchant1", "oldbalanceDest": 0, "newbalanceDest": 0, "amount": 100},
    ])
    result = build_paysim_features(df)
    assert result["dest_balance_consistency_error"].iloc[0] == 0.0


def test_dest_balance_consistency_error_non_merchant() -> None:
    """Non-merchant destinations should compute actual error."""
    df = _make_paysim_df([
        {"nameDest": "C_receiver", "oldbalanceDest": 500, "newbalanceDest": 700, "amount": 100},
    ])
    result = build_paysim_features(df)
    # 500 + 100 - 700 = -100, abs = 100, / max(100, eps) = 1.0
    assert result["dest_balance_consistency_error"].iloc[0] > 0.0


def test_orig_balance_drain_pct_transfer() -> None:
    """TRANSFER type: (oldbal - newbal) / oldbal."""
    df = _make_paysim_df([
        {"type": "TRANSFER", "oldbalanceOrg": 1000, "newbalanceOrig": 200},
    ])
    result = build_paysim_features(df)
    # (1000 - 200) / 1000 = 0.8
    assert abs(result["orig_balance_drain_pct"].iloc[0] - 0.8) < 0.01


def test_orig_balance_drain_pct_non_transfer() -> None:
    """Non-TRANSFER/CASH_OUT types should have drain_pct = 0.0."""
    df = _make_paysim_df([
        {"type": "PAYMENT", "oldbalanceOrg": 1000, "newbalanceOrig": 200},
    ])
    result = build_paysim_features(df)
    assert result["orig_balance_drain_pct"].iloc[0] == 0.0


def test_sender_txn_count_24h_causal() -> None:
    """History features should only count prior transactions."""
    df = _make_paysim_df([
        {"step": 1, "nameOrig": "C_A", "amount": 10},
        {"step": 10, "nameOrig": "C_A", "amount": 20},
        {"step": 20, "nameOrig": "C_A", "amount": 30},
    ])
    result = build_paysim_features(df)
    counts = list(result["sender_txn_count_24h"])
    assert counts[0] == 0  # no prior txns
    assert counts[1] == 1  # 1 prior txn
    assert counts[2] == 2  # 2 prior txns


def test_sender_dest_pair_novelty() -> None:
    df = _make_paysim_df([
        {"step": 1, "nameOrig": "C_A", "nameDest": "C_B"},
        {"step": 2, "nameOrig": "C_A", "nameDest": "C_B"},  # repeat
        {"step": 3, "nameOrig": "C_A", "nameDest": "C_C"},  # new dest
    ])
    result = build_paysim_features(df)
    novelty = list(result["sender_dest_pair_novelty"])
    assert novelty[0] == 1  # first time seeing C_B
    assert novelty[1] == 0  # already seen C_B
    assert novelty[2] == 1  # first time seeing C_C


def test_no_future_leakage() -> None:
    """Transactions should not use information from future rows."""
    df = _make_paysim_df([
        {"step": 100, "nameOrig": "C_A", "amount": 999},
        {"step": 1, "nameOrig": "C_A", "amount": 10},
    ])
    result = build_paysim_features(df)
    # After sorting by step, step=1 comes first and should have 0 prior txns
    assert result["sender_txn_count_24h"].iloc[0] == 0
