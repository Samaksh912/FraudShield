from app.domains.paysim.features_online import compute_paysim_features
from app.state.in_memory import InMemoryStateStore


def test_type_risk_flag_transfer():
    features = compute_paysim_features(
        step=1, txn_type="TRANSFER", amount=1000.0,
        name_orig="C1", name_dest="C2",
        old_balance_org=5000.0, new_balance_orig=4000.0,
        store=InMemoryStateStore(),
    )
    assert features["type_risk_flag"] == 1


def test_type_risk_flag_payment():
    features = compute_paysim_features(
        step=1, txn_type="PAYMENT", amount=100.0,
        name_orig="C1", name_dest="M1",
        old_balance_org=5000.0, new_balance_orig=4900.0,
        store=InMemoryStateStore(),
    )
    assert features["type_risk_flag"] == 0


def test_amount_to_balance_ratio():
    features = compute_paysim_features(
        step=1, txn_type="TRANSFER", amount=4000.0,
        name_orig="C1", name_dest="C2",
        old_balance_org=5000.0, new_balance_orig=1000.0,
        store=InMemoryStateStore(),
    )
    assert abs(features["amount_to_orig_balance_ratio"] - 0.8) < 0.01


def test_balance_consistency_error():
    # oldbalanceOrg=5000, amount=1000, newbalanceOrig=3500 => error = |5000-1000-3500|/5000 = 0.1
    features = compute_paysim_features(
        step=1, txn_type="TRANSFER", amount=1000.0,
        name_orig="C1", name_dest="C2",
        old_balance_org=5000.0, new_balance_orig=3500.0,
        store=InMemoryStateStore(),
    )
    assert abs(features["orig_balance_consistency_error"] - 0.1) < 0.01


def test_balance_consistency_error_none():
    features = compute_paysim_features(
        step=1, txn_type="TRANSFER", amount=1000.0,
        name_orig="C1", name_dest="C2",
        old_balance_org=5000.0, new_balance_orig=None,
        store=InMemoryStateStore(),
    )
    assert features["orig_balance_consistency_error"] == 0.0


def test_sender_txn_count_24h_with_history():
    store = InMemoryStateStore()
    # Record prior txns at steps 1, 2, 3 (within 24h of step 10)
    store.record_transaction("C1", timestamp=1, amount=100.0)
    store.record_transaction("C1", timestamp=2, amount=200.0)
    store.record_transaction("C1", timestamp=3, amount=300.0)
    features = compute_paysim_features(
        step=10, txn_type="TRANSFER", amount=500.0,
        name_orig="C1", name_dest="C2",
        old_balance_org=5000.0, new_balance_orig=4500.0,
        store=store,
    )
    assert features["sender_txn_count_24h"] == 3


def test_sender_txn_count_24h_excludes_old():
    store = InMemoryStateStore()
    store.record_transaction("C1", timestamp=1, amount=100.0)  # 49 steps ago => outside 24h
    features = compute_paysim_features(
        step=50, txn_type="TRANSFER", amount=500.0,
        name_orig="C1", name_dest="C2",
        old_balance_org=5000.0, new_balance_orig=4500.0,
        store=store,
    )
    assert features["sender_txn_count_24h"] == 0


def test_sender_dest_pair_novelty_first_time():
    store = InMemoryStateStore()
    features = compute_paysim_features(
        step=1, txn_type="TRANSFER", amount=100.0,
        name_orig="C1", name_dest="C2",
        old_balance_org=5000.0, new_balance_orig=4900.0,
        store=store,
    )
    assert features["sender_dest_pair_novelty"] == 1


def test_sender_dest_pair_novelty_known_pair():
    store = InMemoryStateStore()
    store.add_to_seen_set("C1", "destinations", "C2")
    features = compute_paysim_features(
        step=1, txn_type="TRANSFER", amount=100.0,
        name_orig="C1", name_dest="C2",
        old_balance_org=5000.0, new_balance_orig=4900.0,
        store=store,
    )
    assert features["sender_dest_pair_novelty"] == 0


def test_all_six_features_present():
    features = compute_paysim_features(
        step=1, txn_type="TRANSFER", amount=100.0,
        name_orig="C1", name_dest="C2",
        old_balance_org=5000.0, new_balance_orig=4900.0,
        store=InMemoryStateStore(),
    )
    expected_keys = {
        "type_risk_flag", "amount_to_orig_balance_ratio",
        "orig_balance_consistency_error", "sender_txn_count_24h",
        "sender_amount_zscore_7d", "sender_dest_pair_novelty",
    }
    assert set(features.keys()) == expected_keys
