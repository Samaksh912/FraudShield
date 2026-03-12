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
