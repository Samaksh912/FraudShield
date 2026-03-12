# Phase 4A: Core MVP Inference Pipeline — Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement the working heuristic-only fraud scoring pipeline so the FastAPI backend computes real features, scores transactions, generates alerts/signals/explanations, and returns contract-compliant responses for both PaySim and IEEE-CIS domains.

**Architecture:** Fill the Phase 3 scaffold stubs in-place. Feature computation functions receive payload + in-memory state store, return raw feature dicts. A heuristic scorer normalizes features per domain-specific rules and produces a weighted score. The engine wires features → scoring → signals → alerts → explainability → response. State updates happen after scoring (causal constraint).

**Tech Stack:** Python 3.12, FastAPI, Pydantic v2, pytest, uvicorn

**Spec:** `docs/superpowers/specs/2026-03-12-phase4a-inference-pipeline-design.md`

---

## Chunk 1: Foundation — Math Utils, State Store, Config Update

### Task 1: Math utility helpers

**Files:**
- Modify: `app/utils/math_utils.py`
- Create: `tests/test_math_utils.py`

- [ ] **Step 1: Write failing tests for math helpers**

```python
# tests/test_math_utils.py
from app.utils.math_utils import clamped_ratio, zscore, EPSILON


def test_clamped_ratio_normal():
    assert clamped_ratio(50.0, 100.0, cap=1.0) == 0.5


def test_clamped_ratio_zero_denominator():
    result = clamped_ratio(50.0, 0.0, cap=1.0)
    assert result == 1.0  # 50 / EPSILON >> 1.0, capped


def test_clamped_ratio_exceeds_cap():
    assert clamped_ratio(200.0, 100.0, cap=1.0) == 1.0


def test_clamped_ratio_cap_5():
    assert clamped_ratio(600.0, 100.0, cap=5.0) == 5.0


def test_zscore_normal():
    result = zscore(10.0, [5.0, 7.0, 9.0, 11.0, 13.0])
    assert isinstance(result, float)
    assert abs(result) < 3.0


def test_zscore_insufficient_history():
    assert zscore(10.0, [5.0]) == 0.0


def test_zscore_zero_std():
    assert zscore(10.0, [10.0, 10.0, 10.0]) == 0.0


def test_zscore_negative():
    result = zscore(1.0, [5.0, 7.0, 9.0, 11.0])
    assert result < 0.0
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `cd /home/arnavbansal/Layer && .venv/bin/python -m pytest tests/test_math_utils.py -v`
Expected: FAIL — `clamped_ratio` and `zscore` not defined

- [ ] **Step 3: Implement math helpers**

```python
# app/utils/math_utils.py
from __future__ import annotations

import statistics

EPSILON = 1e-6


def clamped_ratio(numerator: float, denominator: float, cap: float = 1.0) -> float:
    return min(numerator / max(denominator, EPSILON), cap)


def zscore(value: float, history: list[float], min_samples: int = 2) -> float:
    if len(history) < min_samples:
        return 0.0
    mean = statistics.mean(history)
    std = statistics.pstdev(history)
    if std < EPSILON:
        return 0.0
    return (value - mean) / std
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `cd /home/arnavbansal/Layer && .venv/bin/python -m pytest tests/test_math_utils.py -v`
Expected: All PASS

- [ ] **Step 5: Commit**

```bash
cd /home/arnavbansal/Layer && git add app/utils/math_utils.py tests/test_math_utils.py && git commit -m "feat: add clamped_ratio and zscore math utilities"
```

---

### Task 2: Expand in-memory state store with domain helpers

**Files:**
- Modify: `app/state/in_memory.py`
- Create: `tests/test_state_store.py`

- [ ] **Step 1: Write failing tests for state helpers**

```python
# tests/test_state_store.py
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
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `cd /home/arnavbansal/Layer && .venv/bin/python -m pytest tests/test_state_store.py -v`
Expected: FAIL — `record_transaction` not defined

- [ ] **Step 3: Implement state store helpers**

```python
# app/state/in_memory.py
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
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `cd /home/arnavbansal/Layer && .venv/bin/python -m pytest tests/test_state_store.py -v`
Expected: All PASS

- [ ] **Step 5: Commit**

```bash
cd /home/arnavbansal/Layer && git add app/state/in_memory.py tests/test_state_store.py && git commit -m "feat: add transaction history and seen-set helpers to InMemoryStateStore"
```

---

### Task 3: Add decision threshold to config

**Files:**
- Modify: `app/config.yaml`
- Modify: `app/config.py`

- [ ] **Step 1: Update config.yaml with decision threshold**

Add `review_to_block: 0.9` to the thresholds section of `app/config.yaml`:

```yaml
engine_version: "0.1.0"
api:
  prefix: "/v1"
thresholds:
  low_to_medium: 0.4
  medium_to_high: 0.75
  review_to_block: 0.9
artifact_paths:
  manifests_dir: "artifacts/manifests"
  paysim_latest: "artifacts/manifests/paysim_latest.json"
  ieee_cis_latest: "artifacts/manifests/ieee_cis_latest.json"
defaults:
  artifact_version: "unavailable"
  fusion_version: "default_v1"
  model_mode: "heuristic_only"
supported_domains:
  - "paysim"
  - "ieee_cis"
```

