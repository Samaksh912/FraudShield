from __future__ import annotations

from app.domains.base import DomainAdapter
from app.schemas.common import DomainName, NormalizedTransaction, TransactionSummary
from app.schemas.requests import ScoreRequest


class PaySimAdapter(DomainAdapter):
    domain = DomainName.PAYSIM

    def normalize(self, request: ScoreRequest) -> NormalizedTransaction:
        return NormalizedTransaction(
            request_id=request.request_id,
            domain=request.domain,
            event_time=request.event_time,
            transaction=request.transaction,
            payload=request.payload.model_dump(mode="python"),
            context=request.context,
        )

    def build_transaction_summary(self, request: ScoreRequest) -> TransactionSummary:
        return TransactionSummary(
            amount=request.transaction.amount,
            currency=request.transaction.currency,
            channel=request.transaction.channel,
            product_code=None,
            card_network=None,
            funding_type=None,
        )

