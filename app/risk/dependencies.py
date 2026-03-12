from __future__ import annotations

from functools import lru_cache

from app.risk.engine import HeuristicRiskEngine


@lru_cache(maxsize=1)
def get_engine() -> HeuristicRiskEngine:
    return HeuristicRiskEngine()