- [ ] **Step 2: Update ThresholdConfig in config.py**

Add `review_to_block: float = 0.9` to the `ThresholdConfig` class in `app/config.py`.

- [ ] **Step 3: Run existing tests to verify nothing breaks**

Run: `cd /home/arnavbansal/Layer && .venv/bin/python -m pytest tests/ -v`
Expected: All existing tests PASS

- [ ] **Step 4: Commit**

```bash
cd /home/arnavbansal/Layer && git add app/config.yaml app/config.py && git commit -m "feat: add review_to_block decision threshold to config"
```

---

## Chunk 2: Signal Definitions and Explainability Engine

### Task 4: PaySim signal definitions

**Files:**
- Modify: `app/domains/paysim/explanations.py`

- [ ] **Step 1: Implement PaySim signal definitions**

```python
# app/domains/paysim/explanations.py
from __future__ import annotations

from dataclasses import dataclass


@dataclass(frozen=True)
class SignalDefinition:
    code: str
    feature: str
    threshold: float
    direction: str  # "above", "below", "above_abs"
    severity: str  # "low", "medium", "high"
    message: str


PAYSIM_SIGNALS: list[SignalDefinition] = [
    SignalDefinition(
        code="RISKY_TXN_TYPE",
        feature="type_risk_flag",
        threshold=0.5,
        direction="above",
        severity="medium",
        message="Transaction type is associated with higher fraud risk.",
    ),
    SignalDefinition(
        code="HIGH_AMOUNT_TO_BALANCE_RATIO",
        feature="amount_to_orig_balance_ratio",
        threshold=0.7,
        direction="above",
        severity="high",
        message="Transfer amount is unusually large relative to sender balance.",
    ),
    SignalDefinition(
        code="BALANCE_INCONSISTENCY",
        feature="orig_balance_consistency_error",
        threshold=0.01,
        direction="above",
        severity="high",
        message="Sender balance change does not match transaction amount.",
    ),
    SignalDefinition(
        code="HIGH_SENDER_ACTIVITY",
        feature="sender_txn_count_24h",
        threshold=5,
        direction="above",
        severity="medium",
        message="Sender activity is elevated in the last 24 hours.",
    ),
    SignalDefinition(
        code="UNUSUAL_AMOUNT",
        feature="sender_amount_zscore_7d",
        threshold=2.0,
        direction="above_abs",
        severity="medium",
        message="Transaction amount is unusual for this sender.",
    ),
    SignalDefinition(
        code="NEW_BENEFICIARY",
        feature="sender_dest_pair_novelty",
        threshold=0.5,
        direction="above",
        severity="medium",
        message="Sender is transacting with a new beneficiary.",
    ),
]
```

- [ ] **Step 2: Commit**

```bash
cd /home/arnavbansal/Layer && git add app/domains/paysim/explanations.py && git commit -m "feat: add PaySim signal definitions"
```

---

### Task 5: IEEE-CIS signal definitions

**Files:**
- Modify: `app/domains/ieee_cis/explanations.py`

- [ ] **Step 1: Implement IEEE-CIS signal definitions**

```python
# app/domains/ieee_cis/explanations.py
from __future__ import annotations

from app.domains.paysim.explanations import SignalDefinition


IEEE_CIS_SIGNALS: list[SignalDefinition] = [
    SignalDefinition(
        code="LOW_UID_HISTORY",
        feature="uid_prior_frequency",
        threshold=2,
        direction="below",
        severity="medium",
        message="Card identity has very few prior transactions.",
    ),
    SignalDefinition(
        code="HIGH_AMOUNT_VS_MEDIAN",
        feature="amt_to_uid_median_ratio",
        threshold=3.0,
        direction="above",
        severity="high",
        message="Transaction amount is unusually high for this card identity.",
    ),
    SignalDefinition(
        code="HIGH_UID_VELOCITY",
        feature="uid_txn_count_24h",
        threshold=4,
        direction="above",
        severity="medium",
        message="Entity has elevated card activity in the last 24 hours.",
    ),
    SignalDefinition(
        code="EMAIL_DOMAIN_MISMATCH",
        feature="email_domain_mismatch",
        threshold=0.5,
        direction="above",
        severity="medium",
        message="Purchaser and recipient email domains do not match.",
    ),
    SignalDefinition(
        code="NEW_DEVICE_FOR_UID",
        feature="new_device_for_uid",
        threshold=0.5,
        direction="above",
        severity="high",
        message="Transaction originates from a new device signature for this entity.",
    ),
    SignalDefinition(
        code="NO_IDENTITY_DATA",
        feature="identity_present",
        threshold=0.5,
        direction="below",
        severity="low",
        message="No identity verification data available.",
    ),
]
```

- [ ] **Step 2: Commit**

```bash
cd /home/arnavbansal/Layer && git add app/domains/ieee_cis/explanations.py && git commit -m "feat: add IEEE-CIS signal definitions"
```

---

### Task 6: Explainability engine — signal evaluation and explanation building

**Files:**
- Modify: `app/risk/explainability.py`
- Create: `tests/test_explainability.py`

- [ ] **Step 1: Write failing tests**

