from app.risk.heuristic_scoring import (
    normalize_features,
    compute_heuristic_score,
    PAYSIM_WEIGHTS,
    IEEE_CIS_WEIGHTS,
    risk_level,
    risk_decision,
)


def test_paysim_normalization_binary_passthrough():
    raw = {"type_risk_flag": 1}
    normed = normalize_features(raw, "paysim")
    assert normed["type_risk_flag"] == 1.0


def test_paysim_normalization_count_capped():
    raw = {"sender_txn_count_24h": 30}
    normed = normalize_features(raw, "paysim")
    assert normed["sender_txn_count_24h"] == 1.0  # min(30,20)/20


def test_paysim_normalization_zscore_abs():
    raw = {"sender_amount_zscore_7d": -2.1}
    normed = normalize_features(raw, "paysim")
    assert abs(normed["sender_amount_zscore_7d"] - 2.1 / 3.0) < 0.01


def test_ieee_normalization_frequency_inverted():
    raw = {"uid_prior_frequency": 0}
    normed = normalize_features(raw, "ieee_cis")
    assert normed["uid_prior_frequency"] == 1.0  # 1 - 0/50

    raw2 = {"uid_prior_frequency": 50}
    normed2 = normalize_features(raw2, "ieee_cis")
    assert normed2["uid_prior_frequency"] == 0.0  # 1 - 50/50


def test_ieee_normalization_identity_inverted():
    raw = {"identity_present": 0}
    normed = normalize_features(raw, "ieee_cis")
    assert normed["identity_present"] == 1.0  # 1 - 0

    raw2 = {"identity_present": 1}
    normed2 = normalize_features(raw2, "ieee_cis")
    assert normed2["identity_present"] == 0.0  # 1 - 1


def test_ieee_normalization_ratio_capped():
    raw = {"amt_to_uid_median_ratio": 7.0}
    normed = normalize_features(raw, "ieee_cis")
    assert normed["amt_to_uid_median_ratio"] == 1.0  # min(7,5)/5


def test_compute_heuristic_score_all_zero():
    raw = {
        "type_risk_flag": 0,
        "amount_to_orig_balance_ratio": 0.0,
        "orig_balance_consistency_error": 0.0,
        "sender_txn_count_24h": 0,
        "sender_amount_zscore_7d": 0.0,
        "sender_dest_pair_novelty": 0,
    }
    score, normed = compute_heuristic_score(raw, "paysim")
    assert score == 0.0


def test_compute_heuristic_score_all_max():
    raw = {
        "type_risk_flag": 1,
        "amount_to_orig_balance_ratio": 1.0,
        "orig_balance_consistency_error": 1.0,
        "sender_txn_count_24h": 20,
        "sender_amount_zscore_7d": 3.0,
        "sender_dest_pair_novelty": 1,
    }
    score, normed = compute_heuristic_score(raw, "paysim")
    assert abs(score - 1.0) < 0.01


def test_score_clamped_to_unit():
    # Even with extreme values, score stays in [0, 1]
    raw = {
        "type_risk_flag": 1,
        "amount_to_orig_balance_ratio": 1.0,
        "orig_balance_consistency_error": 1.0,
        "sender_txn_count_24h": 100,
        "sender_amount_zscore_7d": 10.0,
        "sender_dest_pair_novelty": 1,
    }
    score, _ = compute_heuristic_score(raw, "paysim")
    assert 0.0 <= score <= 1.0


def test_paysim_weights_sum_to_one():
    assert abs(sum(PAYSIM_WEIGHTS.values()) - 1.0) < 0.001


def test_ieee_weights_sum_to_one():
    assert abs(sum(IEEE_CIS_WEIGHTS.values()) - 1.0) < 0.001


def test_risk_level_thresholds():
    assert risk_level(0.1) == "low"
    assert risk_level(0.39) == "low"
    assert risk_level(0.4) == "medium"
    assert risk_level(0.74) == "medium"
    assert risk_level(0.75) == "high"
    assert risk_level(1.0) == "high"


def test_risk_decision_thresholds():
    assert risk_decision(0.1) == "allow"
    assert risk_decision(0.39) == "allow"
    assert risk_decision(0.4) == "review"
    assert risk_decision(0.89) == "review"
    assert risk_decision(0.9) == "block"
    assert risk_decision(1.0) == "block"
