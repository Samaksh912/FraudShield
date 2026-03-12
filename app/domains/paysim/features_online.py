from __future__ import annotations

from app.schemas.common import FEATURE_KEYS_BY_DOMAIN
from app.state.in_memory import InMemoryStateStore
from app.utils.math_utils import clamped_ratio, zscore

RISKY_TYPES = {"TRANSFER", "CASH_OUT"}
HOURS_24 = 24
HOURS_7D = 168


def empty_feature_vector() -> dict[str, float | int]:
    return {name: 0 for name in FEATURE_KEYS_BY_DOMAIN["paysim"]}


def compute_paysim_features(
    step: int,
    txn_type: str,
    amount: float,
    name_orig: str,
    name_dest: str,
    old_balance_org: float,
    new_balance_orig: float | None,
    store: InMemoryStateStore,
) -> dict[str, float | int]:
    # 1. type_risk_flag
    type_risk_flag = 1 if txn_type in RISKY_TYPES else 0

    # 2. amount_to_orig_balance_ratio
    amount_to_orig_balance_ratio = clamped_ratio(amount, old_balance_org, cap=1.0)

    # 3. orig_balance_consistency_error
    if new_balance_orig is not None:
        error = abs(old_balance_org - amount - new_balance_orig)
        orig_balance_consistency_error = clamped_ratio(error, old_balance_org, cap=1.0)
    else:
        orig_balance_consistency_error = 0.0

    # 4. sender_txn_count_24h (causal: only prior txns with step < current step)
    history = store.get_transaction_history(name_orig, before_timestamp=step)
    cutoff = step - HOURS_24
    sender_txn_count_24h = sum(1 for ts in history["timestamps"] if ts >= cutoff)

    # 5. sender_amount_zscore_7d
    cutoff_7d = step - HOURS_7D
    amounts_7d = [
        amt for ts, amt in zip(history["timestamps"], history["amounts"])
        if ts >= cutoff_7d
    ]
    sender_amount_zscore_7d = zscore(amount, amounts_7d)

    # 6. sender_dest_pair_novelty
    sender_dest_pair_novelty = 0 if store.is_in_seen_set(name_orig, "destinations", name_dest) else 1

    return {
        "type_risk_flag": type_risk_flag,
        "amount_to_orig_balance_ratio": round(amount_to_orig_balance_ratio, 4),
        "orig_balance_consistency_error": round(orig_balance_consistency_error, 4),
        "sender_txn_count_24h": sender_txn_count_24h,
        "sender_amount_zscore_7d": round(sender_amount_zscore_7d, 4),
        "sender_dest_pair_novelty": sender_dest_pair_novelty,
    }


def update_paysim_state(
    store: InMemoryStateStore,
    name_orig: str,
    name_dest: str,
    step: int,
    amount: float,
) -> None:
    store.record_transaction(name_orig, timestamp=step, amount=amount)
    store.add_to_seen_set(name_orig, "destinations", name_dest)