```python
# tests/test_explainability.py
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
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `cd /home/arnavbansal/Layer && .venv/bin/python -m pytest tests/test_explainability.py -v`
Expected: FAIL

- [ ] **Step 3: Implement explainability engine**

```python
# app/risk/explainability.py
from __future__ import annotations

from app.domains.paysim.explanations import SignalDefinition
from app.schemas.responses import (
    ExplanationResponse,
    FeatureContribution,
    SignalResponse,
)

SEVERITY_ORDER = {"high": 0, "medium": 1, "low": 2}


def evaluate_signals(
    features: dict[str, float | int | None],
    signal_definitions: list[SignalDefinition],
) -> list[SignalResponse]:
    triggered: list[SignalResponse] = []
    for defn in signal_definitions:
        value = features.get(defn.feature)
        if value is None:
            continue
        fired = False
        if defn.direction == "above":
            fired = value > defn.threshold
        elif defn.direction == "below":
            fired = value < defn.threshold
        elif defn.direction == "above_abs":
            fired = abs(value) > defn.threshold
        if fired:
            triggered.append(
                SignalResponse(
                    code=defn.code,
                    severity=defn.severity,
                    value=value,
                    threshold=defn.threshold,
                    message=defn.message,
                )
            )
    triggered.sort(key=lambda s: SEVERITY_ORDER.get(s.severity, 99))
    return triggered


def build_explanations(
    raw_features: dict[str, float | int | None],
    normalized_features: dict[str, float],
    weights: dict[str, float],
    signals: list[SignalResponse],
) -> ExplanationResponse:
    if signals:
        top_reasons = [s.message for s in signals[:5]]
    else:
        top_reasons = ["Transaction appears normal based on available data."]

    contributions: list[FeatureContribution] = []
    for feature, norm_val in normalized_features.items():
        impact = round(norm_val * weights.get(feature, 0.0), 4)
        if abs(impact) < 1e-9:
            continue
        raw_val = raw_features.get(feature, 0)
        contributions.append(
            FeatureContribution(
                feature=feature,
                value=raw_val if raw_val is not None else 0,
                impact=impact,
            )
        )
    contributions.sort(key=lambda c: abs(c.impact), reverse=True)
    return ExplanationResponse(top_reasons=top_reasons, feature_contributions=contributions)
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `cd /home/arnavbansal/Layer && .venv/bin/python -m pytest tests/test_explainability.py -v`
Expected: All PASS

- [ ] **Step 5: Commit**

```bash
cd /home/arnavbansal/Layer && git add app/risk/explainability.py tests/test_explainability.py && git commit -m "feat: implement signal evaluation and explanation builder"
```

---

## Chunk 3: Heuristic Scorer and Alert Generation

### Task 7: Heuristic scoring with per-feature normalization

**Files:**
- Modify: `app/risk/heuristic_scoring.py`
- Create: `tests/test_heuristic_scoring.py`

- [ ] **Step 1: Write failing tests**

```python
# tests/test_heuristic_scoring.py
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
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `cd /home/arnavbansal/Layer && .venv/bin/python -m pytest tests/test_heuristic_scoring.py -v`
Expected: FAIL

- [ ] **Step 3: Implement heuristic scorer**

```python
# app/risk/heuristic_scoring.py
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
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `cd /home/arnavbansal/Layer && .venv/bin/python -m pytest tests/test_heuristic_scoring.py -v`
Expected: All PASS

- [ ] **Step 5: Commit**

```bash
cd /home/arnavbansal/Layer && git add app/risk/heuristic_scoring.py tests/test_heuristic_scoring.py && git commit -m "feat: implement heuristic scorer with per-feature normalization"
```

---

### Task 8: Alert generation

**Files:**
- Modify: `app/risk/alerts.py`
- Create: `tests/test_alerts.py`

- [ ] **Step 1: Write failing tests**

```python
# tests/test_alerts.py
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
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `cd /home/arnavbansal/Layer && .venv/bin/python -m pytest tests/test_alerts.py -v`
Expected: FAIL — `generate_alert` not defined

- [ ] **Step 3: Implement alert generation**

```python
# app/risk/alerts.py
from __future__ import annotations

import uuid

from app.schemas.responses import AlertResponse, AlertsListItem


class InMemoryAlertStore:
    def __init__(self) -> None:
        self._items: list[AlertsListItem] = []

    def list_items(self) -> list[AlertsListItem]:
        return list(self._items)

    def append(self, item: AlertsListItem) -> None:
        self._items.append(item)

    def clear(self) -> None:
        self._items.clear()


def _make_alert_id() -> str:
    return f"alrt_{uuid.uuid4().hex[:4]}"


def generate_alert(
    score: float,
    level: str,
    decision: str,
    domain: str,
    transaction_id: str,
) -> AlertsListItem | None:
    if decision == "allow":
        return None

    if decision == "block":
        priority = "high"
        recommended_action = "block_and_review"
    elif level == "high":
        priority = "high"
        recommended_action = "step_up_verification"
    else:
        priority = "medium"
        recommended_action = "manual_review"

    return AlertsListItem(
        alert_id=_make_alert_id(),
        type="suspicious_transaction",
        priority=priority,
        status="open",
        recommended_action=recommended_action,
        domain=domain,
        transaction_id=transaction_id,
        risk_score=score,
    )


