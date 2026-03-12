"""IEEE-CIS transaction + identity join, uid construction, identity_present derivation."""
from __future__ import annotations

import numpy as np
import pandas as pd

# Fields used for identity_present — must match Phase 4A serving logic
IDENTITY_PRESENT_FIELDS = ["DeviceType", "DeviceInfo", "id_30", "id_31", "id_33"]

# Fields used for uid construction — full Phase 1 definition
UID_FIELDS = ["card1", "card2", "card3", "card5", "addr1", "addr2"]


def build_uid(df: pd.DataFrame) -> pd.Series:
    """Construct uid from card1 + card2 + card3 + card5 + addr1 + addr2.

    Missing values are filled with 'nan' string so uid is always defined.
    """
    parts = [df[col].astype(str).fillna("nan") for col in UID_FIELDS]
    return parts[0].str.cat(parts[1:], sep="_")


def compute_identity_present(df: pd.DataFrame) -> pd.Series:
    """Compute identity_present: 1 if any of the 5 serving-parity fields is non-null.

    Uses the exact same fields as Phase 4A serving:
      DeviceType, DeviceInfo, id_30, id_31, id_33
    """
    present_cols = [col for col in IDENTITY_PRESENT_FIELDS if col in df.columns]
    if not present_cols:
        return pd.Series(0, index=df.index, dtype=int)
    return df[present_cols].notna().any(axis=1).astype(int)


def join_transaction_identity(
    txn_df: pd.DataFrame,
    identity_df: pd.DataFrame | None = None,
) -> pd.DataFrame:
    """Left join transactions with identity on TransactionID.

    Also computes uid and identity_present.

    Args:
        txn_df: Transaction DataFrame. Must have TransactionID.
        identity_df: Identity DataFrame. If None, identity columns are absent.

    Returns:
        Joined DataFrame with uid and identity_present columns added.
    """
    if identity_df is not None and len(identity_df) > 0:
        # Left join
        merged = txn_df.merge(identity_df, on="TransactionID", how="left")
    else:
        merged = txn_df.copy()

    # Build uid
    for col in UID_FIELDS:
        if col not in merged.columns:
            merged[col] = np.nan
    merged["uid"] = build_uid(merged)

    # Compute identity_present
    merged["identity_present"] = compute_identity_present(merged)

    return merged
