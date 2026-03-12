"""Tests for IEEE-CIS identity join and causal feature engineering."""
from __future__ import annotations

import numpy as np
import pandas as pd
import pytest

from training.ieee_cis.feature_build import (
    IEEE_CIS_TRAINING_FEATURES,
    build_ieee_features,
)
from training.ieee_cis.identity_join import (
    IDENTITY_PRESENT_FIELDS,
    UID_FIELDS,
    build_uid,
    compute_identity_present,
    join_transaction_identity,
)


def _make_txn_df(rows: list[dict]) -> pd.DataFrame:
    """Create a minimal IEEE-CIS transaction DataFrame."""
    defaults = {
        "TransactionID": 1,
        "TransactionDT": 86400,
        "TransactionAmt": 100.0,
        "ProductCD": "W",
        "card1": 1000,
        "card2": 200.0,
        "card3": 150.0,
        "card5": 224.0,
        "addr1": 315.0,
        "addr2": 87.0,
        "isFraud": 0,
    }
    full_rows = []
    for i, r in enumerate(rows):
        row = {**defaults, "TransactionID": i + 1, **r}
        full_rows.append(row)
    return pd.DataFrame(full_rows)


def _make_identity_df(rows: list[dict]) -> pd.DataFrame:
    """Create a minimal identity DataFrame."""
    return pd.DataFrame(rows)


# --- identity_join tests ---


def test_uid_construction() -> None:
    df = pd.DataFrame({
        "card1": [1000], "card2": [200.0], "card3": [150.0],
        "card5": [224.0], "addr1": [315.0], "addr2": [87.0],
    })
    uid = build_uid(df)
    assert uid.iloc[0] == "1000_200.0_150.0_224.0_315.0_87.0"


def test_uid_with_missing_fields() -> None:
    df = pd.DataFrame({
        "card1": [1000], "card2": [np.nan], "card3": [150.0],
        "card5": [224.0], "addr1": [np.nan], "addr2": [87.0],
    })
    uid = build_uid(df)
    assert "nan" in uid.iloc[0]  # Missing values become "nan"


def test_identity_present_serving_parity() -> None:
    """identity_present should use the exact 5 fields from Phase 4A serving."""
    assert IDENTITY_PRESENT_FIELDS == ["DeviceType", "DeviceInfo", "id_30", "id_31", "id_33"]


def test_identity_present_all_null() -> None:
    df = pd.DataFrame({"DeviceType": [None], "DeviceInfo": [None], "id_30": [None], "id_31": [None], "id_33": [None]})
    result = compute_identity_present(df)
    assert result.iloc[0] == 0


def test_identity_present_some_present() -> None:
    df = pd.DataFrame({"DeviceType": ["mobile"], "DeviceInfo": [None], "id_30": [None], "id_31": [None], "id_33": [None]})
    result = compute_identity_present(df)
    assert result.iloc[0] == 1


def test_join_transaction_identity() -> None:
    txn_df = _make_txn_df([{"TransactionID": 1}, {"TransactionID": 2}])
    identity_df = _make_identity_df([
        {"TransactionID": 1, "DeviceType": "mobile", "DeviceInfo": "iPhone"},
    ])
    joined = join_transaction_identity(txn_df, identity_df)
    assert "uid" in joined.columns
    assert "identity_present" in joined.columns
    assert joined.loc[joined["TransactionID"] == 1, "identity_present"].iloc[0] == 1
    assert joined.loc[joined["TransactionID"] == 2, "identity_present"].iloc[0] == 0


def test_join_without_identity() -> None:
    txn_df = _make_txn_df([{}])
    joined = join_transaction_identity(txn_df, None)
    assert "uid" in joined.columns
    assert "identity_present" in joined.columns
    assert joined["identity_present"].iloc[0] == 0


# --- feature_build tests ---


def test_all_9_features_present() -> None:
    txn_df = _make_txn_df([{}])
    joined = join_transaction_identity(txn_df, None)
    result = build_ieee_features(joined)
    for feat in IEEE_CIS_TRAINING_FEATURES:
        assert feat in result.columns, f"Missing feature: {feat}"


def test_email_domain_mismatch() -> None:
    txn_df = _make_txn_df([
        {"P_emaildomain": "gmail.com", "R_emaildomain": "yahoo.com"},
        {"P_emaildomain": "gmail.com", "R_emaildomain": "gmail.com"},
        {"P_emaildomain": "gmail.com"},  # R missing
    ])
    joined = join_transaction_identity(txn_df, None)
    result = build_ieee_features(joined)
    mismatch = list(result["email_domain_mismatch"])
    assert mismatch[0] == 1  # different domains
    assert mismatch[1] == 0  # same domain
    assert mismatch[2] == 0  # R missing → no mismatch


def test_uid_prior_frequency_causal() -> None:
    txn_df = _make_txn_df([
        {"TransactionDT": 100, "card1": 1000},
        {"TransactionDT": 200, "card1": 1000},
        {"TransactionDT": 300, "card1": 1000},
    ])
    joined = join_transaction_identity(txn_df, None)
    result = build_ieee_features(joined)
    freqs = list(result["uid_prior_frequency"])
    assert freqs[0] == 0  # no prior
    assert freqs[1] == 1  # 1 prior
    assert freqs[2] == 2  # 2 prior


def test_uid_product_novelty() -> None:
    txn_df = _make_txn_df([
        {"TransactionDT": 100, "card1": 1000, "ProductCD": "W"},
        {"TransactionDT": 200, "card1": 1000, "ProductCD": "W"},  # repeat
        {"TransactionDT": 300, "card1": 1000, "ProductCD": "C"},  # new
    ])
    joined = join_transaction_identity(txn_df, None)
    result = build_ieee_features(joined)
    novelty = list(result["uid_product_novelty"])
    assert novelty[0] == 1  # first time
    assert novelty[1] == 0  # repeat
    assert novelty[2] == 1  # new product


def test_no_future_leakage() -> None:
    """Transactions should not use future rows for history features."""
    txn_df = _make_txn_df([
        {"TransactionDT": 999, "card1": 1000, "TransactionAmt": 9999},
        {"TransactionDT": 1, "card1": 1000, "TransactionAmt": 10},
    ])
    joined = join_transaction_identity(txn_df, None)
    result = build_ieee_features(joined)
    # After sorting by TransactionDT, row with DT=1 comes first
    assert result["uid_prior_frequency"].iloc[0] == 0


def test_new_device_for_uid() -> None:
    txn_df = _make_txn_df([
        {"TransactionDT": 100, "card1": 1000},
        {"TransactionDT": 200, "card1": 1000},
    ])
    identity_df = _make_identity_df([
        {"TransactionID": 1, "DeviceType": "mobile", "DeviceInfo": "iPhone"},
        {"TransactionID": 2, "DeviceType": "mobile", "DeviceInfo": "iPhone"},  # same device
    ])
    joined = join_transaction_identity(txn_df, identity_df)
    result = build_ieee_features(joined)
    devices = list(result["new_device_for_uid"])
    assert devices[0] == 1  # first device → new
    assert devices[1] == 0  # same device → not new
