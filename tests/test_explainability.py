from app.domains.paysim.explanations import PAYSIM_SIGNALS
from app.risk.explainability import evaluate_signals, build_explanations


def test_evaluate_signals_fires_on_above_threshold():
    features = {"amount_to_orig_balance_ratio": 0.85}
    signals = evaluate_signals(features, PAYSIM_SIGNALS)
    codes = [s.code for s in signals]
    assert "HIGH_AMOUNT_TO_BALANCE_RATIO" in codes


def test_evaluate_signals_does_not_fire_below_threshold():
    features = {"amount_to_orig_balance_ratio": 0.3}
    signals = evaluate_signals(features, PAYSIM_SIGNALS)
    codes = [s.code for s in signals]
    assert "HIGH_AMOUNT_TO_BALANCE_RATIO" not in codes


def test_evaluate_signals_above_abs_direction():
    features = {"sender_amount_zscore_7d": -2.5}
    signals = evaluate_signals(features, PAYSIM_SIGNALS)
    codes = [s.code for s in signals]
    assert "UNUSUAL_AMOUNT" in codes


def test_evaluate_signals_below_direction():
    from app.domains.ieee_cis.explanations import IEEE_CIS_SIGNALS
    features = {"uid_prior_frequency": 1}
    signals = evaluate_signals(features, IEEE_CIS_SIGNALS)
    codes = [s.code for s in signals]
    assert "LOW_UID_HISTORY" in codes


def test_evaluate_signals_below_does_not_fire_when_above():
    from app.domains.ieee_cis.explanations import IEEE_CIS_SIGNALS
    features = {"uid_prior_frequency": 10}
    signals = evaluate_signals(features, IEEE_CIS_SIGNALS)
    codes = [s.code for s in signals]
    assert "LOW_UID_HISTORY" not in codes


def test_build_explanations_with_signals():
    features = {
        "type_risk_flag": 1,
        "amount_to_orig_balance_ratio": 0.85,
        "orig_balance_consistency_error": 0.0,
        "sender_txn_count_24h": 3,
        "sender_amount_zscore_7d": 1.0,
        "sender_dest_pair_novelty": 1,
    }
    normalized = {
        "type_risk_flag": 1.0,
        "amount_to_orig_balance_ratio": 0.85,
        "orig_balance_consistency_error": 0.0,
        "sender_txn_count_24h": 0.15,
        "sender_amount_zscore_7d": 0.333,
        "sender_dest_pair_novelty": 1.0,
    }
    weights = {
        "type_risk_flag": 0.20,
        "amount_to_orig_balance_ratio": 0.25,
        "orig_balance_consistency_error": 0.20,
        "sender_txn_count_24h": 0.10,
        "sender_amount_zscore_7d": 0.15,
        "sender_dest_pair_novelty": 0.10,
    }
    signals = evaluate_signals(features, PAYSIM_SIGNALS)
    explanation = build_explanations(features, normalized, weights, signals)
    assert len(explanation.top_reasons) > 0
    assert len(explanation.feature_contributions) > 0
    # contributions sorted by abs(impact) descending
    impacts = [c.impact for c in explanation.feature_contributions]
    assert impacts == sorted(impacts, key=abs, reverse=True)


def test_build_explanations_no_signals():
    features = {
        "type_risk_flag": 0,
        "amount_to_orig_balance_ratio": 0.01,
        "orig_balance_consistency_error": 0.0,
        "sender_txn_count_24h": 0,
        "sender_amount_zscore_7d": 0.0,
        "sender_dest_pair_novelty": 0,
    }
    normalized = {k: 0.0 for k in features}
    weights = {k: 0.1 for k in features}
    signals = evaluate_signals(features, PAYSIM_SIGNALS)
    explanation = build_explanations(features, normalized, weights, signals)
    assert explanation.top_reasons == ["Transaction appears normal based on available data."]
    assert explanation.feature_contributions == []
