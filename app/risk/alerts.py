from __future__ import annotations

import uuid

from app.schemas.responses import AlertResponse, AlertsListItem


class InMemoryAlertStore:
    def __init__(self) -> None:
        self._items: list[AlertsListItem] = []

    def list_items(self) -> list[AlertsListItem]:
        return list(self._items)

    def append(self, item: AlertsListItem) -> None:
        self._items.append(item)

    def clear(self) -> None:
        self._items.clear()


def _make_alert_id() -> str:
    return f"alrt_{uuid.uuid4().hex[:4]}"


def generate_alert(
    score: float,
    level: str,
    decision: str,
    domain: str,
    transaction_id: str,
) -> AlertsListItem | None:
    if decision == "allow":
        return None

    if decision == "block":
        priority = "high"
        recommended_action = "block_and_review"
    elif level == "high":
        priority = "high"
        recommended_action = "step_up_verification"
    else:
        priority = "medium"
        recommended_action = "manual_review"

    return AlertsListItem(
        alert_id=_make_alert_id(),
        type="suspicious_transaction",
        priority=priority,
        status="open",
        recommended_action=recommended_action,
        domain=domain,
        transaction_id=transaction_id,
        risk_score=score,
    )


def alert_list_item_to_response(item: AlertsListItem) -> AlertResponse:
    return AlertResponse(
        alert_id=item.alert_id,
        type=item.type,
        priority=item.priority,
        status=item.status,
        recommended_action=item.recommended_action,
    )
