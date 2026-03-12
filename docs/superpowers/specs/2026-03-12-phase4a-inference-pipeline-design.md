# Phase 4A: Core MVP Inference Pipeline Design

## Goal

Implement the working inference pipeline inside the existing Phase 3 scaffold so the FastAPI backend accepts requests, computes real features, scores via heuristics, generates signals/alerts/explanations, and returns contract-compliant responses.

## Scope

### In scope

- Real feature computation for PaySim (6 features) and IEEE-CIS (6 features)
- In-memory causal state tracking per domain
- Heuristic-only scoring with explicit per-feature normalization
- Signal generation from feature thresholds
- Threshold-based alert generation and in-memory storage
- Feature-driven explainability (top reasons, feature contributions)
- Sample CSV ingestion helpers for tests and demos
- Backend-computed `identity_present` (never trusted from client)
- Latency measurement (owned by `engine.score()`)
- Tests for all of the above

### Out of scope

- ML model training
- Kaggle artifact integration
- Frontend implementation
- Database/Redis
- Net Banking domain logic

## File Change Plan

| File | Action |
|---|---|
| `app/domains/paysim/features_online.py` | Implement 6 MVP features with state |
| `app/domains/ieee_cis/features_online.py` | Implement 6 MVP features with state |
| `app/state/in_memory.py` | Add domain-aware state helpers |
| `app/risk/heuristic_scoring.py` | Weighted scoring with per-feature normalization |
| `app/risk/engine.py` | Wire features, scoring, signals, alerts, explainability; own latency measurement |
| `app/risk/alerts.py` | Threshold-based alert creation |
| `app/risk/explainability.py` | Feature-driven reasons, signals, contributions |
| `app/risk/fusion.py` | Heuristic-only fusion (supervised/anomaly slots remain null) |
| `app/risk/dependencies.py` | Update to import and cache new concrete engine class |
| `app/domains/paysim/explanations.py` | PaySim signal definitions |
| `app/domains/ieee_cis/explanations.py` | IEEE-CIS signal definitions |
| `app/domains/ieee_cis/adapter.py` | Compute `identity_present` from payload fields |
| `app/utils/data_loader.py` | Add CSV-to-ScoreRequest helpers |
| `app/utils/math_utils.py` | Add z-score, ratio clamping helpers |
| `tests/test_paysim_features.py` | New: feature computation tests |
| `tests/test_ieee_features.py` | New: feature computation tests |
| `tests/test_heuristic_scoring.py` | New: normalization and scoring tests |
| `tests/test_alerts.py` | New: alert generation tests |
| `tests/test_risk_engine.py` | Update to use new engine class |
| `tests/test_sample_loading.py` | Update with ScoreRequest conversion tests |
| `tests/test_api_contract.py` | Remains; verify still passes |
| `tests/test_frontend_mocks.py` | Update to validate mock structure compatibility |

## Design Details

### 1. IEEE-CIS uid Construction

```python
uid = f"{card1}_{card2}_{card3}_{card5}_{addr1}_{addr2}"
```

Uses the full Phase 1 definition: `card1 + card2 + card3 + card5 + addr1 + addr2`. This ensures train-serve parity with Kaggle training in Phase 4B.

### 2. identity_present Computation

Computed by the adapter, never trusted from client payload. Logic:

```python
identity_fields = [payload.DeviceType, payload.DeviceInfo, payload.id_30, payload.id_31, payload.id_33]
identity_present = 1 if any(f is not None for f in identity_fields) else 0
```

The `identity_present` field on `IeeeCisScorePayload` remains in the schema for backward compatibility but is ignored during scoring. The adapter always recomputes it.

### 3. In-Memory State Structure

**PaySim state** (keyed by `nameOrig`):
- `txn_timestamps: list[int]` — step values of prior transactions
- `txn_amounts: list[float]` — amounts of prior transactions
- `seen_destinations: set[str]` — previously seen `nameDest` values

