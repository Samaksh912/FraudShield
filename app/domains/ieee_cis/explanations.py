from __future__ import annotations

from app.domains.paysim.explanations import SignalDefinition


IEEE_CIS_SIGNALS: list[SignalDefinition] = [
    SignalDefinition(
        code="LOW_UID_HISTORY",
        feature="uid_prior_frequency",
        threshold=2,
        direction="below",
        severity="medium",
        message="Card identity has very few prior transactions.",
    ),
    SignalDefinition(
        code="HIGH_AMOUNT_VS_MEDIAN",
        feature="amt_to_uid_median_ratio",
        threshold=3.0,
        direction="above",
        severity="high",
        message="Transaction amount is unusually high for this card identity.",
    ),
    SignalDefinition(
        code="HIGH_UID_VELOCITY",
        feature="uid_txn_count_24h",
        threshold=4,
        direction="above",
        severity="medium",
        message="Entity has elevated card activity in the last 24 hours.",
    ),
    SignalDefinition(
        code="EMAIL_DOMAIN_MISMATCH",
        feature="email_domain_mismatch",
        threshold=0.5,
        direction="above",
        severity="medium",
        message="Purchaser and recipient email domains do not match.",
    ),
    SignalDefinition(
        code="NEW_DEVICE_FOR_UID",
        feature="new_device_for_uid",
        threshold=0.5,
        direction="above",
        severity="high",
        message="Transaction originates from a new device signature for this entity.",
    ),
    SignalDefinition(
        code="NO_IDENTITY_DATA",
        feature="identity_present",
        threshold=0.5,
        direction="below",
        severity="low",
        message="No identity verification data available.",
    ),
]
