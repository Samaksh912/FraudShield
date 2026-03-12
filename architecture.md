# Architecture Summary

This repository follows [phase2_merged_architecture.md](/home/arnavbansal/Layer/phase2_merged_architecture.md) as the Phase 2 source of truth.

## Runtime shape

- FastAPI serves `/v1` routes.
- `RiskEngine` is the central scoring interface.
- `PaySimAdapter` and `IeeeCisAdapter` isolate domain-specific request normalization.
- CSV and parquet ingestion stay outside serving logic.
- Kaggle-trained artifacts are loaded through manifest-aware loader hooks.
- The app must work with no artifacts in `heuristic_only` mode.

## Locked API contract

The request and response models in `app/schemas/` must stay aligned with:

- `frontend_api_contract_v1.json`
- `frontend_mock_responses.json`

The `/v1/score` response must include:

- `input_snapshot`
- `risk`
- `scores`
- `signals`
- `explanations`
- `features`
- `alerts`
- `transaction_summary`
- `model`

## Domain policy

- PaySim and IEEE-CIS remain fully separated at the schema and adapter level.
- Net Banking is scaffold-only in Phase 3.
- The app-side online MVP feature set is the explicit 6-feature subset per domain from Phase 2.
- Offline training remains extension-ready for broader features.

## Phase 3 deliverables

- project scaffold
- typed request and response models
- raw-record schema models
- CSV/parquet loader stubs
- artifact loader stubs
- `RiskEngine` stub
- adapter stubs
- tests for contract safety and sample parsing

