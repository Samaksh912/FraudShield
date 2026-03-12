from __future__ import annotations

from dataclasses import dataclass


@dataclass(frozen=True)
class SignalDefinition:
    code: str
    feature: str
    threshold: float
    direction: str  # "above", "below", "above_abs"
    severity: str  # "low", "medium", "high"
    message: str


PAYSIM_SIGNALS: list[SignalDefinition] = [
    SignalDefinition(
        code="RISKY_TXN_TYPE",
        feature="type_risk_flag",
        threshold=0.5,
        direction="above",
        severity="medium",
        message="Transaction type is associated with higher fraud risk.",
    ),
    SignalDefinition(
        code="HIGH_AMOUNT_TO_BALANCE_RATIO",
        feature="amount_to_orig_balance_ratio",
        threshold=0.7,
        direction="above",
        severity="high",
        message="Transfer amount is unusually large relative to sender balance.",
    ),
    SignalDefinition(
        code="BALANCE_INCONSISTENCY",
        feature="orig_balance_consistency_error",
        threshold=0.01,
        direction="above",
        severity="high",
        message="Sender balance change does not match transaction amount.",
    ),
    SignalDefinition(
        code="HIGH_SENDER_ACTIVITY",
        feature="sender_txn_count_24h",
        threshold=5,
        direction="above",
        severity="medium",
        message="Sender activity is elevated in the last 24 hours.",
    ),
    SignalDefinition(
        code="UNUSUAL_AMOUNT",
        feature="sender_amount_zscore_7d",
        threshold=2.0,
        direction="above_abs",
        severity="medium",
        message="Transaction amount is unusual for this sender.",
    ),
    SignalDefinition(
        code="NEW_BENEFICIARY",
        feature="sender_dest_pair_novelty",
        threshold=0.5,
        direction="above",
        severity="medium",
        message="Sender is transacting with a new beneficiary.",
    ),
]
