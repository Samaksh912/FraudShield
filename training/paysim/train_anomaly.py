"""PaySim anomaly training — lightweight Isolation Forest.

Gated: only runs when explicitly requested. Never blocks supervised training.
"""
from __future__ import annotations

from typing import Any

import numpy as np


def train_paysim_anomaly(X_train: np.ndarray, **kwargs: Any) -> Any:
    """Train an Isolation Forest on PaySim features.

    Args:
        X_train: Feature matrix (n_samples, n_features).

    Returns:
        Fitted IsolationForest model.

    Raises:
        ImportError: If sklearn is not available.
    """
    from sklearn.ensemble import IsolationForest

    contamination = kwargs.get("contamination", "auto")
    n_estimators = kwargs.get("n_estimators", 100)
    random_state = kwargs.get("random_state", 42)

    print(f"[PaySim-Anomaly] Training IsolationForest (n_estimators={n_estimators})")
    model = IsolationForest(
        n_estimators=n_estimators,
        contamination=contamination,
        random_state=random_state,
        n_jobs=-1,
    )
    model.fit(X_train)
    print("[PaySim-Anomaly] Training complete")
    return model
