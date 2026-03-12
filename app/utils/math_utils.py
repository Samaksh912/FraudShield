from __future__ import annotations

import statistics

EPSILON = 1e-6


def clamped_ratio(numerator: float, denominator: float, cap: float = 1.0) -> float:
    return min(numerator / max(denominator, EPSILON), cap)


def zscore(value: float, history: list[float], min_samples: int = 2) -> float:
    if len(history) < min_samples:
        return 0.0
    mean = statistics.mean(history)
    std = statistics.pstdev(history)
    if std < EPSILON:
        return 0.0
    return (value - mean) / std
