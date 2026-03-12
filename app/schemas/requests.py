from __future__ import annotations

from datetime import datetime
from typing import Any

from pydantic import BaseModel, ConfigDict, Field, model_validator

from app.schemas.common import ContextInput, DomainName, TransactionInput


class PaySimScorePayload(BaseModel):
    model_config = ConfigDict(extra="forbid")

    step: int
    type: str
    nameOrig: str
    nameDest: str
    oldbalanceOrg: float
    newbalanceOrig: float | None = None
    oldbalanceDest: float | None = None
    newbalanceDest: float | None = None


class IeeeCisScorePayload(BaseModel):
    model_config = ConfigDict(extra="forbid")

    TransactionDT: int
    TransactionAmt: float
    ProductCD: str
    card1: int
    card2: float
    card3: float
    card5: float
    addr1: float
    addr2: float
    card4: str | None = None
    card6: str | None = None
    dist1: float | None = None
    P_emaildomain: str | None = None
    R_emaildomain: str | None = None
    DeviceType: str | None = None
    DeviceInfo: str | None = None
    id_30: str | None = None
    id_31: str | None = None
    id_33: str | None = None
    identity_present: int | None = None


PayloadModel = PaySimScorePayload | IeeeCisScorePayload


class ScoreRequest(BaseModel):
    model_config = ConfigDict(extra="forbid")

    request_id: str
    domain: DomainName
    event_time: datetime
    transaction: TransactionInput
    payload: PayloadModel
    context: ContextInput | None = None

    @model_validator(mode="after")
    def validate_domain_payload_alignment(self) -> "ScoreRequest":
        if self.domain == DomainName.PAYSIM:
            if not isinstance(self.payload, PaySimScorePayload):
                raise ValueError("paysim requests must use PaySimScorePayload")
            if self.transaction.channel != "upi":
                raise ValueError("paysim requests must use transaction.channel='upi'")
        if self.domain == DomainName.IEEE_CIS:
            if not isinstance(self.payload, IeeeCisScorePayload):
                raise ValueError("ieee_cis requests must use IeeeCisScorePayload")
            if self.transaction.channel != "card":
                raise ValueError("ieee_cis requests must use transaction.channel='card'")
        return self


class BatchScoreItem(BaseModel):
    model_config = ConfigDict(extra="forbid")

    request_id: str
    event_time: datetime
    transaction: TransactionInput
    payload: PayloadModel
    context: ContextInput | None = None


class BatchScoreRequest(BaseModel):
    model_config = ConfigDict(extra="forbid")

    domain: DomainName
    items: list[BatchScoreItem] = Field(min_length=1)

    @model_validator(mode="after")
    def validate_items(self) -> "BatchScoreRequest":
        for item in self.items:
            if self.domain == DomainName.PAYSIM:
                if not isinstance(item.payload, PaySimScorePayload):
                    raise ValueError("paysim batch items must use PaySimScorePayload")
                if item.transaction.channel != "upi":
                    raise ValueError("paysim batch items must use transaction.channel='upi'")
            if self.domain == DomainName.IEEE_CIS:
                if not isinstance(item.payload, IeeeCisScorePayload):
                    raise ValueError("ieee_cis batch items must use IeeeCisScorePayload")
                if item.transaction.channel != "card":
                    raise ValueError("ieee_cis batch items must use transaction.channel='card'")
        return self

    def to_score_requests(self) -> list[ScoreRequest]:
        requests: list[ScoreRequest] = []
        for item in self.items:
            requests.append(
                ScoreRequest(
                    request_id=item.request_id,
                    domain=self.domain,
                    event_time=item.event_time,
                    transaction=item.transaction,
                    payload=item.payload,
                    context=item.context,
                )
            )
        return requests

