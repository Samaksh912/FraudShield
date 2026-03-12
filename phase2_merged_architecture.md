# Phase 2 Merged Backend Architecture

## 1. Architecture Overview

### Recommended approach

Build a modular monolith with FastAPI and a central `RiskEngine`.

- `RiskEngine` is the single orchestration layer for all scoring.
- `PaySimAdapter` handles UPI-like payments.
- `IeeeCisAdapter` handles card transactions and identity/device joins.
- Shared services handle:
  - supervised scoring
  - anomaly scoring
  - heuristic fallback scoring
  - risk fusion
  - alert generation
  - explainability
  - artifact loading
- The frontend consumes one universal JSON contract across all domains.
- Kaggle training remains fully outside the serving app.

### Hackathon-optimal architecture

This is not the ideal production architecture. It is the best tradeoff for a 12-hour build:

- one backend service
- one API contract
- one shared engine
- separate domain modules
- in-memory state for causal history features
- versioned exported artifacts from Kaggle

### Runtime shape

```text
Frontend Dashboard
      |
      v
   FastAPI
      |
      v
  RiskEngine
   |   |   |   \
   |   |   |    +--> Explainability
   |   |   +-------> AlertService
   |   +-----------> FusionService
   +---------------> DomainAdapter
                        |
                        +--> Online feature calculators
                        +--> Domain validation / normalization
      |
      +--> ArtifactLoader / ModelRegistry
      +--> InMemoryStateStore
```

### Component responsibilities

| Component | Responsibility | MVP |
|---|---|---|
| FastAPI routes | `/v1/score`, `/v1/batch`, `/v1/alerts`, `/v1/health`, optional `/v1/admin/models` | Yes |
| Domain adapters | Validate and normalize domain payloads | Yes |
| Online feature layer | Compute causal online features | Yes |
| `RiskEngine` | Orchestrate scoring and response building | Yes |
| Supervised model loader | Load Kaggle-exported model artifacts | Yes |
| Anomaly path | Optional second signal if artifact exists | Partial |
| Fusion layer | Combine supervised, anomaly, heuristic scores | Yes |
| Alert service | Emit alert objects and keep recent alerts | Yes |
| Explainability layer | Produce top reasons, signals, and evidence | Yes |
| Training ingestion | Load `.csv` / `.parquet` offline | Yes |

## 2. Key Design Principles

1. Domain-specific logic stays in domain packages.
   `RiskEngine` orchestrates; adapters and feature modules own domain behavior.

2. Training and serving are separate systems.
   Kaggle exports artifacts; the backend only loads and serves them.

3. Online features must be causal.
   Only transactions with timestamp `< current_transaction_time` may influence live features.

4. The app must fail open.
   If models are missing, scoring falls back to deterministic heuristic logic instead of failing.

5. Use one frontend contract.
   The frontend should never branch on PaySim vs IEEE-CIS response shape.

6. Keep the structure flat enough for a hackathon.
   Avoid excessive abstraction and deep package nesting.

7. Preserve extension readiness.
   Net Banking should be addable as a new domain adapter without refactoring the shared engine.

8. Prefer explicit contracts over implicit coupling.
   Feature names, defaults, thresholds, and artifact metadata must be versioned.

### Hackathon heuristics

- Weighted fusion is a heuristic choice optimized for explainability and speed.
- In-memory state is acceptable for demo traffic.
- Rule-based scoring should ship before ML integration.

## 3. Detailed Directory Tree

