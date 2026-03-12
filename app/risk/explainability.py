from __future__ import annotations

from app.domains.paysim.explanations import SignalDefinition
from app.schemas.responses import (
    ExplanationResponse,
    FeatureContribution,
    SignalResponse,
)

SEVERITY_ORDER = {"high": 0, "medium": 1, "low": 2}


def evaluate_signals(
    features: dict[str, float | int | None],
    signal_definitions: list[SignalDefinition],
) -> list[SignalResponse]:
    triggered: list[SignalResponse] = []
    for defn in signal_definitions:
        value = features.get(defn.feature)
        if value is None:
            continue
        fired = False
        if defn.direction == "above":
            fired = value > defn.threshold
        elif defn.direction == "below":
            fired = value < defn.threshold
        elif defn.direction == "above_abs":
            fired = abs(value) > defn.threshold
        if fired:
            triggered.append(
                SignalResponse(
                    code=defn.code,
                    severity=defn.severity,
                    value=value,
                    threshold=defn.threshold,
                    message=defn.message,
                )
            )
    triggered.sort(key=lambda s: SEVERITY_ORDER.get(s.severity, 99))
    return triggered


def build_explanations(
    raw_features: dict[str, float | int | None],
    normalized_features: dict[str, float],
    weights: dict[str, float],
    signals: list[SignalResponse],
) -> ExplanationResponse:
    if signals:
        top_reasons = [s.message for s in signals[:5]]
    else:
        top_reasons = ["Transaction appears normal based on available data."]

    contributions: list[FeatureContribution] = []
    for feature, norm_val in normalized_features.items():
        impact = round(norm_val * weights.get(feature, 0.0), 4)
        if abs(impact) < 1e-9:
            continue
        raw_val = raw_features.get(feature, 0)
        contributions.append(
            FeatureContribution(
                feature=feature,
                value=raw_val if raw_val is not None else 0,
                impact=impact,
            )
        )
    contributions.sort(key=lambda c: abs(c.impact), reverse=True)
    return ExplanationResponse(top_reasons=top_reasons, feature_contributions=contributions)