def alert_list_item_to_response(item: AlertsListItem) -> AlertResponse:
    return AlertResponse(
        alert_id=item.alert_id,
        type=item.type,
        priority=item.priority,
        status=item.status,
        recommended_action=item.recommended_action,
    )
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `cd /home/arnavbansal/Layer && .venv/bin/python -m pytest tests/test_alerts.py -v`
Expected: All PASS

- [ ] **Step 5: Commit**

```bash
cd /home/arnavbansal/Layer && git add app/risk/alerts.py tests/test_alerts.py && git commit -m "feat: implement threshold-based alert generation"
```

---

## Chunk 4: Domain Feature Computation

### Task 9: PaySim online feature computation

**Files:**
- Modify: `app/domains/paysim/features_online.py`
- Create: `tests/test_paysim_features.py`

- [ ] **Step 1: Write failing tests**

```python
# tests/test_paysim_features.py
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
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `cd /home/arnavbansal/Layer && .venv/bin/python -m pytest tests/test_paysim_features.py -v`
Expected: FAIL

- [ ] **Step 3: Implement PaySim feature computation**

```python
# app/domains/paysim/features_online.py
from __future__ import annotations

from app.schemas.common import FEATURE_KEYS_BY_DOMAIN
from app.state.in_memory import InMemoryStateStore
from app.utils.math_utils import EPSILON, clamped_ratio, zscore

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
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `cd /home/arnavbansal/Layer && .venv/bin/python -m pytest tests/test_paysim_features.py -v`
Expected: All PASS

- [ ] **Step 5: Commit**

```bash
cd /home/arnavbansal/Layer && git add app/domains/paysim/features_online.py tests/test_paysim_features.py && git commit -m "feat: implement PaySim online feature computation"
```

---

### Task 10: IEEE-CIS online feature computation + adapter identity_present

**Files:**
- Modify: `app/domains/ieee_cis/features_online.py`
- Modify: `app/domains/ieee_cis/adapter.py`
- Create: `tests/test_ieee_features.py`

- [ ] **Step 1: Write failing tests**

```python
# tests/test_ieee_features.py
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
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `cd /home/arnavbansal/Layer && .venv/bin/python -m pytest tests/test_ieee_features.py -v`
Expected: FAIL

- [ ] **Step 3: Implement IEEE-CIS feature computation**

```python
# app/domains/ieee_cis/features_online.py
from __future__ import annotations

import statistics

from app.schemas.common import FEATURE_KEYS_BY_DOMAIN
from app.state.in_memory import InMemoryStateStore
from app.utils.math_utils import EPSILON, clamped_ratio

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
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `cd /home/arnavbansal/Layer && .venv/bin/python -m pytest tests/test_ieee_features.py -v`
Expected: All PASS

- [ ] **Step 5: Commit**

```bash
cd /home/arnavbansal/Layer && git add app/domains/ieee_cis/features_online.py app/domains/ieee_cis/adapter.py tests/test_ieee_features.py && git commit -m "feat: implement IEEE-CIS online feature computation with uid and identity_present"
```

---

## Chunk 5: Risk Engine Wiring

### Task 11: Implement HeuristicRiskEngine

**Files:**
- Modify: `app/risk/engine.py`
- Modify: `app/risk/dependencies.py`

- [ ] **Step 1: Implement HeuristicRiskEngine**

Replace the contents of `app/risk/engine.py` with the full engine that wires features, scoring, signals, alerts, explainability, and latency:

