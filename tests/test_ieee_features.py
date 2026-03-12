from app.domains.ieee_cis.features_online import (
    compute_ieee_features,
    build_uid,
    compute_identity_present,
    build_device_signature,
)
from app.state.in_memory import InMemoryStateStore


def test_build_uid():
    uid = build_uid(card1=13926, card2=404.0, card3=150.0, card5=142.0, addr1=315.0, addr2=87.0)
    assert uid == "13926_404.0_150.0_142.0_315.0_87.0"


def test_compute_identity_present_with_device():
    result = compute_identity_present(
        device_type="mobile", device_info="iOS Device",
        id_30="iOS 11.1.2", id_31="mobile safari 11.0", id_33="1334x750",
    )
    assert result == 1


def test_compute_identity_present_no_data():
    result = compute_identity_present(
        device_type=None, device_info=None,
        id_30=None, id_31=None, id_33=None,
    )
    assert result == 0


def test_uid_prior_frequency_no_history():
    store = InMemoryStateStore()
    features = compute_ieee_features(
        transaction_dt=86400, transaction_amt=68.5,
        card1=13926, card2=404.0, card3=150.0, card5=142.0,
        addr1=315.0, addr2=87.0,
        p_emaildomain="gmail.com", r_emaildomain="hotmail.com",
        device_type="mobile", device_info="iOS Device",
        id_30=None, id_31=None, id_33=None,
        store=store,
    )
    assert features["uid_prior_frequency"] == 0


def test_uid_prior_frequency_with_history():
    store = InMemoryStateStore()
    uid = build_uid(13926, 404.0, 150.0, 142.0, 315.0, 87.0)
    store.record_transaction(uid, timestamp=1000, amount=50.0)
    store.record_transaction(uid, timestamp=2000, amount=75.0)
    features = compute_ieee_features(
        transaction_dt=86400, transaction_amt=68.5,
        card1=13926, card2=404.0, card3=150.0, card5=142.0,
        addr1=315.0, addr2=87.0,
        p_emaildomain="gmail.com", r_emaildomain="hotmail.com",
        device_type="mobile", device_info="iOS Device",
        id_30=None, id_31=None, id_33=None,
        store=store,
    )
    assert features["uid_prior_frequency"] == 2


def test_email_domain_mismatch():
    store = InMemoryStateStore()
    features = compute_ieee_features(
        transaction_dt=86400, transaction_amt=68.5,
        card1=1, card2=1.0, card3=1.0, card5=1.0,
        addr1=1.0, addr2=1.0,
        p_emaildomain="gmail.com", r_emaildomain="hotmail.com",
        device_type=None, device_info=None,
        id_30=None, id_31=None, id_33=None,
        store=store,
    )
    assert features["email_domain_mismatch"] == 1


def test_email_domain_match():
    store = InMemoryStateStore()
    features = compute_ieee_features(
        transaction_dt=86400, transaction_amt=68.5,
        card1=1, card2=1.0, card3=1.0, card5=1.0,
        addr1=1.0, addr2=1.0,
        p_emaildomain="gmail.com", r_emaildomain="gmail.com",
        device_type=None, device_info=None,
        id_30=None, id_31=None, id_33=None,
        store=store,
    )
    assert features["email_domain_mismatch"] == 0


def test_email_domain_one_missing():
    store = InMemoryStateStore()
    features = compute_ieee_features(
        transaction_dt=86400, transaction_amt=68.5,
        card1=1, card2=1.0, card3=1.0, card5=1.0,
        addr1=1.0, addr2=1.0,
        p_emaildomain="gmail.com", r_emaildomain=None,
        device_type=None, device_info=None,
        id_30=None, id_31=None, id_33=None,
        store=store,
    )
    assert features["email_domain_mismatch"] == 0


def test_new_device_for_uid_first_time():
    store = InMemoryStateStore()
    features = compute_ieee_features(
        transaction_dt=86400, transaction_amt=68.5,
        card1=1, card2=1.0, card3=1.0, card5=1.0,
        addr1=1.0, addr2=1.0,
        p_emaildomain=None, r_emaildomain=None,
        device_type="mobile", device_info="iOS Device",
        id_30=None, id_31=None, id_33=None,
        store=store,
    )
    assert features["new_device_for_uid"] == 1


def test_new_device_no_device_info():
    store = InMemoryStateStore()
    features = compute_ieee_features(
        transaction_dt=86400, transaction_amt=68.5,
        card1=1, card2=1.0, card3=1.0, card5=1.0,
        addr1=1.0, addr2=1.0,
        p_emaildomain=None, r_emaildomain=None,
        device_type=None, device_info=None,
        id_30=None, id_31=None, id_33=None,
        store=store,
    )
    assert features["new_device_for_uid"] == 0  # neutral when no device info


def test_all_six_features_present():
    store = InMemoryStateStore()
    features = compute_ieee_features(
        transaction_dt=86400, transaction_amt=68.5,
        card1=1, card2=1.0, card3=1.0, card5=1.0,
        addr1=1.0, addr2=1.0,
        p_emaildomain=None, r_emaildomain=None,
        device_type=None, device_info=None,
        id_30=None, id_31=None, id_33=None,
        store=store,
    )
    expected_keys = {
        "uid_prior_frequency", "amt_to_uid_median_ratio",
        "uid_txn_count_24h", "email_domain_mismatch",
        "new_device_for_uid", "identity_present",
    }
    assert set(features.keys()) == expected_keys
