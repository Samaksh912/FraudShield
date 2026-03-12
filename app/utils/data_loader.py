from __future__ import annotations

import csv
import uuid
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

from app.schemas.common import TransactionInput
from app.schemas.requests import (
    IeeeCisScorePayload,
    PaySimScorePayload,
    ScoreRequest,
)


def load_csv_rows(path: str | Path) -> list[dict[str, Any]]:
    file_path = Path(path)
    with file_path.open(newline="") as handle:
        return list(csv.DictReader(handle))


def load_tabular_rows(path: str | Path) -> list[dict[str, Any]]:
    file_path = Path(path)
    suffix = file_path.suffix.lower()
    if suffix == ".csv":
        return load_csv_rows(file_path)
    if suffix == ".parquet":
        try:
            import pandas as pd
        except ModuleNotFoundError as exc:
            raise RuntimeError("pandas is required to read parquet files") from exc
        return pd.read_parquet(file_path).to_dict(orient="records")
    raise ValueError(f"Unsupported file type: {suffix}")


def paysim_row_to_score_request(row: dict[str, Any]) -> ScoreRequest:
    return ScoreRequest(
        request_id=str(uuid.uuid4()),
        domain="paysim",
        event_time=datetime.now(tz=timezone.utc),
        transaction=TransactionInput(
            transaction_id=f"txn_ps_{uuid.uuid4().hex[:8]}",
            amount=float(row["amount"]),
            currency="INR",
            channel="upi",
        ),
        payload=PaySimScorePayload(
            step=int(row["step"]),
            type=row["type"],
            nameOrig=row["nameOrig"],
            nameDest=row["nameDest"],
            oldbalanceOrg=float(row["oldbalanceOrg"]),
            newbalanceOrig=float(row["newbalanceOrig"]) if row.get("newbalanceOrig") else None,
            oldbalanceDest=float(row["oldbalanceDest"]) if row.get("oldbalanceDest") else None,
            newbalanceDest=float(row["newbalanceDest"]) if row.get("newbalanceDest") else None,
        ),
    )


def ieee_row_to_score_request(
    txn_row: dict[str, Any],
    identity_row: dict[str, Any] | None = None,
) -> ScoreRequest:
    def _float_or_none(val: Any) -> float | None:
        if val is None or val == "":
            return None
        return float(val)

    def _str_or_none(val: Any) -> str | None:
        if val is None or val == "":
            return None
        return str(val)

    device_type = None
    device_info = None
    id_30 = None
    id_31 = None
    id_33 = None
    if identity_row:
        device_type = _str_or_none(identity_row.get("DeviceType"))
        device_info = _str_or_none(identity_row.get("DeviceInfo"))
        id_30 = _str_or_none(identity_row.get("id_30"))
        id_31 = _str_or_none(identity_row.get("id_31"))
        id_33 = _str_or_none(identity_row.get("id_33"))

    card4 = _str_or_none(txn_row.get("card4"))
    card6 = _str_or_none(txn_row.get("card6"))

    return ScoreRequest(
        request_id=str(uuid.uuid4()),
        domain="ieee_cis",
        event_time=datetime.now(tz=timezone.utc),
        transaction=TransactionInput(
            transaction_id=f"txn_ieee_{txn_row['TransactionID']}",
            amount=float(txn_row["TransactionAmt"]),
            currency="USD",
            channel="card",
            product_code=txn_row.get("ProductCD"),
            card_network=card4,
            funding_type=card6,
        ),
        payload=IeeeCisScorePayload(
            TransactionDT=int(txn_row["TransactionDT"]),
            TransactionAmt=float(txn_row["TransactionAmt"]),
            ProductCD=txn_row["ProductCD"],
            card1=int(txn_row["card1"]),
            card2=float(txn_row.get("card2", 0) or 0),
            card3=float(txn_row.get("card3", 0) or 0),
            card5=float(txn_row.get("card5", 0) or 0),
            addr1=float(txn_row.get("addr1", 0) or 0),
            addr2=float(txn_row.get("addr2", 0) or 0),
            card4=card4,
            card6=card6,
            dist1=_float_or_none(txn_row.get("dist1")),
            P_emaildomain=_str_or_none(txn_row.get("P_emaildomain")),
            R_emaildomain=_str_or_none(txn_row.get("R_emaildomain")),
            DeviceType=device_type,
            DeviceInfo=device_info,
            id_30=id_30,
            id_31=id_31,
            id_33=id_33,
        ),
    )


def load_paysim_sample(path: str | Path) -> list[ScoreRequest]:
    rows = load_csv_rows(path)
    return [paysim_row_to_score_request(row) for row in rows]


def load_ieee_sample(
    txn_path: str | Path,
    identity_path: str | Path,
) -> list[ScoreRequest]:
    txn_rows = load_csv_rows(txn_path)
    identity_rows = load_csv_rows(identity_path)
    identity_map: dict[str, dict[str, Any]] = {}
    for row in identity_rows:
        tid = row.get("TransactionID", "")
        if tid:
            identity_map[tid] = row

    requests: list[ScoreRequest] = []
    for txn_row in txn_rows:
        tid = txn_row.get("TransactionID", "")
        identity_row = identity_map.get(tid)
        requests.append(ieee_row_to_score_request(txn_row, identity_row))
    return requests
