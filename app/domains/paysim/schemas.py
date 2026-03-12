from __future__ import annotations

from pydantic import BaseModel, ConfigDict


class PaySimRawEventRecord(BaseModel):
    model_config = ConfigDict(extra="forbid")

    step: int
    type: str
    amount: float
    nameOrig: str
    oldbalanceOrg: float
    newbalanceOrig: float
    nameDest: str
    oldbalanceDest: float
    newbalanceDest: float
    isFraud: int | None = None
    isFlaggedFraud: int | None = None

