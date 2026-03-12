"""PaySim causal feature engineering for training.

All 9 Phase 1 features, computed causally:
  - DataFrame is sorted by `step`
  - History features use only prior rows (no future leakage)
  - Merchant destinations (nameDest starts with 'M') treated neutrally for
    dest_balance_consistency_error
"""
from __future__ import annotations

import numpy as np
import pandas as pd

EPSILON = 1e-6

# The 9 PaySim training features (superset of 6 MVP online features)
PAYSIM_TRAINING_FEATURES: list[str] = [
    "type_risk_flag",
    "amount_to_orig_balance_ratio",
    "orig_balance_consistency_error",
    "dest_balance_consistency_error",
    "orig_balance_drain_pct",
    "sender_txn_count_24h",
    "sender_amount_zscore_7d",
    "sender_dest_pair_novelty",
    "dest_inbound_txn_count_24h",
]

# The 6 MVP features served online (subset)
PAYSIM_ONLINE_FEATURES: list[str] = [
    "type_risk_flag",
    "amount_to_orig_balance_ratio",
    "orig_balance_consistency_error",
    "sender_txn_count_24h",
    "sender_amount_zscore_7d",
    "sender_dest_pair_novelty",
]

PAYSIM_REQUIRED_RAW_FIELDS: list[str] = [
    "step",
    "type",
    "amount",
    "nameOrig",
    "oldbalanceOrg",
    "newbalanceOrig",
    "nameDest",
    "oldbalanceDest",
    "newbalanceDest",
]

RISKY_TYPES = {"TRANSFER", "CASH_OUT"}
STEPS_24H = 24
STEPS_7D = 168


def build_paysim_features(df: pd.DataFrame) -> pd.DataFrame:
    """Build all 9 PaySim training features causally.

    Args:
        df: Raw PaySim DataFrame with required columns.
            Must contain `isFraud` for training.

    Returns:
        DataFrame with feature columns + `isFraud` target, sorted by step.
    """
    # Validate required columns
    for col in PAYSIM_REQUIRED_RAW_FIELDS:
        if col not in df.columns:
            raise ValueError(f"Missing required column: {col}")

    # Sort by step for causal ordering
    df = df.sort_values("step").reset_index(drop=True)

    # --- Stateless features (vectorized) ---

    # 1. type_risk_flag: 1 if type in {TRANSFER, CASH_OUT}
    df["type_risk_flag"] = df["type"].isin(RISKY_TYPES).astype(int)

    # 2. amount_to_orig_balance_ratio: amount / max(oldbalanceOrg, eps), capped 1.0
    df["amount_to_orig_balance_ratio"] = np.clip(
        df["amount"] / np.maximum(df["oldbalanceOrg"], EPSILON), 0.0, 1.0
    )

    # 3. orig_balance_consistency_error:
    #    abs(oldbalanceOrg - amount - newbalanceOrig) / max(oldbalanceOrg, eps)
    df["orig_balance_consistency_error"] = np.clip(
        np.abs(df["oldbalanceOrg"] - df["amount"] - df["newbalanceOrig"])
        / np.maximum(df["oldbalanceOrg"], EPSILON),
        0.0,
        1.0,
    )

    # 4. dest_balance_consistency_error:
    #    Neutral (0.0) for merchant destinations (nameDest starts with 'M')
    #    Otherwise: abs(oldbalanceDest + amount - newbalanceDest) / max(amount, eps)
    is_merchant = df["nameDest"].str.startswith("M")
    raw_dest_error = np.clip(
        np.abs(df["oldbalanceDest"] + df["amount"] - df["newbalanceDest"])
        / np.maximum(df["amount"], EPSILON),
        0.0,
        1.0,
    )
    df["dest_balance_consistency_error"] = np.where(is_merchant, 0.0, raw_dest_error)

    # 5. orig_balance_drain_pct:
    #    (oldbalanceOrg - newbalanceOrig) / max(oldbalanceOrg, eps) for TRANSFER/CASH_OUT
    #    0.0 otherwise
    is_risky_type = df["type"].isin(RISKY_TYPES)
    raw_drain = np.clip(
        (df["oldbalanceOrg"] - df["newbalanceOrig"])
        / np.maximum(df["oldbalanceOrg"], EPSILON),
        0.0,
        1.0,
    )
    df["orig_balance_drain_pct"] = np.where(is_risky_type, raw_drain, 0.0)

    # 6. email_domain_mismatch: not applicable for PaySim

    # --- History-dependent features (iterative, causal) ---
    sender_txn_count_24h = np.zeros(len(df), dtype=np.int64)
    sender_amount_zscore_7d = np.zeros(len(df), dtype=np.float64)
    sender_dest_pair_novelty = np.zeros(len(df), dtype=np.int64)
    dest_inbound_txn_count_24h = np.zeros(len(df), dtype=np.int64)

    # Per-sender history accumulators
    sender_history: dict[str, list[tuple[int, float]]] = {}  # (step, amount)
    sender_dest_pairs: dict[str, set[str]] = {}

    # Per-dest inbound history
    dest_history: dict[str, list[int]] = {}  # list of steps

    for i in range(len(df)):
        row = df.iloc[i]
        sender = row["nameOrig"]
        dest = row["nameDest"]
        step = int(row["step"])
        amount = float(row["amount"])

        # --- sender_txn_count_24h ---
        hist = sender_history.get(sender, [])
        count_24h = sum(1 for s, _ in hist if step - s <= STEPS_24H)
        sender_txn_count_24h[i] = count_24h

        # --- sender_amount_zscore_7d ---
        amounts_7d = [a for s, a in hist if step - s <= STEPS_7D]
        if len(amounts_7d) >= 2:
            mean_val = np.mean(amounts_7d)
            std_val = np.std(amounts_7d)
            if std_val > EPSILON:
                sender_amount_zscore_7d[i] = (amount - mean_val) / std_val
        # else stays 0.0

        # --- sender_dest_pair_novelty ---
        seen_dests = sender_dest_pairs.get(sender, set())
        sender_dest_pair_novelty[i] = 0 if dest in seen_dests else 1

        # --- dest_inbound_txn_count_24h ---
        dest_hist = dest_history.get(dest, [])
        count_dest_24h = sum(1 for s in dest_hist if step - s <= STEPS_24H)
        dest_inbound_txn_count_24h[i] = count_dest_24h

        # Update accumulators AFTER scoring (causal constraint)
        if sender not in sender_history:
            sender_history[sender] = []
        sender_history[sender].append((step, amount))

        if sender not in sender_dest_pairs:
            sender_dest_pairs[sender] = set()
        sender_dest_pairs[sender].add(dest)

        if dest not in dest_history:
            dest_history[dest] = []
        dest_history[dest].append(step)

    df["sender_txn_count_24h"] = sender_txn_count_24h
    df["sender_amount_zscore_7d"] = sender_amount_zscore_7d
    df["sender_dest_pair_novelty"] = sender_dest_pair_novelty
    df["dest_inbound_txn_count_24h"] = dest_inbound_txn_count_24h

    # Build output
    output_cols = PAYSIM_TRAINING_FEATURES.copy()
    if "isFraud" in df.columns:
        output_cols.append("isFraud")

    return df[output_cols].copy()
