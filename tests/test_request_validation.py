import json
from pathlib import Path

from app.schemas.requests import BatchScoreRequest, ScoreRequest


BASE_DIR = Path(__file__).resolve().parents[1]


def load_contract() -> dict:
    return json.loads((BASE_DIR / "frontend_api_contract_v1.json").read_text())


def test_score_request_examples_validate() -> None:
    contract = load_contract()
    ScoreRequest.model_validate(contract["examples"]["score_request_paysim"])
    ScoreRequest.model_validate(contract["examples"]["score_request_ieee_cis"])


def test_batch_request_validates() -> None:
    contract = load_contract()
    paysim = contract["examples"]["score_request_paysim"]
    batch = {
        "domain": "paysim",
        "items": [
            {
                "request_id": paysim["request_id"],
                "event_time": paysim["event_time"],
                "transaction": paysim["transaction"],
                "payload": paysim["payload"],
                "context": paysim["context"],
            }
        ],
    }
    parsed = BatchScoreRequest.model_validate(batch)
    assert parsed.domain.value == "paysim"
    assert len(parsed.items) == 1