**IEEE-CIS state** (keyed by uid):
- `txn_timestamps: list[int]` — `TransactionDT` values of prior transactions
- `txn_amounts: list[float]` — amounts of prior transactions
- `seen_devices: set[str]` — previously seen device signatures

State is read before scoring, updated after scoring. Only transactions with time < current transaction time contribute.

### 4. PaySim Feature Computation

| Feature | Computation | Default |
|---|---|---|
| `type_risk_flag` | 1 if type in {TRANSFER, CASH_OUT}, else 0 | 0 |
| `amount_to_orig_balance_ratio` | `amount / max(oldbalanceOrg, epsilon)`, capped at 1.0 | 0.0 |
| `orig_balance_consistency_error` | `abs(oldbalanceOrg - amount - newbalanceOrig) / max(oldbalanceOrg, epsilon)`, capped at 1.0; 0.0 if `newbalanceOrig` is None | 0.0 |
| `sender_txn_count_24h` | Count of sender's prior txns within 24 steps | 0 |
| `sender_amount_zscore_7d` | Z-score of current amount vs sender's 7-day (168 steps) history; 0.0 if < 2 prior txns. Can be negative. | 0.0 |
| `sender_dest_pair_novelty` | 1 if (sender, dest) pair not seen before, else 0 | 0 (neutral) |

### 5. IEEE-CIS Feature Computation

| Feature | Computation | Default |
|---|---|---|
| `uid_prior_frequency` | Count of uid's total prior transactions | 0 |
| `amt_to_uid_median_ratio` | `amount / max(median(uid_prior_amounts), epsilon)`, capped at 5.0; 0.0 if no prior amounts | 0.0 |
| `uid_txn_count_24h` | Count of uid's prior txns within 86400 seconds | 0 |
| `email_domain_mismatch` | 1 if P_emaildomain and R_emaildomain both present and differ, else 0 | 0 |
| `new_device_for_uid` | 1 if device signature not in uid's seen devices, else 0; 0 if no device info | 0 (neutral) |
| `identity_present` | Computed by adapter (see section 2) | 0 |

### 6. Per-Feature Normalization Rules (Heuristic Scorer)

Every feature is normalized to [0, 1] before weighting. The `features` dict in the response always contains **raw** feature values (which may be negative, e.g. z-scores, or > 1, e.g. `amt_to_uid_median_ratio`). Normalization is internal to the heuristic scorer only.

**PaySim:**
| Feature | Normalization |
|---|---|
| `type_risk_flag` | binary, pass through |
| `amount_to_orig_balance_ratio` | already capped [0, 1] |
| `orig_balance_consistency_error` | already capped [0, 1] |
| `sender_txn_count_24h` | `min(count, 20) / 20` |
| `sender_amount_zscore_7d` | `min(abs(zscore), 3.0) / 3.0` |
| `sender_dest_pair_novelty` | binary, pass through |

**IEEE-CIS:**
| Feature | Normalization |
|---|---|
| `uid_prior_frequency` | `1.0 - min(count, 50) / 50` (inverted: low frequency = higher risk) |
| `amt_to_uid_median_ratio` | `min(ratio, 5.0) / 5.0` |
| `uid_txn_count_24h` | `min(count, 20) / 20` |
| `email_domain_mismatch` | binary, pass through |
| `new_device_for_uid` | binary, pass through |
| `identity_present` | `1.0 - value` (inverted: no identity = higher risk) |

### 7. Heuristic Scoring Weights

**PaySim weights:**
| Feature | Weight |
|---|---|
| `type_risk_flag` | 0.20 |
| `amount_to_orig_balance_ratio` | 0.25 |
| `orig_balance_consistency_error` | 0.20 |
| `sender_txn_count_24h` | 0.10 |
| `sender_amount_zscore_7d` | 0.15 |
| `sender_dest_pair_novelty` | 0.10 |

