from __future__ import annotations

PAYSIM_WEIGHTS: dict[str, float] = {
    "type_risk_flag": 0.20,
    "amount_to_orig_balance_ratio": 0.25,
    "orig_balance_consistency_error": 0.20,
    "sender_txn_count_24h": 0.10,
    "sender_amount_zscore_7d": 0.15,
    "sender_dest_pair_novelty": 0.10,
}

IEEE_CIS_WEIGHTS: dict[str, float] = {
    "uid_prior_frequency": 0.15,
    "amt_to_uid_median_ratio": 0.25,
    "uid_txn_count_24h": 0.10,
    "email_domain_mismatch": 0.15,
    "new_device_for_uid": 0.20,
    "identity_present": 0.15,
}

_PAYSIM_NORMALIZERS: dict[str, str] = {
    "type_risk_flag": "binary",
    "amount_to_orig_balance_ratio": "passthrough",
    "orig_balance_consistency_error": "passthrough",
    "sender_txn_count_24h": "count_20",
    "sender_amount_zscore_7d": "abs_cap_3",
    "sender_dest_pair_novelty": "binary",
}

_IEEE_CIS_NORMALIZERS: dict[str, str] = {
    "uid_prior_frequency": "inv_count_50",
    "amt_to_uid_median_ratio": "cap_5",
    "uid_txn_count_24h": "count_20",
    "email_domain_mismatch": "binary",
    "new_device_for_uid": "binary",
    "identity_present": "inv_binary",
}


def _normalize_value(value: float | int, rule: str) -> float:
    v = float(value)
    if rule == "binary":
        return v
    if rule == "passthrough":
        return v
    if rule == "count_20":
        return min(v, 20.0) / 20.0
    if rule == "abs_cap_3":
        return min(abs(v), 3.0) / 3.0
    if rule == "inv_count_50":
        return 1.0 - min(v, 50.0) / 50.0
    if rule == "cap_5":
        return min(v, 5.0) / 5.0
    if rule == "inv_binary":
        return 1.0 - v
    return v


def normalize_features(
    raw_features: dict[str, float | int | None], domain: str
) -> dict[str, float]:
    normalizers = _PAYSIM_NORMALIZERS if domain == "paysim" else _IEEE_CIS_NORMALIZERS
    result: dict[str, float] = {}
    for feature, rule in normalizers.items():
        raw = raw_features.get(feature, 0)
        if raw is None:
            raw = 0
        result[feature] = _normalize_value(raw, rule)
    return result


def compute_heuristic_score(
    raw_features: dict[str, float | int | None], domain: str
) -> tuple[float, dict[str, float]]:
    weights = PAYSIM_WEIGHTS if domain == "paysim" else IEEE_CIS_WEIGHTS
    normalized = normalize_features(raw_features, domain)
    score = sum(normalized[f] * weights[f] for f in weights)
    return max(0.0, min(1.0, score)), normalized


def risk_level(score: float) -> str:
    if score >= 0.75:
        return "high"
    if score >= 0.4:
        return "medium"
    return "low"


def risk_decision(score: float) -> str:
    if score >= 0.9:
        return "block"
    if score >= 0.4:
        return "review"
    return "allow"