```text
Layer/
├── app/
│   ├── __init__.py
│   ├── main.py
│   ├── config.yaml
│   ├── config.py
│   ├── api/
│   │   ├── __init__.py
│   │   ├── routes_score.py
│   │   ├── routes_batch.py
│   │   ├── routes_alerts.py
│   │   ├── routes_health.py
│   │   └── routes_admin.py
│   ├── risk/
│   │   ├── __init__.py
│   │   ├── engine.py
│   │   ├── fusion.py
│   │   ├── alerts.py
│   │   ├── explainability.py
│   │   ├── heuristic_scoring.py
│   │   └── artifact_loader.py
│   ├── domains/
│   │   ├── __init__.py
│   │   ├── base.py
│   │   ├── paysim/
│   │   │   ├── __init__.py
│   │   │   ├── adapter.py
│   │   │   ├── schemas.py
│   │   │   ├── features_online.py
│   │   │   ├── explanations.py
│   │   │   └── feature_contract.yaml
│   │   ├── ieee_cis/
│   │   │   ├── __init__.py
│   │   │   ├── adapter.py
│   │   │   ├── schemas.py
│   │   │   ├── features_online.py
│   │   │   ├── explanations.py
│   │   │   └── feature_contract.yaml
│   │   └── net_banking/
│   │       ├── __init__.py
│   │       ├── adapter.py
│   │       ├── schemas.py
│   │       └── feature_contract.yaml
│   ├── state/
│   │   ├── __init__.py
│   │   ├── store.py
│   │   └── in_memory.py
│   ├── schemas/
│   │   ├── __init__.py
│   │   ├── common.py
│   │   ├── requests.py
│   │   └── responses.py
│   └── utils/
│       ├── __init__.py
│       ├── data_loader.py
│       ├── math_utils.py
│       └── time_utils.py
├── training/
│   ├── common/
│   │   ├── io.py
│   │   ├── splitters.py
│   │   ├── validators.py
│   │   └── artifact_manifest.py
│   ├── paysim/
│   │   ├── feature_build.py
│   │   ├── train_supervised.py
│   │   ├── train_anomaly.py
│   │   └── export_artifacts.py
│   ├── ieee_cis/
│   │   ├── identity_join.py
│   │   ├── feature_build.py
│   │   ├── train_supervised.py
│   │   ├── train_anomaly.py
│   │   └── export_artifacts.py
│   └── kaggle/
│       ├── README.md
│       ├── export_spec.md
│       └── sample_manifest.json
├── artifacts/
│   ├── manifests/
│   │   ├── paysim_latest.json
│   │   └── ieee_cis_latest.json
│   ├── paysim/
│   │   └── v1/
│   └── ieee_cis/
│       └── v1/
├── data/
│   ├── raw/
│   ├── samples/
│   └── demo/
├── frontend/
├── tests/
│   ├── test_risk_engine.py
│   ├── test_paysim_features.py
│   ├── test_ieee_features.py
│   ├── test_api_contract.py
│   └── test_artifact_manifest.py
├── scripts/
│   ├── run_api.sh
│   └── seed_demo_events.py
├── pyproject.toml
├── .env.example
└── README.md
```

### Why this merged tree is better

- Simpler than the first architecture file.
- Safer than the second because it keeps explicit state and artifact contracts.
- Clean split between `app/`, `training/`, and `artifacts/`.

## 4. Data Flow

### A. Training-data ingestion

`training/common/io.py` should provide:

- `.csv` loading via `pandas.read_csv`
- `.parquet` loading via `pandas.read_parquet`
- required-column validation
- optional dtype coercion

### B. Offline feature engineering

Each domain has offline training feature code:

- `training/paysim/feature_build.py`
- `training/ieee_cis/feature_build.py`

These scripts must:

- implement Phase 1 causal feature rules
- use only prior-history windows
- produce stable feature names
- export metadata aligned with online inference

### C. Kaggle training workflow

For each domain:

1. Load raw data.
2. Build causal training features.
3. Train supervised model.
4. Optionally train anomaly model.
5. Export artifacts plus manifest.

### D. Exported artifact package

Each Kaggle export should look like:

```text
artifacts/paysim/v1/
├── supervised_model.joblib
├── anomaly_model.joblib
├── feature_order.json
├── feature_defaults.json
├── thresholds.json
├── metrics.json
├── metadata.json
└── manifest.json
```

`manifest.json` should include:

- `domain`
- `artifact_version`
- `model_family`
- `created_at`
- `feature_order`
- `required_raw_fields`
- `online_features`
- `training_features`
- `score_mapping`
- `alert_thresholds`

This is better than `metadata.json` alone because it is sufficient for safe model loading.

### E. FastAPI artifact loading strategy

At startup:

