import json
from pathlib import Path

from app.schemas.responses import AlertsListResponse, HealthResponse, ScoreResponse


BASE_DIR = Path(__file__).resolve().parents[1]


def test_score_response_mocks_validate() -> None:
    mocks = json.loads((BASE_DIR / "frontend_mock_responses.json").read_text())
    for item in mocks["mocks"]["score_responses"]:
        ScoreResponse.model_validate(item["response"])


def test_alerts_response_mock_validates() -> None:
    mocks = json.loads((BASE_DIR / "frontend_mock_responses.json").read_text())
    AlertsListResponse.model_validate(mocks["mocks"]["alerts_response"])


def test_health_response_mock_validates() -> None:
    mocks = json.loads((BASE_DIR / "frontend_mock_responses.json").read_text())
    HealthResponse.model_validate(mocks["mocks"]["health_response"])

