from app.state.in_memory import InMemoryStateStore


def test_record_and_get_txn_history():
    store = InMemoryStateStore()
    store.record_transaction("sender_A", timestamp=10, amount=100.0)
    store.record_transaction("sender_A", timestamp=20, amount=200.0)
    history = store.get_transaction_history("sender_A")
    assert len(history["timestamps"]) == 2
    assert history["amounts"] == [100.0, 200.0]


def test_get_empty_history():
    store = InMemoryStateStore()
    history = store.get_transaction_history("unknown")
    assert history["timestamps"] == []
    assert history["amounts"] == []


def test_seen_set_operations():
    store = InMemoryStateStore()
    assert not store.is_in_seen_set("sender_A", "destinations", "dest_1")
    store.add_to_seen_set("sender_A", "destinations", "dest_1")
    assert store.is_in_seen_set("sender_A", "destinations", "dest_1")
    assert not store.is_in_seen_set("sender_A", "destinations", "dest_2")


def test_causal_filter_timestamps():
    store = InMemoryStateStore()
    store.record_transaction("s1", timestamp=10, amount=100.0)
    store.record_transaction("s1", timestamp=20, amount=200.0)
    store.record_transaction("s1", timestamp=30, amount=300.0)
    history = store.get_transaction_history("s1", before_timestamp=25)
    assert history["timestamps"] == [10, 20]
    assert history["amounts"] == [100.0, 200.0]


def test_separate_entities():
    store = InMemoryStateStore()
    store.record_transaction("A", timestamp=1, amount=10.0)
    store.record_transaction("B", timestamp=2, amount=20.0)
    assert len(store.get_transaction_history("A")["timestamps"]) == 1
    assert len(store.get_transaction_history("B")["timestamps"]) == 1