**IEEE-CIS weights:**
| Feature | Weight |
|---|---|
| `uid_prior_frequency` | 0.15 |
| `amt_to_uid_median_ratio` | 0.25 |
| `uid_txn_count_24h` | 0.10 |
| `email_domain_mismatch` | 0.15 |
| `new_device_for_uid` | 0.20 |
| `identity_present` | 0.15 |

Final score = `clamp(sum(normalized_feature * weight), 0.0, 1.0)`

### 8. Risk Level and Decision Mapping

Level and decision use **separate** thresholds (reconciled with mock fixtures):

**Level thresholds** (from `config.yaml`):
| Score Range | Level |
|---|---|
| `< 0.4` | low |
| `0.4 - 0.75` | medium |
| `>= 0.75` | high |

**Decision thresholds** (separate from level):
| Score Range | Decision |
|---|---|
| `< 0.4` | allow |
| `0.4 - 0.9` | review |
| `>= 0.9` | block |

This reconciles with mock fixtures:
- `score: 0.864` → level: high, decision: review (correct: 0.864 < 0.9)
- `score: 0.931` → level: high, decision: block (correct: 0.931 >= 0.9)
- `score: 0.58` → level: medium, decision: review (correct)
- `score: 0.11` → level: low, decision: allow (correct)

### 9. Alert Generation

Alerts are generated when `risk.score >= 0.4`:

| Decision | Alert Priority | Recommended Action |
|---|---|---|
| review (medium level) | medium | `manual_review` |
| review (high level) | high | `step_up_verification` |
| block | high | `block_and_review` |

This matches all mock alert fixtures exactly:
- paysim high-risk review: priority high, `step_up_verification`
- ieee_cis high-risk block: priority high, `block_and_review`
- ieee_cis medium-risk review: priority medium, `manual_review`

Alert objects are stored in `InMemoryAlertStore` and returned in both the score response and via `GET /v1/alerts`.

### 10. Signal Generation

Each feature has a predefined signal definition with a threshold and a **direction** (`above` or `below`). If the raw feature value crosses the threshold in the specified direction, a `SignalResponse` is emitted.

Signal codes are aligned with `frontend_mock_responses.json` (the binding reference).

**PaySim signals:**
| Code | Feature | Threshold | Direction | Severity | Message |
|---|---|---|---|---|---|
| `RISKY_TXN_TYPE` | `type_risk_flag` | 0.5 | above | medium | Transaction type is associated with higher fraud risk. |
| `HIGH_AMOUNT_TO_BALANCE_RATIO` | `amount_to_orig_balance_ratio` | 0.7 | above | high | Transfer amount is unusually large relative to sender balance. |
| `BALANCE_INCONSISTENCY` | `orig_balance_consistency_error` | 0.01 | above | high | Sender balance change does not match transaction amount. |
| `HIGH_SENDER_ACTIVITY` | `sender_txn_count_24h` | 5 | above | medium | Sender activity is elevated in the last 24 hours. |
| `UNUSUAL_AMOUNT` | `sender_amount_zscore_7d` | 2.0 | above (abs) | medium | Transaction amount is unusual for this sender. |
| `NEW_BENEFICIARY` | `sender_dest_pair_novelty` | 0.5 | above | medium | Sender is transacting with a new beneficiary. |

**IEEE-CIS signals:**
| Code | Feature | Threshold | Direction | Severity | Message |
|---|---|---|---|---|---|
| `LOW_UID_HISTORY` | `uid_prior_frequency` | 2 | below | medium | Card identity has very few prior transactions. |
| `HIGH_AMOUNT_VS_MEDIAN` | `amt_to_uid_median_ratio` | 3.0 | above | high | Transaction amount is unusually high for this card identity. |
| `HIGH_UID_VELOCITY` | `uid_txn_count_24h` | 4 | above | medium | Entity has elevated card activity in the last 24 hours. |
| `EMAIL_DOMAIN_MISMATCH` | `email_domain_mismatch` | 0.5 | above | medium | Purchaser and recipient email domains do not match. |
| `NEW_DEVICE_FOR_UID` | `new_device_for_uid` | 0.5 | above | high | Transaction originates from a new device signature for this entity. |
| `NO_IDENTITY_DATA` | `identity_present` | 0.5 | below | low | No identity verification data available. |

