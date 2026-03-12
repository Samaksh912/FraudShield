from __future__ import annotations

from typing import Any

from pydantic import BaseModel, ConfigDict, Field


IEEE_TRANSACTION_C_FIELDS = [f"C{i}" for i in range(1, 15)]
IEEE_TRANSACTION_D_FIELDS = [f"D{i}" for i in range(1, 16)]
IEEE_TRANSACTION_M_FIELDS = [f"M{i}" for i in range(1, 10)]
IEEE_TRANSACTION_V_FIELDS = [f"V{i}" for i in range(1, 340)]
IEEE_IDENTITY_FIELDS = [f"id_{i:02d}" for i in range(1, 39)]


def _coerce_value(value: Any) -> Any:
    if value == "":
        return None
    return value


class IeeeCisRawTransactionRecord(BaseModel):
    model_config = ConfigDict(extra="forbid")

    TransactionID: int
    isFraud: int | None = None
    TransactionDT: int
    TransactionAmt: float
    ProductCD: str
    card1: int
    card2: float | None = None
    card3: float | None = None
    card4: str | None = None
    card5: float | None = None
    card6: str | None = None
    addr1: float | None = None
    addr2: float | None = None
    dist1: float | None = None
    dist2: float | None = None
    P_emaildomain: str | None = None
    R_emaildomain: str | None = None
    c_features: dict[str, float | None] = Field(default_factory=dict)
    d_features: dict[str, float | None] = Field(default_factory=dict)
    m_features: dict[str, str | None] = Field(default_factory=dict)
    v_features: dict[str, float | None] = Field(default_factory=dict)

    @classmethod
    def from_flat_record(cls, row: dict[str, Any]) -> "IeeeCisRawTransactionRecord":
        core = {
            key: _coerce_value(value)
            for key, value in row.items()
            if key
            not in (
                IEEE_TRANSACTION_C_FIELDS
                + IEEE_TRANSACTION_D_FIELDS
                + IEEE_TRANSACTION_M_FIELDS
                + IEEE_TRANSACTION_V_FIELDS
            )
        }
        core["c_features"] = {key: _coerce_value(row.get(key)) for key in IEEE_TRANSACTION_C_FIELDS}
        core["d_features"] = {key: _coerce_value(row.get(key)) for key in IEEE_TRANSACTION_D_FIELDS}
        core["m_features"] = {key: _coerce_value(row.get(key)) for key in IEEE_TRANSACTION_M_FIELDS}
        core["v_features"] = {key: _coerce_value(row.get(key)) for key in IEEE_TRANSACTION_V_FIELDS}
        return cls.model_validate(core)


class IeeeCisIdentityRecord(BaseModel):
    model_config = ConfigDict(extra="forbid")

    TransactionID: int
    id_features: dict[str, float | str | None] = Field(default_factory=dict)
    DeviceType: str | None = None
    DeviceInfo: str | None = None

    @classmethod
    def from_flat_record(cls, row: dict[str, Any]) -> "IeeeCisIdentityRecord":
        core = {
            "TransactionID": _coerce_value(row.get("TransactionID")),
            "DeviceType": _coerce_value(row.get("DeviceType")),
            "DeviceInfo": _coerce_value(row.get("DeviceInfo")),
            "id_features": {key: _coerce_value(row.get(key)) for key in IEEE_IDENTITY_FIELDS},
        }
        return cls.model_validate(core)

