import json
from pathlib import Path

from app.schemas.responses import ScoreResponse


BASE_DIR = Path(__file__).resolve().parents[1]


def test_score_response_contract_example_validates() -> None:
    contract = json.loads((BASE_DIR / "frontend_api_contract_v1.json").read_text())
    response = ScoreResponse.model_validate(contract["examples"]["score_response"])
    assert response.domain.value == "paysim"
    assert response.risk.score <= 1.0


def test_required_top_level_fields_match_contract() -> None:
    contract = json.loads((BASE_DIR / "frontend_api_contract_v1.json").read_text())
    required = set(contract["endpoints"]["score"]["response"]["top_level_required"])
    example_keys = set(contract["examples"]["score_response"].keys())
    assert required == example_keys

