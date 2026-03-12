from app.risk.alerts import InMemoryAlertStore, generate_alert


def test_generate_alert_low_risk_no_alert():
    alert = generate_alert(
        score=0.2, level="low", decision="allow",
        domain="paysim", transaction_id="txn_1"
    )
    assert alert is None


def test_generate_alert_medium_review():
    alert = generate_alert(
        score=0.55, level="medium", decision="review",
        domain="paysim", transaction_id="txn_2"
    )
    assert alert is not None
    assert alert.priority.value == "medium"
    assert alert.recommended_action == "manual_review"


def test_generate_alert_high_review():
    alert = generate_alert(
        score=0.85, level="high", decision="review",
        domain="paysim", transaction_id="txn_3"
    )
    assert alert is not None
    assert alert.priority.value == "high"
    assert alert.recommended_action == "step_up_verification"


def test_generate_alert_high_block():
    alert = generate_alert(
        score=0.95, level="high", decision="block",
        domain="ieee_cis", transaction_id="txn_4"
    )
    assert alert is not None
    assert alert.priority.value == "high"
    assert alert.recommended_action == "block_and_review"


def test_alert_store_append_and_list():
    store = InMemoryAlertStore()
    alert = generate_alert(
        score=0.55, level="medium", decision="review",
        domain="paysim", transaction_id="txn_5"
    )
    assert alert is not None
    store.append(alert)
    items = store.list_items()
    assert len(items) == 1
    assert items[0].transaction_id == "txn_5"


def test_alert_id_format():
    alert = generate_alert(
        score=0.8, level="high", decision="review",
        domain="paysim", transaction_id="txn_6"
    )
    assert alert is not None
    assert alert.alert_id.startswith("alrt_")