Signal definitions include:
- `direction: "above"` — fire when `value > threshold`
- `direction: "below"` — fire when `value < threshold`
- `direction: "above_abs"` — fire when `abs(value) > threshold` (used for z-scores)

### 11. Explainability

- **`top_reasons`**: Derived from triggered signals, ordered by severity (high first). Each signal's message becomes a reason. Max 5 reasons. If no signals trigger, return `["Transaction appears normal based on available data."]`.
- **`feature_contributions`**: One entry per feature that has a non-zero `impact` value. `impact` = `normalized_value * weight`. Features with zero normalized value (e.g. a high-frequency uid with `1.0 - 50/50 = 0.0`) are excluded because their impact is literally zero. This is correct behavior: the feature is present in the scoring but contributes no risk.

Note: the `value` field in `feature_contributions` uses the **raw** feature value (same as in `features` dict). The `impact` field uses the **normalized** value times the weight.

### 12. Fusion Layer

Phase 4A: heuristic-only mode.
- `scores.heuristic` = computed heuristic score
- `scores.supervised` = `null`
- `scores.anomaly` = `null`
- `risk.score` = `scores.heuristic`
- `risk.confidence` = `1.0` (full confidence in heuristic, no model uncertainty)
- `fusion_version` = `"default_v1"` (matches config, contract, and all mock fixtures)

### 13. Latency Measurement

Owned by `engine.score()`. Wraps the entire scoring pipeline (feature computation + scoring + signals + alerts + explainability + response construction) in `time.perf_counter()`. Reports as `int(elapsed_ms)`.

### 14. Engine Class Transition

`StubRiskEngine` is replaced by a new concrete class (e.g. `HeuristicRiskEngine`) that implements the real pipeline. `StubRiskEngine` is removed. `app/risk/dependencies.py` is updated to import and cache the new class. `tests/test_risk_engine.py` is updated to use the new class.

### 15. Sample Data Ingestion

Add helpers in `app/utils/data_loader.py`:
- `load_paysim_sample(path) -> list[ScoreRequest]` — converts `upi_sample.csv` rows
- `load_ieee_sample(txn_path, identity_path) -> list[ScoreRequest]` — converts IEEE CSV rows with identity left-join

### 16. Testing Plan

| Test File | Tests |
|---|---|
| `tests/test_paysim_features.py` | Feature computation on known inputs, state isolation, causal ordering |
| `tests/test_ieee_features.py` | Feature computation, uid construction, identity_present derivation |
| `tests/test_heuristic_scoring.py` | Normalization rules, weight application, score clamping |
| `tests/test_risk_engine.py` | End-to-end scoring, domain routing, response format (updated for new engine) |
| `tests/test_alerts.py` | Alert generation thresholds, recommended_action mapping, alert store behavior |
| `tests/test_api_contract.py` | Response matches `frontend_api_contract_v1.json` |
| `tests/test_frontend_mocks.py` | Structure compatibility with `frontend_mock_responses.json` (validates field presence, types, enums — not exact values) |
| `tests/test_sample_loading.py` | CSV ingestion, ScoreRequest construction |

### 17. Mock Compatibility Strategy

`frontend_mock_responses.json` contains synthetic example responses with pre-seeded state and specific feature values that depend on transaction history we cannot exactly reproduce at test time. Therefore, `test_frontend_mocks.py` validates **structural compatibility** — correct field names, correct types, valid enum values, correct feature keys per domain — rather than exact value matching. This ensures the contract is met without coupling tests to arbitrary mock numbers.
