from __future__ import annotations

from typing import Any

from app.state.store import StateStore


class InMemoryStateStore(StateStore):
    def __init__(self) -> None:
        self._data: dict[str, Any] = {}
        self._histories: dict[str, dict[str, list]] = {}
        self._seen_sets: dict[str, dict[str, set[str]]] = {}

    def get(self, key: str, default: Any = None) -> Any:
        return self._data.get(key, default)

    def set(self, key: str, value: Any) -> None:
        self._data[key] = value

    def record_transaction(self, entity_id: str, timestamp: int, amount: float) -> None:
        if entity_id not in self._histories:
            self._histories[entity_id] = {"timestamps": [], "amounts": []}
        self._histories[entity_id]["timestamps"].append(timestamp)
        self._histories[entity_id]["amounts"].append(amount)

    def get_transaction_history(
        self, entity_id: str, before_timestamp: int | None = None
    ) -> dict[str, list]:
        empty: dict[str, list] = {"timestamps": [], "amounts": []}
        history = self._histories.get(entity_id, empty)
        if before_timestamp is None:
            return history
        filtered_ts: list[int] = []
        filtered_amts: list[float] = []
        for ts, amt in zip(history["timestamps"], history["amounts"]):
            if ts < before_timestamp:
                filtered_ts.append(ts)
                filtered_amts.append(amt)
        return {"timestamps": filtered_ts, "amounts": filtered_amts}

    def is_in_seen_set(self, entity_id: str, set_name: str, value: str) -> bool:
        return value in self._seen_sets.get(entity_id, {}).get(set_name, set())

    def add_to_seen_set(self, entity_id: str, set_name: str, value: str) -> None:
        if entity_id not in self._seen_sets:
            self._seen_sets[entity_id] = {}
        if set_name not in self._seen_sets[entity_id]:
            self._seen_sets[entity_id][set_name] = set()
        self._seen_sets[entity_id][set_name].add(value)