```python
# app/risk/engine.py
from __future__ import annotations

import time
from abc import ABC, abstractmethod

from app import __version__
from app.config import load_config
from app.domains.ieee_cis.explanations import IEEE_CIS_SIGNALS
from app.domains.ieee_cis.features_online import (
    compute_ieee_features,
    update_ieee_state,
)
from app.domains.paysim.explanations import PAYSIM_SIGNALS
from app.domains.paysim.features_online import (
    compute_paysim_features,
    update_paysim_state,
)
from app.risk.alerts import InMemoryAlertStore, alert_list_item_to_response, generate_alert
from app.risk.artifact_loader import load_artifact_registry
from app.risk.explainability import build_explanations, evaluate_signals
from app.risk.heuristic_scoring import (
    IEEE_CIS_WEIGHTS,
    PAYSIM_WEIGHTS,
    compute_heuristic_score,
    risk_decision,
    risk_level,
)
from app.schemas.common import ApiStatus, DomainName, ModelMode
from app.schemas.requests import (
    BatchScoreRequest,
    IeeeCisScorePayload,
    PaySimScorePayload,
    ScoreRequest,
)
from app.schemas.responses import (
    AlertsListItem,
    BatchScoreResponse,
    ModelResponse,
    RiskResponse,
    ScoreBreakdown,
    ScoreResponse,
)
from app.state.in_memory import InMemoryStateStore


class RiskEngine(ABC):
    @abstractmethod
    def score(self, request: ScoreRequest) -> ScoreResponse:
        raise NotImplementedError

    @abstractmethod
    def score_batch(self, request: BatchScoreRequest) -> BatchScoreResponse:
        raise NotImplementedError


class HeuristicRiskEngine(RiskEngine):
    def __init__(self) -> None:
        self._config = load_config()
        self._artifacts = load_artifact_registry()
        self._alert_store = InMemoryAlertStore()
        self._paysim_state = InMemoryStateStore()
        self._ieee_state = InMemoryStateStore()

    def score(self, request: ScoreRequest) -> ScoreResponse:
        start = time.perf_counter()

        domain = request.domain
        payload = request.payload

        # 1. Compute features
        if domain == DomainName.PAYSIM:
            assert isinstance(payload, PaySimScorePayload)
            features = compute_paysim_features(
                step=payload.step,
                txn_type=payload.type,
                amount=request.transaction.amount,
                name_orig=payload.nameOrig,
                name_dest=payload.nameDest,
                old_balance_org=payload.oldbalanceOrg,
                new_balance_orig=payload.newbalanceOrig,
                store=self._paysim_state,
            )
            signal_defs = PAYSIM_SIGNALS
            weights = PAYSIM_WEIGHTS
        else:
            assert isinstance(payload, IeeeCisScorePayload)
            features = compute_ieee_features(
                transaction_dt=payload.TransactionDT,
                transaction_amt=payload.TransactionAmt,
                card1=payload.card1,
                card2=payload.card2,
                card3=payload.card3,
                card5=payload.card5,
                addr1=payload.addr1,
                addr2=payload.addr2,
                p_emaildomain=payload.P_emaildomain,
                r_emaildomain=payload.R_emaildomain,
                device_type=payload.DeviceType,
                device_info=payload.DeviceInfo,
                id_30=payload.id_30,
                id_31=payload.id_31,
                id_33=payload.id_33,
                store=self._ieee_state,
            )
            signal_defs = IEEE_CIS_SIGNALS
            weights = IEEE_CIS_WEIGHTS

        # 2. Heuristic scoring
        heuristic_score, normalized = compute_heuristic_score(features, domain.value)
        level = risk_level(heuristic_score)
        decision = risk_decision(heuristic_score)

        # 3. Signals
        signals = evaluate_signals(features, signal_defs)

        # 4. Explanations
        explanations = build_explanations(features, normalized, weights, signals)

        # 5. Alerts
        alert_item = generate_alert(
            score=heuristic_score,
            level=level,
            decision=decision,
            domain=domain.value,
            transaction_id=request.transaction.transaction_id,
        )
        alert_responses = []
        if alert_item is not None:
            self._alert_store.append(alert_item)
            alert_responses.append(alert_list_item_to_response(alert_item))

        # 6. Update state AFTER scoring
        if domain == DomainName.PAYSIM:
            assert isinstance(payload, PaySimScorePayload)
            update_paysim_state(
                store=self._paysim_state,
                name_orig=payload.nameOrig,
                name_dest=payload.nameDest,
                step=payload.step,
                amount=request.transaction.amount,
            )
        else:
            assert isinstance(payload, IeeeCisScorePayload)
            update_ieee_state(
                store=self._ieee_state,
                card1=payload.card1,
                card2=payload.card2,
                card3=payload.card3,
                card5=payload.card5,
                addr1=payload.addr1,
                addr2=payload.addr2,
                transaction_dt=payload.TransactionDT,
                transaction_amt=payload.TransactionAmt,
                device_type=payload.DeviceType,
                device_info=payload.DeviceInfo,
            )

        # 7. Build response
        artifact = self._artifacts.items[domain.value]
        elapsed_ms = int((time.perf_counter() - start) * 1000)

        return ScoreResponse(
            request_id=request.request_id,
            status=ApiStatus.OK,
            domain=domain,
            transaction_id=request.transaction.transaction_id,
            input_snapshot={
                "transaction": request.transaction,
                "payload": request.payload.model_dump(mode="python"),
            },
            risk=RiskResponse(
                score=round(heuristic_score, 4),
                level=level,
                decision=decision,
                confidence=1.0,
            ),
            scores=ScoreBreakdown(
                heuristic=round(heuristic_score, 4),
                supervised=None,
                anomaly=None,
                fusion_version=self._config.defaults.fusion_version,
            ),
            signals=signals,
            explanations=explanations,
            features=features,
            alerts=alert_responses,
            transaction_summary=self._build_summary(request),
            model=ModelResponse(
                artifact_version=artifact.artifact_version or self._config.defaults.artifact_version,
                mode=artifact.mode if artifact.artifact_version else ModelMode.HEURISTIC_ONLY,
                engine_version=__version__,
            ),
            latency_ms=elapsed_ms,
        )

    def _build_summary(self, request: ScoreRequest) -> dict:
        return {
            "amount": request.transaction.amount,
            "currency": request.transaction.currency,
            "channel": request.transaction.channel,
            "product_code": request.transaction.product_code,
            "card_network": request.transaction.card_network,
            "funding_type": request.transaction.funding_type,
        }

    def score_batch(self, request: BatchScoreRequest) -> BatchScoreResponse:
        results = [self.score(item) for item in request.to_score_requests()]
        return BatchScoreResponse(domain=request.domain, results=results)

    def list_alerts(self) -> list[AlertsListItem]:
        return self._alert_store.list_items()
```

