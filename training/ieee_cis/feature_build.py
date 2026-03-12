"""IEEE-CIS causal feature engineering for training.

All 9 Phase 1 features, computed causally:
  - DataFrame is sorted by TransactionDT
  - History features use only prior rows (no future leakage)
  - uid = card1_card2_card3_card5_addr1_addr2
  - identity_present uses serving-parity fields
"""
from __future__ import annotations

import numpy as np
import pandas as pd

EPSILON = 1e-6

# The 9 IEEE-CIS training features
IEEE_CIS_TRAINING_FEATURES: list[str] = [
    "uid_prior_frequency",
    "amt_to_uid_median_ratio",
    "uid_txn_count_24h",
    "uid_amt_sum_24h",
    "uid_product_novelty",
    "email_domain_mismatch",
    "new_device_for_uid",
    "dist1_to_uid_median_ratio",
    "identity_present",
]

# The 6 MVP features served online (subset)
IEEE_CIS_ONLINE_FEATURES: list[str] = [
    "uid_prior_frequency",
    "amt_to_uid_median_ratio",
    "uid_txn_count_24h",
    "email_domain_mismatch",
    "new_device_for_uid",
    "identity_present",
]

IEEE_CIS_REQUIRED_RAW_FIELDS: list[str] = [
    "TransactionID",
    "TransactionDT",
    "TransactionAmt",
    "ProductCD",
    "card1",
    "card2",
    "card3",
    "card5",
    "addr1",
    "addr2",
]

SECONDS_24H = 86400


def _device_signature(row: pd.Series) -> str | None:
    """Build a device signature string from DeviceType + DeviceInfo."""
    dtype = row.get("DeviceType")
    dinfo = row.get("DeviceInfo")
    if pd.isna(dtype) and pd.isna(dinfo):
        return None
    return f"{dtype}_{dinfo}"


def build_ieee_features(df: pd.DataFrame) -> pd.DataFrame:
    """Build all 9 IEEE-CIS training features causally.

    Args:
        df: Joined DataFrame with uid and identity_present already computed
            (from identity_join). Must contain TransactionDT for causal ordering.

    Returns:
        DataFrame with feature columns + isFraud target.
    """
    # Validate
    if "uid" not in df.columns:
        raise ValueError("Missing 'uid' column — run identity_join first")
    if "TransactionDT" not in df.columns:
        raise ValueError("Missing 'TransactionDT' column")

    # Sort by TransactionDT for causal ordering
    df = df.sort_values("TransactionDT").reset_index(drop=True)

    # --- Stateless features (vectorized) ---

    # 6. email_domain_mismatch: 1 if both email domains present and differ
    has_p = df.get("P_emaildomain", pd.Series(dtype=str)).notna()
    has_r = df.get("R_emaildomain", pd.Series(dtype=str)).notna()
    both_present = has_p & has_r
    domains_differ = df.get("P_emaildomain", pd.Series(dtype=str)) != df.get(
        "R_emaildomain", pd.Series(dtype=str)
    )
    df["email_domain_mismatch"] = (both_present & domains_differ).astype(int)

    # 9. identity_present: already computed in identity_join, just carry forward
    if "identity_present" not in df.columns:
        df["identity_present"] = 0

    # --- History-dependent features (iterative, causal) ---
    n = len(df)
    uid_prior_frequency = np.zeros(n, dtype=np.int64)
    amt_to_uid_median_ratio = np.zeros(n, dtype=np.float64)
    uid_txn_count_24h = np.zeros(n, dtype=np.int64)
    uid_amt_sum_24h = np.zeros(n, dtype=np.float64)
    uid_product_novelty = np.zeros(n, dtype=np.int64)
    new_device_for_uid = np.zeros(n, dtype=np.int64)
    dist1_to_uid_median_ratio = np.zeros(n, dtype=np.float64)

    # Per-uid accumulators
    uid_timestamps: dict[str, list[int]] = {}
    uid_amounts: dict[str, list[float]] = {}
    uid_products: dict[str, set[str]] = {}
    uid_devices: dict[str, set[str]] = {}
    uid_dist1_vals: dict[str, list[float]] = {}

    for i in range(n):
        row = df.iloc[i]
        uid = str(row["uid"])
        dt = int(row["TransactionDT"])
        amt = float(row["TransactionAmt"])
        product = str(row.get("ProductCD", ""))

        # Get prior history
        prior_ts = uid_timestamps.get(uid, [])
        prior_amts = uid_amounts.get(uid, [])
        prior_products = uid_products.get(uid, set())
        prior_devices = uid_devices.get(uid, set())
        prior_dist1 = uid_dist1_vals.get(uid, [])

        # 1. uid_prior_frequency: total prior txns
        uid_prior_frequency[i] = len(prior_ts)

        # 2. amt_to_uid_median_ratio: amt / median(prior amounts), capped 5.0
        if len(prior_amts) > 0:
            median_amt = float(np.median(prior_amts))
            amt_to_uid_median_ratio[i] = min(
                amt / max(median_amt, EPSILON), 5.0
            )
        # else stays 0.0

        # 3. uid_txn_count_24h: prior txns within 86400 seconds
        uid_txn_count_24h[i] = sum(1 for t in prior_ts if dt - t <= SECONDS_24H)

        # 4. uid_amt_sum_24h: sum of prior amounts within 86400 seconds
        uid_amt_sum_24h[i] = sum(
            a for t, a in zip(prior_ts, prior_amts) if dt - t <= SECONDS_24H
        )

        # 5. uid_product_novelty: 1 if product not seen before for this uid
        uid_product_novelty[i] = 0 if product in prior_products else 1

        # 7. new_device_for_uid: 1 if device signature not in uid's prior set
        dev_sig = _device_signature(row)
        if dev_sig is not None:
            new_device_for_uid[i] = 0 if dev_sig in prior_devices else 1
        # else stays 0

        # 8. dist1_to_uid_median_ratio: dist1 / median(prior dist1), capped 5.0
        dist1_val = row.get("dist1")
        if pd.notna(dist1_val) and len(prior_dist1) > 0:
            median_dist = float(np.median(prior_dist1))
            dist1_to_uid_median_ratio[i] = min(
                float(dist1_val) / max(median_dist, EPSILON), 5.0
            )
        # else stays 0.0

        # Update accumulators AFTER scoring (causal constraint)
        if uid not in uid_timestamps:
            uid_timestamps[uid] = []
            uid_amounts[uid] = []
            uid_products[uid] = set()
            uid_devices[uid] = set()
            uid_dist1_vals[uid] = []

        uid_timestamps[uid].append(dt)
        uid_amounts[uid].append(amt)
        uid_products[uid].add(product)
        if dev_sig is not None:
            uid_devices[uid].add(dev_sig)
        if pd.notna(dist1_val):
            uid_dist1_vals[uid].append(float(dist1_val))

    df["uid_prior_frequency"] = uid_prior_frequency
    df["amt_to_uid_median_ratio"] = amt_to_uid_median_ratio
    df["uid_txn_count_24h"] = uid_txn_count_24h
    df["uid_amt_sum_24h"] = uid_amt_sum_24h
    df["uid_product_novelty"] = uid_product_novelty
    df["new_device_for_uid"] = new_device_for_uid
    df["dist1_to_uid_median_ratio"] = dist1_to_uid_median_ratio

    # Build output
    output_cols = IEEE_CIS_TRAINING_FEATURES.copy()
    if "isFraud" in df.columns:
        output_cols.append("isFraud")

    return df[output_cols].copy()