1. Read `artifacts/manifests/*_latest.json`
2. Resolve active version per domain
3. Load available models and metadata
4. Validate feature alignment
5. If missing, register the domain as `heuristic_only`

### F. Online inference flow

For `POST /score`:

1. Request enters FastAPI
2. Shared request shell is validated
3. Domain adapter validates domain payload
4. Adapter computes causal online features using current payload + prior state
5. `RiskEngine` invokes:
   - heuristic scorer
   - supervised scorer if available
   - anomaly scorer if available
6. Fusion layer combines scores
7. Alert service emits alerts if thresholds trigger
8. Explainability layer produces reasons and signals
9. State store updates after scoring
10. Universal JSON response returns

### G. Online state strategy

MVP:

- use `InMemoryStateStore`
- keep rolling counters, rolling stats, and seen sets only
- seed demo history at startup if needed

Future:

- replace with Redis behind the same interface

Examples:

- PaySim state:
  - sender transaction timestamps
  - sender rolling amount stats
  - seen `(sender, beneficiary)` pairs
  - destination recent inbound counts
- IEEE-CIS state:
  - `uid` prior counts
  - `uid` rolling spend stats
  - `uid` seen devices
  - `uid-product` seen pairs

### H. MVP feature policy: 6 now, 9 extension-ready

Phase 1 defined 9 engineered features per domain.
For the 12-hour MVP, the serving app should implement the 6-feature subset explicitly recommended in the Phase 1 MVP summary, while keeping the remaining 3 features extension-ready in the domain contracts and training code.

#### PaySim

Phase 1 full feature table:

- `type_risk_flag`
- `amount_to_orig_balance_ratio`
- `orig_balance_consistency_error`
- `dest_balance_consistency_error`
- `orig_balance_drain_pct`
- `sender_txn_count_24h`
- `sender_amount_zscore_7d`
- `sender_dest_pair_novelty`
- `dest_inbound_txn_count_24h`

MVP online implementation set:

- `type_risk_flag`
- `amount_to_orig_balance_ratio`
- `orig_balance_consistency_error`
- `sender_txn_count_24h`
- `sender_amount_zscore_7d`
- `sender_dest_pair_novelty`

Extension-ready after MVP:

- `dest_balance_consistency_error`
- `orig_balance_drain_pct`
- `dest_inbound_txn_count_24h`

#### IEEE-CIS

Phase 1 full feature table:

- `uid_prior_frequency`
- `amt_to_uid_median_ratio`
- `uid_txn_count_24h`
- `uid_amt_sum_24h`
- `uid_product_novelty`
- `email_domain_mismatch`
- `new_device_for_uid`
- `dist1_to_uid_median_ratio`
- `identity_present`

MVP online implementation set:

- `uid_prior_frequency`
- `amt_to_uid_median_ratio`
- `uid_txn_count_24h`
- `email_domain_mismatch`
- `new_device_for_uid`
- `identity_present`

Extension-ready after MVP:

- `uid_amt_sum_24h`
- `uid_product_novelty`
- `dist1_to_uid_median_ratio`

Frontend guidance:

- scoring and alerting must work with the 6-feature MVP set
- dashboard detail views may later surface all 9 when the extra online features are implemented
- Kaggle training may use the broader 9-feature engineered set plus raw masked competition features

## 5. Universal JSON Response Contract

### Request

```json
{
  "request_id": "4f1db8e3-4741-41d8-8df4-5ab7f8a9d901",
  "domain": "paysim",
  "event_time": "2026-03-12T10:15:00Z",
  "transaction": {
    "transaction_id": "txn_1001",
    "amount": 125000.0,
    "currency": "INR",
    "channel": "upi"
  },
  "context": {
    "source": "dashboard-demo"
  },
  "payload": {
    "step": 278,
    "type": "TRANSFER",
    "nameOrig": "C123",
    "nameDest": "C456",
    "oldbalanceOrg": 150000.0,
    "newbalanceOrig": 25000.0,
    "oldbalanceDest": 10000.0,
    "newbalanceDest": 135000.0
  }
}
```

### Response

