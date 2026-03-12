"""Classification metrics, threshold suggestion, and report printing."""
from __future__ import annotations

from typing import Any

import numpy as np
from sklearn.metrics import (
    average_precision_score,
    confusion_matrix,
    f1_score,
    precision_recall_curve,
    precision_score,
    recall_score,
)


def compute_classification_metrics(
    y_true: np.ndarray,
    y_pred_proba: np.ndarray,
    threshold: float = 0.5,
) -> dict[str, Any]:
    """Compute precision, recall, F1, PR-AUC, and confusion matrix."""
    y_true = np.asarray(y_true)
    y_pred_proba = np.asarray(y_pred_proba)
    y_pred = (y_pred_proba >= threshold).astype(int)

    pr_auc = float(average_precision_score(y_true, y_pred_proba))
    prec = float(precision_score(y_true, y_pred, zero_division=0))
    rec = float(recall_score(y_true, y_pred, zero_division=0))
    f1 = float(f1_score(y_true, y_pred, zero_division=0))
    cm = confusion_matrix(y_true, y_pred).tolist()

    return {
        "threshold": threshold,
        "precision": round(prec, 4),
        "recall": round(rec, 4),
        "f1": round(f1, 4),
        "pr_auc": round(pr_auc, 4),
        "confusion_matrix": cm,
    }


def suggest_thresholds(
    y_true: np.ndarray,
    y_pred_proba: np.ndarray,
) -> dict[str, dict[str, float]]:
    """Suggest level and decision thresholds.

    Returns two threshold sets:
      - level: low_to_medium, medium_to_high (for risk level mapping)
      - decision: allow_to_review, review_to_block (for action mapping)

    Strategy:
      - allow_to_review: precision ≈ 0.3 (catch most fraud, accept some FP)
      - review_to_block: precision ≈ 0.8 (high confidence required for blocking)
      - level thresholds mirror defaults (0.4 / 0.75) unless data suggests otherwise
    """
    y_true = np.asarray(y_true)
    y_pred_proba = np.asarray(y_pred_proba)

    precision_vals, recall_vals, pr_thresholds = precision_recall_curve(
        y_true, y_pred_proba
    )

    # Find threshold closest to target precision values
    def _find_threshold_for_precision(target_prec: float) -> float:
        # precision_recall_curve returns precision in decreasing recall order
        # Find where precision first exceeds target
        for i, p in enumerate(precision_vals[:-1]):
            if p >= target_prec and i < len(pr_thresholds):
                return float(pr_thresholds[i])
        # Fallback to median threshold
        return float(np.median(pr_thresholds)) if len(pr_thresholds) > 0 else 0.5

    allow_to_review = _find_threshold_for_precision(0.3)
    review_to_block = _find_threshold_for_precision(0.8)

    # Clamp to reasonable range
    allow_to_review = float(np.clip(allow_to_review, 0.2, 0.6))
    review_to_block = float(np.clip(review_to_block, 0.7, 0.95))

    return {
        "level": {
            "low_to_medium": round(allow_to_review, 3),
            "medium_to_high": round(review_to_block - 0.15, 3),
        },
        "decision": {
            "allow_to_review": round(allow_to_review, 3),
            "review_to_block": round(review_to_block, 3),
        },
    }


def print_metrics_report(metrics: dict[str, Any]) -> None:
    """Print a formatted classification report for Kaggle notebooks."""
    print("=" * 50)
    print("  Classification Report")
    print("=" * 50)
    print(f"  Threshold:  {metrics.get('threshold', 'N/A')}")
    print(f"  Precision:  {metrics.get('precision', 'N/A')}")
    print(f"  Recall:     {metrics.get('recall', 'N/A')}")
    print(f"  F1 Score:   {metrics.get('f1', 'N/A')}")
    print(f"  PR-AUC:     {metrics.get('pr_auc', 'N/A')}")
    cm = metrics.get("confusion_matrix")
    if cm and len(cm) == 2:
        print(f"\n  Confusion Matrix:")
        print(f"    TN={cm[0][0]:>6}  FP={cm[0][1]:>6}")
        print(f"    FN={cm[1][0]:>6}  TP={cm[1][1]:>6}")
    print("=" * 50)
