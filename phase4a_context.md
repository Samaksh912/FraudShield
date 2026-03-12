# Phase 4A Context

## Objective

Implement the core MVP inference pipeline for the fraud detection system.

This phase is for:

- FastAPI routes
- `RiskEngine` runtime orchestration
- domain routing
- online feature calculation
- heuristic-only scoring
- alert generation
- explainability placeholders
- contract-compliant responses

This phase is not for:

- real ML training
- local training workflows
- full Kaggle artifact integration
- frontend implementation

## Hackathon Constraints

- Total build time is 12 hours
- Final product must be a working web app
- Training happens in Kaggle, not inside the app runtime
- Backend must run even when no trained artifacts exist
- Heuristic-only mode is required as a safe fallback

## Source Of Truth

Use these files as binding references:

- `phase2_merged_architecture.md`
- `architecture.md`
- `frontend_api_contract_v1.json`
- `frontend_mock_responses.json`
- `upi_sample.csv`
- `ieee_transaction_sample.csv`
- `ieee_identity_sample.csv`

## Implemented Domains

- `paysim`: UPI-like digital payments
- `ieee_cis`: card fraud

Extension-ready but not implemented in this phase:

- `net_banking`

Out of MVP scope:

- `blockchain`

## Required Endpoints

- `POST /v1/score`
- `POST /v1/batch`
- `GET /v1/alerts`
- `GET /v1/health`
- `GET /v1/admin/models`

The endpoints must follow `frontend_api_contract_v1.json`.

## Required Response Shape

Every score response must include:

- `request_id`
- `status`
- `domain`
- `transaction_id`
- `input_snapshot`
- `risk`
- `scores`
- `signals`
- `explanations`
- `features`
- `alerts`
- `transaction_summary`
- `model`
- `latency_ms`

Important:

- `input_snapshot` must echo the transaction and payload used for scoring
- all scores must be normalized to `0.0` to `1.0`
- response shape must remain stable across domains

## Scoring Policy For Phase 4A

Use heuristic-only scoring or stubbed scoring.

Do not:

- train models
- depend on real trained artifacts
- require anomaly models to exist

The system must still expose:

- `scores.heuristic`
- `scores.supervised`
- `scores.anomaly`
- `risk.score`
- `risk.level`
- `risk.decision`

If supervised or anomaly outputs are unavailable:

- return `null` where the contract expects nullable fields
- keep the rest of the response valid

## PaySim MVP Online Features

Implement these six features in Phase 4A:

- `type_risk_flag`
- `amount_to_orig_balance_ratio`
- `orig_balance_consistency_error`
- `sender_txn_count_24h`
- `sender_amount_zscore_7d`
- `sender_dest_pair_novelty`

Feature notes:

- use `step` as hours
- history must be causal
- update state only after scoring the current transaction

## IEEE-CIS MVP Online Features

Implement these six features in Phase 4A:

- `uid_prior_frequency`
- `amt_to_uid_median_ratio`
- `uid_txn_count_24h`
- `email_domain_mismatch`
- `new_device_for_uid`
- `identity_present`

Feature notes:

- use `TransactionDT` as seconds
- construct `uid` from the agreed card/address fields
- detect new device from device-related fields and prior entity history
- update state only after scoring the current transaction

## In-Memory State Requirements

Use in-memory state for live history features.

Examples:

- PaySim:
  - sender transaction history
  - sender rolling amounts
  - seen sender-beneficiary pairs
- IEEE-CIS:
  - uid counts
  - uid rolling amounts
  - seen device signatures

This is acceptable for the MVP and should not be replaced with a database in Phase 4A.

## Alerting Requirements

Implement simple threshold-based alerts.

Each response should support:

- low / medium / high risk levels
- allow / review / block decisions
- alert priority
- recommended action

If no alert is triggered:

- return an empty `alerts` array

## Explainability Requirements

The response must contain:

- `signals`
- `explanations.top_reasons`
- `explanations.feature_contributions`

These can be heuristic placeholders in this phase, but must be meaningful and contract-compliant.

## Sample Data Requirements

Use:

- `upi_sample.csv`
- `ieee_transaction_sample.csv`
- `ieee_identity_sample.csv`

For IEEE-CIS:

- identity data is sparse
- not every transaction has a matching identity row
- code must handle that safely

## Testing Requirements

Phase 4A should keep or add tests for:

- sample file ingestion
- request validation
- response contract validation
- domain routing
- `RiskEngine` output format
- frontend mock compatibility
- alert generation behavior

Use the project virtual environment for test execution if shell `pytest` is unavailable.

## Success Criteria

Phase 4A is complete when:

- FastAPI app runs
- all required endpoints respond
- both domains score successfully
- responses match `frontend_api_contract_v1.json`
- responses remain compatible with `frontend_mock_responses.json`
- app works without trained artifacts
- frontend can proceed using the live or mocked API shape