```json
{
  "request_id": "4f1db8e3-4741-41d8-8df4-5ab7f8a9d901",
  "status": "ok",
  "domain": "paysim",
  "transaction_id": "txn_1001",
  "input_snapshot": {
    "transaction": {
      "transaction_id": "txn_1001",
      "amount": 125000.0,
      "currency": "INR",
      "channel": "upi"
    },
    "payload": {
      "step": 278,
      "type": "TRANSFER",
      "nameOrig": "C123",
      "nameDest": "C456",
      "oldbalanceOrg": 150000.0,
      "newbalanceOrig": 25000.0,
      "oldbalanceDest": 10000.0,
      "newbalanceDest": 135000.0
    }
  },
  "risk": {
    "score": 0.864,
    "level": "high",
    "decision": "review",
    "confidence": 0.82
  },
  "scores": {
    "heuristic": 0.88,
    "supervised": 0.91,
    "anomaly": null,
    "fusion_version": "default_v1"
  },
  "signals": [
    {
      "code": "HIGH_AMOUNT_TO_BALANCE_RATIO",
      "severity": "high",
      "value": 0.83,
      "threshold": 0.7,
      "message": "Transfer amount is unusually large relative to sender balance."
    }
  ],
  "explanations": {
    "top_reasons": [
      "Large transfer relative to available balance",
      "New sender-beneficiary pair",
      "Sender activity is elevated in the last 24 hours"
    ],
    "feature_contributions": [
      {
        "feature": "amount_to_orig_balance_ratio",
        "value": 0.8333,
        "impact": 0.31
      }
    ]
  },
  "features": {
    "type_risk_flag": 1,
    "amount_to_orig_balance_ratio": 0.8333,
    "orig_balance_consistency_error": 0.0,
    "sender_txn_count_24h": 6,
    "sender_amount_zscore_7d": 2.9,
    "sender_dest_pair_novelty": 1
  },
  "alerts": [
    {
      "alert_id": "alrt_9c3b",
      "type": "suspicious_transaction",
      "priority": "high",
      "status": "open",
      "recommended_action": "step_up_verification"
    }
  ],
  "transaction_summary": {
    "amount": 125000.0,
    "currency": "INR",
    "channel": "upi",
    "product_code": null,
    "card_network": null,
    "funding_type": null
  },
  "model": {
    "artifact_version": "v1",
    "mode": "model_plus_rules",
    "engine_version": "0.1.0"
  },
  "latency_ms": 24
}
```

### Why this merged contract is the right one

- Keeps the rich dashboard support from the first file.
- Keeps the frontend simplicity from the second file.
- Still works when anomaly is absent or when the app is in heuristic-only mode.

Scale policy:

- all numeric scores in the API are normalized to `0.0` to `1.0`
- the frontend may multiply by 100 for display
- `risk.score`, `scores.heuristic`, `scores.supervised`, and `scores.anomaly` must stay on the same scale

IEEE-CIS `transaction_summary` mapping should be adapter-driven.
Typical fields:

- `amount` from `TransactionAmt`
- `currency` defaulted by app config
- `channel` set to `"card"`
- `product_code` from `ProductCD`
- `card_network` from `card4`
- `funding_type` from `card6`

### Minimum endpoints

- `POST /v1/score`
- `POST /v1/batch`
- `GET /v1/alerts`
- `GET /v1/health`
- `GET /v1/admin/models`

## 6. Recommended Python Packages

### Required

| Package | Why |
|---|---|
| `fastapi` | API framework |
| `uvicorn` | ASGI server |
| `pydantic` | request/response validation |
| `pydantic-settings` | config loading |
| `pandas` | `.csv` / `.parquet` loading and feature work |
| `pyarrow` | parquet support |
| `numpy` | numeric transforms |
| `scikit-learn` | anomaly models, utilities |
| `joblib` | model serialization |
| `pyyaml` | config file loading |
| `pytest` | tests |
| `httpx` | FastAPI API tests |

### Choose one supervised library

- `lightgbm` recommended for hackathon speed and tabular performance
- `xgboost` only if the team is already more comfortable with it

### Optional

- `orjson` for faster JSON
- `redis` only if in-memory state becomes a blocker
- `shap` only if there is time for richer explainability

