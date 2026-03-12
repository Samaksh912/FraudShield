from __future__ import annotations

import statistics

from app.schemas.common import FEATURE_KEYS_BY_DOMAIN
from app.state.in_memory import InMemoryStateStore
from app.utils.math_utils import clamped_ratio

SECONDS_24H = 86400


def empty_feature_vector() -> dict[str, float | int]:
    return {name: 0 for name in FEATURE_KEYS_BY_DOMAIN["ieee_cis"]}


def build_uid(
    card1: int, card2: float, card3: float,
    card5: float, addr1: float, addr2: float,
) -> str:
    return f"{card1}_{card2}_{card3}_{card5}_{addr1}_{addr2}"


def compute_identity_present(
    device_type: str | None,
    device_info: str | None,
    id_30: str | None,
    id_31: str | None,
    id_33: str | None,
) -> int:
    fields = [device_type, device_info, id_30, id_31, id_33]
    return 1 if any(f is not None for f in fields) else 0


def build_device_signature(
    device_type: str | None, device_info: str | None,
) -> str | None:
    if device_type is None and device_info is None:
        return None
    return f"{device_type or 'unknown'}_{device_info or 'unknown'}"


def compute_ieee_features(
    transaction_dt: int,
    transaction_amt: float,
    card1: int,
    card2: float,
    card3: float,
    card5: float,
    addr1: float,
    addr2: float,
    p_emaildomain: str | None,
    r_emaildomain: str | None,
    device_type: str | None,
    device_info: str | None,
    id_30: str | None,
    id_31: str | None,
    id_33: str | None,
    store: InMemoryStateStore,
) -> dict[str, float | int]:
    uid = build_uid(card1, card2, card3, card5, addr1, addr2)

    # Causal history
    history = store.get_transaction_history(uid, before_timestamp=transaction_dt)

    # 1. uid_prior_frequency
    uid_prior_frequency = len(history["timestamps"])

    # 2. amt_to_uid_median_ratio
    if history["amounts"]:
        median_amt = statistics.median(history["amounts"])
        amt_to_uid_median_ratio = clamped_ratio(transaction_amt, median_amt, cap=5.0)
    else:
        amt_to_uid_median_ratio = 0.0

    # 3. uid_txn_count_24h
    cutoff = transaction_dt - SECONDS_24H
    uid_txn_count_24h = sum(1 for ts in history["timestamps"] if ts >= cutoff)

    # 4. email_domain_mismatch
    if p_emaildomain and r_emaildomain:
        email_domain_mismatch = 1 if p_emaildomain != r_emaildomain else 0
    else:
        email_domain_mismatch = 0

    # 5. new_device_for_uid
    device_sig = build_device_signature(device_type, device_info)
    if device_sig is not None:
        new_device_for_uid = 0 if store.is_in_seen_set(uid, "devices", device_sig) else 1
    else:
        new_device_for_uid = 0  # neutral when no device info

    # 6. identity_present (computed, not from client)
    identity_present_val = compute_identity_present(
        device_type, device_info, id_30, id_31, id_33
    )

    return {
        "uid_prior_frequency": uid_prior_frequency,
        "amt_to_uid_median_ratio": round(amt_to_uid_median_ratio, 4),
        "uid_txn_count_24h": uid_txn_count_24h,
        "email_domain_mismatch": email_domain_mismatch,
        "new_device_for_uid": new_device_for_uid,
        "identity_present": identity_present_val,
    }


def update_ieee_state(
    store: InMemoryStateStore,
    card1: int, card2: float, card3: float,
    card5: float, addr1: float, addr2: float,
    transaction_dt: int, transaction_amt: float,
    device_type: str | None, device_info: str | None,
) -> None:
    uid = build_uid(card1, card2, card3, card5, addr1, addr2)
    store.record_transaction(uid, timestamp=transaction_dt, amount=transaction_amt)
    device_sig = build_device_signature(device_type, device_info)
    if device_sig is not None:
        store.add_to_seen_set(uid, "devices", device_sig)
