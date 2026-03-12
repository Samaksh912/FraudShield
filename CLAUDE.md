# CLAUDE.md

## Scope

This repository implements the backend scaffold for an AI-based financial fraud detection MVP built for a 12-hour hackathon.

Current implemented domains:

- `paysim` for UPI-like digital payments
- `ieee_cis` for card fraud

Extension-ready:

- `net_banking`

Explicitly out of MVP scope:

- `blockchain`

## Phase Boundaries

- Phase 3 owns scaffolding, typed schemas, API contracts, loaders, stubs, and tests.
- Phase 4 will add actual scoring logic, artifact-backed inference, and feature computation.
- Do not add real training code to the serving app.
- Do not couple frontend rendering logic into the backend.

## Contract Rules

- `frontend_api_contract_v1.json` is the API source of truth.
- `frontend_mock_responses.json` is the frontend compatibility source of truth.
- All API score values are normalized to `0.0` to `1.0`.
- The backend must preserve:
  - `input_snapshot`
  - `risk`
  - `scores`
  - `signals`
  - `explanations`
  - `features`
  - `alerts`
  - `transaction_summary`
  - `model`

## Engineering Conventions

- Prefer explicit typed models over clever abstractions.
- Keep PaySim and IEEE-CIS logic separated under `app/domains/`.
- Keep shared orchestration under `app/risk/`.
- Preserve a central `RiskEngine` interface.
- The app must run in `heuristic_only` mode with no model artifacts present.
- Treat causal history constraints as non-negotiable for future feature logic.
- Do not rename contract fields without updating tests and the source-of-truth JSON files.

## Repo Workflow

1. Lock shared interfaces first.
2. Implement domain-specific behavior behind adapters.
3. Keep training code in `training/`.
4. Keep Kaggle-exported artifacts under `artifacts/`.
5. Add or update tests whenever request/response models change.

## Guardrails

- Do not implement training inside FastAPI modules.
- Do not hardcode frontend-only derived formatting in response models.
- Do not add fields not present in the contract unless clearly optional and documented.
- Do not merge PaySim and IEEE-CIS schemas into one loose dict model.
- Do not assume artifacts exist at startup.
- Do not add database or queue infrastructure in MVP scaffolding unless specifically requested.

## Local Development

- Preferred startup command:
  - `uvicorn app.main:app --reload`
- Preferred test command:
  - `pytest`

## Expected Next Step

Phase 4 should implement:

- real adapter normalization logic
- feature computation
- heuristic scoring
- artifact-backed inference
- alert persistence behavior beyond in-memory stubs if time remains