## 7. Suggested Work Split for 2 People

### First 45 minutes: shared lock

Both people jointly lock:

- universal JSON request/response shape
- `DomainAdapter` interface
- `RiskEngine` method signatures
- feature names and null policy
- artifact manifest format
- `config.yaml` structure

After that, shared modules are effectively frozen.

### Person A

- own `domains/paysim/`
- implement PaySim schemas, adapter, online features, explanations
- own `training/paysim/`
- integrate PaySim model export

### Person B

- own `domains/ieee_cis/`
- implement IEEE schemas, adapter, identity join assumptions, online features, explanations
- own `training/ieee_cis/`
- integrate IEEE model export

### Shared modules

- `app/risk/`
- `app/api/`
- `app/schemas/`
- `app/state/`

These should be scaffolded early and changed minimally.

### Milestones

| Time | Target |
|---|---|
| Hour 1 | shared contracts locked, app skeleton exists |
| Hour 4 | both domains return heuristic scores |
| Hour 7 | at least one Kaggle model integrated |
| Hour 9 | alerts and dashboard contract working |
| Hour 11 | demo scripts and sample transactions polished |

## 8. MVP Scope vs Future Scope

### MVP-critical

- FastAPI backend
- central `RiskEngine`
- PaySim adapter
- IEEE-CIS adapter
- six explicitly defined MVP online features per domain
- heuristic scoring
- supervised model loading
- fusion layer
- alert generation
- explainability payload
- universal JSON response
- in-memory causal state

### MVP-important but can be thin

- anomaly scoring path
- batch endpoint
- admin model status endpoint
- seeded demo transactions

### Future scope

- Net Banking implementation
- Redis-backed state
- persistent alerts
- streaming/WebSocket alerts
- SHAP explanations
- graph features
- analyst feedback loops
- auth and RBAC

## 9. Risks, Tradeoffs, and Time-Saving Simplifications

### Main risks

1. Training-serving mismatch
   Fix with manifest validation and stable feature contracts.

2. Overbuilding the IEEE-CIS side
   Keep the app-side online features narrow; let Kaggle use broader features later.

3. Real-time history dependence
   Use in-memory rolling state and seeded demo histories.

4. Demo failure due to missing model artifacts
   Keep heuristic-only mode working from the start.

### Tradeoffs

| Decision | Chosen for MVP | Why |
|---|---|---|
| Architecture | modular monolith | lowest integration risk |
| Alert storage | in-memory | no DB setup needed |
| Feature history | in-memory state | fast and good enough for demo |
| Explainability | rule-based top reasons | simpler than SHAP |
| Artifact management | folder + manifest | enough for hackathon |
| Config | one `config.yaml` plus optional domain contracts | simpler than many config files |

### Time-saving simplifications

1. Ship heuristic scoring first.
2. Limit app-side online scoring to the explicitly listed six-feature MVP subset per domain.
3. Keep anomaly optional.
4. No Docker unless deployment actually needs it.
5. No database for MVP.
6. Seed demo events early so the frontend can be built in parallel.

## 10. Testability Boundaries

- unit-test domain online feature functions
- unit-test score fusion
- unit-test `RiskEngine` with mocked adapters and models
- contract-test API JSON shape
- test artifact manifest validation

Do not rely on live Kaggle artifacts for core tests.

## 11. Simple Local Development Flow

1. Scaffold the merged directory structure.
2. Implement heuristic-only scoring first.
3. Run FastAPI locally with:

```bash
uvicorn app.main:app --reload
```

4. Seed sample events for PaySim and IEEE-CIS.
5. Build the frontend against the universal response contract.
6. Drop Kaggle artifacts into `artifacts/` when ready.
7. Restart the app and verify model-backed scoring.

## Final Recommendation

This merged architecture should be the Phase 2 source of truth.

It keeps:

- the stronger technical correctness of `phase2_backend_architecture.md`
- the stronger execution discipline of `phase2_plan_claude.md`

Most importantly, it is realistic for a 12-hour hackathon without giving up the hard requirements around `RiskEngine`, FastAPI, causal features, artifact loading, and dashboard-ready outputs.
