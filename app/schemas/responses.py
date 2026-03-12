from __future__ import annotations

from typing import Any

from pydantic import BaseModel, ConfigDict, Field, model_validator

from app.schemas.common import (
    AlertPriority,
    AlertStatus,
    ApiStatus,
    DomainName,
    FEATURE_KEYS_BY_DOMAIN,
    InputSnapshot,
    ModelMode,
    RiskDecision,
    RiskLevel,
    Severity,
    TransactionSummary,
)


class RiskResponse(BaseModel):
    score: float = Field(ge=0.0, le=1.0)
    level: RiskLevel
    decision: RiskDecision
    confidence: float = Field(ge=0.0, le=1.0)


class ScoreBreakdown(BaseModel):
    heuristic: float = Field(ge=0.0, le=1.0)
    supervised: float | None = Field(default=None, ge=0.0, le=1.0)
    anomaly: float | None = Field(default=None, ge=0.0, le=1.0)
    fusion_version: str


class SignalResponse(BaseModel):
    code: str
    severity: Severity
    value: float | int
    threshold: float | int
    message: str


class FeatureContribution(BaseModel):
    feature: str
    value: float | int
    impact: float


class ExplanationResponse(BaseModel):
    top_reasons: list[str]
    feature_contributions: list[FeatureContribution]


class AlertResponse(BaseModel):
    alert_id: str
    type: str
    priority: AlertPriority
    status: AlertStatus
    recommended_action: str


class ModelResponse(BaseModel):
    artifact_version: str | None
    mode: ModelMode
    engine_version: str


class ScoreResponse(BaseModel):
    model_config = ConfigDict(extra="forbid")

    request_id: str
    status: ApiStatus
    domain: DomainName
    transaction_id: str
    input_snapshot: InputSnapshot
    risk: RiskResponse
    scores: ScoreBreakdown
    signals: list[SignalResponse]
    explanations: ExplanationResponse
    features: dict[str, float | int | None]
    alerts: list[AlertResponse]
    transaction_summary: TransactionSummary
    model: ModelResponse
    latency_ms: int

    @model_validator(mode="after")
    def validate_features(self) -> "ScoreResponse":
        expected = set(FEATURE_KEYS_BY_DOMAIN[self.domain.value])
        actual = set(self.features.keys())
        if actual != expected:
            raise ValueError(
                f"feature keys for domain {self.domain.value} do not match contract; "
                f"expected {sorted(expected)}, got {sorted(actual)}"
            )
        return self


class BatchScoreResponse(BaseModel):
    domain: DomainName
    results: list[ScoreResponse]


class AlertsListItem(BaseModel):
    alert_id: str
    type: str
    priority: AlertPriority
    status: AlertStatus
    recommended_action: str
    domain: DomainName
    transaction_id: str
    risk_score: float = Field(ge=0.0, le=1.0)


class AlertsListResponse(BaseModel):
    items: list[AlertsListItem]


class DomainHealth(BaseModel):
    mode: ModelMode
    artifact_version: str | None


class HealthResponse(BaseModel):
    status: ApiStatus
    engine_version: str
    domains: dict[str, DomainHealth]


class AdminModelStatusResponse(BaseModel):
    items: dict[str, dict[str, Any]]