- [ ] **Step 2: Update dependencies.py**

```python
# app/risk/dependencies.py
from __future__ import annotations

from functools import lru_cache

from app.risk.engine import HeuristicRiskEngine


@lru_cache(maxsize=1)
def get_engine() -> HeuristicRiskEngine:
    return HeuristicRiskEngine()
```

- [ ] **Step 3: Run tests excluding test_risk_engine.py (updated in next task)**

Run: `cd /home/arnavbansal/Layer && .venv/bin/python -m pytest tests/ --ignore=tests/test_risk_engine.py -v`
Expected: All tests PASS (test_risk_engine.py still imports removed StubRiskEngine, so it is excluded until Task 12 updates it)

- [ ] **Step 4: Commit**

```bash
cd /home/arnavbansal/Layer && git add app/risk/engine.py app/risk/dependencies.py && git commit -m "feat: implement HeuristicRiskEngine with full scoring pipeline"
```

---

### Task 12: Update test_risk_engine.py for new engine

**Files:**
- Modify: `tests/test_risk_engine.py`

- [ ] **Step 1: Update risk engine tests**

```python
# tests/test_risk_engine.py
import json
from pathlib import Path

from app.risk.engine import HeuristicRiskEngine
from app.schemas.requests import ScoreRequest

BASE_DIR = Path(__file__).resolve().parents[1]


def test_heuristic_engine_paysim_returns_contract_safe_response():
    contract = json.loads((BASE_DIR / "frontend_api_contract_v1.json").read_text())
    request = ScoreRequest.model_validate(contract["examples"]["score_request_paysim"])
    engine = HeuristicRiskEngine()
    response = engine.score(request)
    assert response.status.value == "ok"
    assert response.domain.value == "paysim"
    assert response.model.engine_version
    assert set(response.features.keys()) == {
        "type_risk_flag",
        "amount_to_orig_balance_ratio",
        "orig_balance_consistency_error",
        "sender_txn_count_24h",
        "sender_amount_zscore_7d",
        "sender_dest_pair_novelty",
    }
    assert 0.0 <= response.risk.score <= 1.0
    assert response.scores.supervised is None
    assert response.scores.anomaly is None
    assert response.latency_ms >= 0


def test_heuristic_engine_ieee_cis_returns_contract_safe_response():
    contract = json.loads((BASE_DIR / "frontend_api_contract_v1.json").read_text())
    request = ScoreRequest.model_validate(contract["examples"]["score_request_ieee_cis"])
    engine = HeuristicRiskEngine()
    response = engine.score(request)
    assert response.status.value == "ok"
    assert response.domain.value == "ieee_cis"
    assert set(response.features.keys()) == {
        "uid_prior_frequency",
        "amt_to_uid_median_ratio",
        "uid_txn_count_24h",
        "email_domain_mismatch",
        "new_device_for_uid",
        "identity_present",
    }
    assert 0.0 <= response.risk.score <= 1.0


def test_heuristic_engine_batch():
    contract = json.loads((BASE_DIR / "frontend_api_contract_v1.json").read_text())
    from app.schemas.requests import BatchScoreRequest
    paysim = contract["examples"]["score_request_paysim"]
    batch = BatchScoreRequest.model_validate({
        "domain": "paysim",
        "items": [{
            "request_id": paysim["request_id"],
            "event_time": paysim["event_time"],
            "transaction": paysim["transaction"],
            "payload": paysim["payload"],
            "context": paysim["context"],
        }],
    })
    engine = HeuristicRiskEngine()
    response = engine.score_batch(batch)
    assert len(response.results) == 1
    assert response.results[0].status.value == "ok"


def test_heuristic_engine_alerts_stored():
    contract = json.loads((BASE_DIR / "frontend_api_contract_v1.json").read_text())
    request = ScoreRequest.model_validate(contract["examples"]["score_request_paysim"])
    engine = HeuristicRiskEngine()
    response = engine.score(request)
    # Whether alerts are generated depends on score, but the list should be accessible
    all_alerts = engine.list_alerts()
    if response.risk.score >= 0.4:
        assert len(all_alerts) >= 1
    else:
        assert len(all_alerts) == 0


def test_input_snapshot_echoed():
    contract = json.loads((BASE_DIR / "frontend_api_contract_v1.json").read_text())
    request = ScoreRequest.model_validate(contract["examples"]["score_request_paysim"])
    engine = HeuristicRiskEngine()
    response = engine.score(request)
    assert response.input_snapshot.transaction.transaction_id == request.transaction.transaction_id
    assert "step" in response.input_snapshot.payload
```

- [ ] **Step 2: Run tests**

Run: `cd /home/arnavbansal/Layer && .venv/bin/python -m pytest tests/test_risk_engine.py -v`
Expected: All PASS

- [ ] **Step 3: Commit**

```bash
cd /home/arnavbansal/Layer && git add tests/test_risk_engine.py && git commit -m "test: update risk engine tests for HeuristicRiskEngine"
```

---

## Chunk 6: Sample Ingestion, API Tests, and Final Verification

### Task 13: Sample data ingestion helpers

**Files:**
- Modify: `app/utils/data_loader.py`
- Modify: `tests/test_sample_loading.py`

