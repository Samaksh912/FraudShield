from __future__ import annotations

from abc import ABC, abstractmethod

from app.schemas.common import DomainName, NormalizedTransaction, TransactionSummary
from app.schemas.requests import ScoreRequest


class DomainAdapter(ABC):
    domain: DomainName

    @abstractmethod
    def normalize(self, request: ScoreRequest) -> NormalizedTransaction:
        raise NotImplementedError

    @abstractmethod
    def build_transaction_summary(self, request: ScoreRequest) -> TransactionSummary:
        raise NotImplementedError

