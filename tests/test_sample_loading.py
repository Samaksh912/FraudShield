from pathlib import Path

from app.domains.ieee_cis.schemas import IeeeCisIdentityRecord, IeeeCisRawTransactionRecord
from app.domains.paysim.schemas import PaySimRawEventRecord
from app.utils.data_loader import load_csv_rows, load_paysim_sample, load_ieee_sample


BASE_DIR = Path(__file__).resolve().parents[1]


def test_load_upi_sample_rows() -> None:
    rows = load_csv_rows(BASE_DIR / "upi_sample.csv")
    assert rows
    record = PaySimRawEventRecord.model_validate(rows[0])
    assert record.nameOrig
    assert record.step >= 0


def test_load_ieee_transaction_sample_rows() -> None:
    rows = load_csv_rows(BASE_DIR / "ieee_transaction_sample.csv")
    assert rows
    record = IeeeCisRawTransactionRecord.from_flat_record(rows[0])
    assert record.TransactionID > 0
    assert "V1" in record.v_features


def test_load_ieee_identity_sample_rows() -> None:
    rows = load_csv_rows(BASE_DIR / "ieee_identity_sample.csv")
    assert rows
    record = IeeeCisIdentityRecord.from_flat_record(rows[0])
    assert record.TransactionID > 0
    assert "id_01" in record.id_features


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