- [ ] **Step 1: Add ScoreRequest conversion helpers and tests**

Add to `app/utils/data_loader.py`:

```python
# Add these functions to the existing file

from datetime import datetime, timezone
import uuid

from app.schemas.requests import (
    IeeeCisScorePayload,
    PaySimScorePayload,
    ScoreRequest,
)
from app.schemas.common import TransactionInput


def paysim_row_to_score_request(row: dict[str, Any]) -> ScoreRequest:
    return ScoreRequest(
        request_id=str(uuid.uuid4()),
        domain="paysim",
        event_time=datetime.now(tz=timezone.utc),
        transaction=TransactionInput(
            transaction_id=f"txn_ps_{uuid.uuid4().hex[:8]}",
            amount=float(row["amount"]),
            currency="INR",
            channel="upi",
        ),
        payload=PaySimScorePayload(
            step=int(row["step"]),
            type=row["type"],
            nameOrig=row["nameOrig"],
            nameDest=row["nameDest"],
            oldbalanceOrg=float(row["oldbalanceOrg"]),
            newbalanceOrig=float(row["newbalanceOrig"]) if row.get("newbalanceOrig") else None,
            oldbalanceDest=float(row["oldbalanceDest"]) if row.get("oldbalanceDest") else None,
            newbalanceDest=float(row["newbalanceDest"]) if row.get("newbalanceDest") else None,
        ),
    )


def ieee_row_to_score_request(
    txn_row: dict[str, Any],
    identity_row: dict[str, Any] | None = None,
) -> ScoreRequest:
    def _float_or_none(val: Any) -> float | None:
        if val is None or val == "":
            return None
        return float(val)

    def _str_or_none(val: Any) -> str | None:
        if val is None or val == "":
            return None
        return str(val)

    device_type = None
    device_info = None
    id_30 = None
    id_31 = None
    id_33 = None
    if identity_row:
        device_type = _str_or_none(identity_row.get("DeviceType"))
        device_info = _str_or_none(identity_row.get("DeviceInfo"))
        id_30 = _str_or_none(identity_row.get("id_30"))
        id_31 = _str_or_none(identity_row.get("id_31"))
        id_33 = _str_or_none(identity_row.get("id_33"))

    card4 = _str_or_none(txn_row.get("card4"))
    card6 = _str_or_none(txn_row.get("card6"))

    return ScoreRequest(
        request_id=str(uuid.uuid4()),
        domain="ieee_cis",
        event_time=datetime.now(tz=timezone.utc),
        transaction=TransactionInput(
            transaction_id=f"txn_ieee_{txn_row['TransactionID']}",
            amount=float(txn_row["TransactionAmt"]),
            currency="USD",
            channel="card",
            product_code=txn_row.get("ProductCD"),
            card_network=card4,
            funding_type=card6,
        ),
        payload=IeeeCisScorePayload(
            TransactionDT=int(txn_row["TransactionDT"]),
            TransactionAmt=float(txn_row["TransactionAmt"]),
            ProductCD=txn_row["ProductCD"],
            card1=int(txn_row["card1"]),
            card2=float(txn_row.get("card2", 0) or 0),
            card3=float(txn_row.get("card3", 0) or 0),
            card5=float(txn_row.get("card5", 0) or 0),
            addr1=float(txn_row.get("addr1", 0) or 0),
            addr2=float(txn_row.get("addr2", 0) or 0),
            card4=card4,
            card6=card6,
            dist1=_float_or_none(txn_row.get("dist1")),
            P_emaildomain=_str_or_none(txn_row.get("P_emaildomain")),
            R_emaildomain=_str_or_none(txn_row.get("R_emaildomain")),
            DeviceType=device_type,
            DeviceInfo=device_info,
            id_30=id_30,
            id_31=id_31,
            id_33=id_33,
        ),
    )


def load_paysim_sample(path: str | Path) -> list[ScoreRequest]:
    rows = load_csv_rows(path)
    return [paysim_row_to_score_request(row) for row in rows]


def load_ieee_sample(
    txn_path: str | Path,
    identity_path: str | Path,
) -> list[ScoreRequest]:
    txn_rows = load_csv_rows(txn_path)
    identity_rows = load_csv_rows(identity_path)
    identity_map: dict[str, dict[str, Any]] = {}
    for row in identity_rows:
        tid = row.get("TransactionID", "")
        if tid:
            identity_map[tid] = row

    requests: list[ScoreRequest] = []
    for txn_row in txn_rows:
        tid = txn_row.get("TransactionID", "")
        identity_row = identity_map.get(tid)
        requests.append(ieee_row_to_score_request(txn_row, identity_row))
    return requests
```

- [ ] **Step 2: Add ingestion tests**

Append to `tests/test_sample_loading.py`:

