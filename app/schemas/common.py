from __future__ import annotations

from datetime import datetime
from enum import Enum
from typing import Any

from pydantic import BaseModel, ConfigDict, Field


FEATURE_KEYS_BY_DOMAIN: dict[str, list[str]] = {
    "paysim": [
        "type_risk_flag",
        "amount_to_orig_balance_ratio",
        "orig_balance_consistency_error",
        "sender_txn_count_24h",
        "sender_amount_zscore_7d",
        "sender_dest_pair_novelty",
    ],
    "ieee_cis": [
        "uid_prior_frequency",
        "amt_to_uid_median_ratio",
        "uid_txn_count_24h",
        "email_domain_mismatch",
        "new_device_for_uid",
        "identity_present",
    ],
}


class DomainName(str, Enum):
    PAYSIM = "paysim"
    IEEE_CIS = "ieee_cis"


class ApiStatus(str, Enum):
    OK = "ok"
    ERROR = "error"


class RiskLevel(str, Enum):
    LOW = "low"
    MEDIUM = "medium"
    HIGH = "high"


class RiskDecision(str, Enum):
    ALLOW = "allow"
    REVIEW = "review"
    BLOCK = "block"


class Severity(str, Enum):
    LOW = "low"
    MEDIUM = "medium"
    HIGH = "high"


class AlertPriority(str, Enum):
    LOW = "low"
    MEDIUM = "medium"
    HIGH = "high"


class AlertStatus(str, Enum):
    OPEN = "open"
    RESOLVED = "resolved"
    DISMISSED = "dismissed"


class ModelMode(str, Enum):
    HEURISTIC_ONLY = "heuristic_only"
    MODEL_PLUS_RULES = "model_plus_rules"


class TransactionInput(BaseModel):
    model_config = ConfigDict(extra="forbid")

    transaction_id: str
    amount: float
    currency: str
    channel: str
    product_code: str | None = None
    card_network: str | None = None
    funding_type: str | None = None


class ContextInput(BaseModel):
    model_config = ConfigDict(extra="forbid")

    source: str | None = None


class InputSnapshot(BaseModel):
    transaction: TransactionInput
    payload: dict[str, Any]


class TransactionSummary(BaseModel):
    amount: float
    currency: str
    channel: str
    product_code: str | None = None
    card_network: str | None = None
    funding_type: str | None = None


class NormalizedTransaction(BaseModel):
    request_id: str
    domain: DomainName
    event_time: datetime
    transaction: TransactionInput
    payload: dict[str, Any] = Field(default_factory=dict)
    context: ContextInput | None = None