```python
# Add these tests to the existing file

from app.utils.data_loader import load_paysim_sample, load_ieee_sample


def test_load_paysim_sample_produces_score_requests() -> None:
    requests = load_paysim_sample(BASE_DIR / "upi_sample.csv")
    assert len(requests) > 0
    req = requests[0]
    assert req.domain.value == "paysim"
    assert req.transaction.channel == "upi"
    assert req.payload.step >= 0


def test_load_ieee_sample_produces_score_requests() -> None:
    requests = load_ieee_sample(
        BASE_DIR / "ieee_transaction_sample.csv",
        BASE_DIR / "ieee_identity_sample.csv",
    )
    assert len(requests) > 0
    req = requests[0]
    assert req.domain.value == "ieee_cis"
    assert req.transaction.channel == "card"


def test_paysim_sample_can_be_scored() -> None:
    from app.risk.engine import HeuristicRiskEngine
    requests = load_paysim_sample(BASE_DIR / "upi_sample.csv")
    engine = HeuristicRiskEngine()
    response = engine.score(requests[0])
    assert response.status.value == "ok"
    assert 0.0 <= response.risk.score <= 1.0


def test_ieee_sample_can_be_scored() -> None:
    from app.risk.engine import HeuristicRiskEngine
    requests = load_ieee_sample(
        BASE_DIR / "ieee_transaction_sample.csv",
        BASE_DIR / "ieee_identity_sample.csv",
    )
    engine = HeuristicRiskEngine()
    response = engine.score(requests[0])
    assert response.status.value == "ok"
    assert 0.0 <= response.risk.score <= 1.0
```

- [ ] **Step 3: Run tests**

Run: `cd /home/arnavbansal/Layer && .venv/bin/python -m pytest tests/test_sample_loading.py -v`
Expected: All PASS

- [ ] **Step 4: Commit**

```bash
cd /home/arnavbansal/Layer && git add app/utils/data_loader.py tests/test_sample_loading.py && git commit -m "feat: add sample CSV to ScoreRequest ingestion helpers"
```

---

### Task 14: Full test suite verification and API smoke test

**Files:**
- No new files

- [ ] **Step 1: Run full test suite**

Run: `cd /home/arnavbansal/Layer && .venv/bin/python -m pytest tests/ -v`
Expected: All tests PASS

- [ ] **Step 2: Start the FastAPI server and smoke test**

Run in background:
```bash
cd /home/arnavbansal/Layer && .venv/bin/python -m uvicorn app.main:app --port 8000 &
```

Then test endpoints:
```bash
# Health
curl -s http://localhost:8000/v1/health | python -m json.tool

# Score (paysim)
curl -s -X POST http://localhost:8000/v1/score \
  -H "Content-Type: application/json" \
  -d '{
    "request_id": "test-1",
    "domain": "paysim",
    "event_time": "2026-03-12T10:15:00Z",
    "transaction": {"transaction_id": "txn_1", "amount": 125000.0, "currency": "INR", "channel": "upi"},
    "payload": {"step": 278, "type": "TRANSFER", "nameOrig": "C123", "nameDest": "C456", "oldbalanceOrg": 150000.0, "newbalanceOrig": 25000.0}
  }' | python -m json.tool

# Score (ieee_cis)
curl -s -X POST http://localhost:8000/v1/score \
  -H "Content-Type: application/json" \
  -d '{
    "request_id": "test-2",
    "domain": "ieee_cis",
    "event_time": "2026-03-12T10:15:00Z",
    "transaction": {"transaction_id": "txn_c1", "amount": 68.5, "currency": "USD", "channel": "card", "product_code": "W", "card_network": "visa", "funding_type": "credit"},
    "payload": {"TransactionDT": 86400, "TransactionAmt": 68.5, "ProductCD": "W", "card1": 13926, "card2": 404.0, "card3": 150.0, "card5": 142.0, "addr1": 315.0, "addr2": 87.0, "P_emaildomain": "gmail.com", "R_emaildomain": "hotmail.com", "DeviceType": "mobile", "DeviceInfo": "iOS Device"}
  }' | python -m json.tool

# Alerts
curl -s http://localhost:8000/v1/alerts | python -m json.tool

# Admin models
curl -s http://localhost:8000/v1/admin/models | python -m json.tool
```

Kill the server after verification.

- [ ] **Step 3: Commit all remaining changes if any**

```bash
cd /home/arnavbansal/Layer && git add -A && git status
# Only commit if there are changes
```

Expected: All 5 endpoints respond correctly. PaySim and IEEE-CIS both produce scored responses with real features, signals, explanations, and alerts. The backend runs with no artifacts in heuristic-only mode.

---

## Spec Coverage Notes

**`app/risk/fusion.py`**: The spec lists this as a file to modify, but the fusion logic (heuristic-only: `supervised=None`, `anomaly=None`, `fusion_version="default_v1"`) is handled inline in `HeuristicRiskEngine.score()` (Task 11). The existing `fusion.py` stub (`default_fusion_version()`) is no longer called. This is intentional — a separate fusion module adds no value until Phase 4B introduces supervised/anomaly scoring.

**`app/domains/ieee_cis/adapter.py`**: The spec says to compute `identity_present` in the adapter. The plan computes it inside `compute_ieee_features()` instead, which achieves the same result (backend-computed, client value ignored). The adapter file is unchanged.

**`tests/test_frontend_mocks.py`**: The existing tests already validate structural compatibility by running `ScoreResponse.model_validate()` on mock fixtures, which checks field presence, types, and enum values. No update needed — the existing tests cover the spec's mock compatibility requirement.
