from __future__ import annotations

import time
from abc import ABC, abstractmethod

from app import __version__
from app.config import load_config
from app.domains.ieee_cis.explanations import IEEE_CIS_SIGNALS
from app.domains.ieee_cis.features_online import (
    compute_ieee_features,
    update_ieee_state,
)
from app.domains.paysim.explanations import PAYSIM_SIGNALS
from app.domains.paysim.features_online import (
    compute_paysim_features,
    update_paysim_state,
)
from app.risk.alerts import InMemoryAlertStore, alert_list_item_to_response, generate_alert
from app.risk.artifact_loader import load_artifact_registry
from app.risk.explainability import build_explanations, evaluate_signals
from app.risk.heuristic_scoring import (
    IEEE_CIS_WEIGHTS,
    PAYSIM_WEIGHTS,
    compute_heuristic_score,
    risk_decision,
    risk_level,
)
from app.schemas.common import ApiStatus, DomainName, ModelMode
from app.schemas.requests import (
    BatchScoreRequest,
    IeeeCisScorePayload,
    PaySimScorePayload,
    ScoreRequest,
)
from app.schemas.responses import (
    AlertsListItem,
    BatchScoreResponse,
    ModelResponse,
    RiskResponse,
    ScoreBreakdown,
    ScoreResponse,
)
from app.state.in_memory import InMemoryStateStore


class RiskEngine(ABC):
    @abstractmethod
    def score(self, request: ScoreRequest) -> ScoreResponse:
        raise NotImplementedError

    @abstractmethod
    def score_batch(self, request: BatchScoreRequest) -> BatchScoreResponse:
        raise NotImplementedError


class HeuristicRiskEngine(RiskEngine):
    def __init__(self) -> None:
        self._config = load_config()
        self._artifacts = load_artifact_registry()
        self._alert_store = InMemoryAlertStore()
        self._paysim_state = InMemoryStateStore()
        self._ieee_state = InMemoryStateStore()

    def score(self, request: ScoreRequest) -> ScoreResponse:
        start = time.perf_counter()

        domain = request.domain
        payload = request.payload

        # 1. Compute features
        if domain == DomainName.PAYSIM:
            assert isinstance(payload, PaySimScorePayload)
            features = compute_paysim_features(
                step=payload.step,
                txn_type=payload.type,
                amount=request.transaction.amount,
                name_orig=payload.nameOrig,
                name_dest=payload.nameDest,
                old_balance_org=payload.oldbalanceOrg,
                new_balance_orig=payload.newbalanceOrig,
                store=self._paysim_state,
            )
            signal_defs = PAYSIM_SIGNALS
            weights = PAYSIM_WEIGHTS
        else:
            assert isinstance(payload, IeeeCisScorePayload)
            features = compute_ieee_features(
                transaction_dt=payload.TransactionDT,
                transaction_amt=payload.TransactionAmt,
                card1=payload.card1,
                card2=payload.card2,
                card3=payload.card3,
                card5=payload.card5,
                addr1=payload.addr1,
                addr2=payload.addr2,
                p_emaildomain=payload.P_emaildomain,
                r_emaildomain=payload.R_emaildomain,
                device_type=payload.DeviceType,
                device_info=payload.DeviceInfo,
                id_30=payload.id_30,
                id_31=payload.id_31,
                id_33=payload.id_33,
                store=self._ieee_state,
            )
            signal_defs = IEEE_CIS_SIGNALS
            weights = IEEE_CIS_WEIGHTS

        # 2. Heuristic scoring
        heuristic_score, normalized = compute_heuristic_score(features, domain.value)
        level = risk_level(heuristic_score)
        decision = risk_decision(heuristic_score)

        # 3. Signals
        signals = evaluate_signals(features, signal_defs)

        # 4. Explanations
        explanations = build_explanations(features, normalized, weights, signals)

        # 5. Alerts
        alert_item = generate_alert(
            score=heuristic_score,
            level=level,
            decision=decision,
            domain=domain.value,
            transaction_id=request.transaction.transaction_id,
        )
        alert_responses = []
        if alert_item is not None:
            self._alert_store.append(alert_item)
            alert_responses.append(alert_list_item_to_response(alert_item))

        # 6. Update state AFTER scoring
        if domain == DomainName.PAYSIM:
            assert isinstance(payload, PaySimScorePayload)
            update_paysim_state(
                store=self._paysim_state,
                name_orig=payload.nameOrig,
                name_dest=payload.nameDest,
                step=payload.step,
                amount=request.transaction.amount,
            )
        else:
            assert isinstance(payload, IeeeCisScorePayload)
            update_ieee_state(
                store=self._ieee_state,
                card1=payload.card1,
                card2=payload.card2,
                card3=payload.card3,
                card5=payload.card5,
                addr1=payload.addr1,
                addr2=payload.addr2,
                transaction_dt=payload.TransactionDT,
                transaction_amt=payload.TransactionAmt,
                device_type=payload.DeviceType,
                device_info=payload.DeviceInfo,
            )

        # 7. Build response
        artifact = self._artifacts.items[domain.value]
        elapsed_ms = int((time.perf_counter() - start) * 1000)

        return ScoreResponse(
            request_id=request.request_id,
            status=ApiStatus.OK,
            domain=domain,
            transaction_id=request.transaction.transaction_id,
            input_snapshot={
                "transaction": request.transaction,
                "payload": request.payload.model_dump(mode="python"),
            },
            risk=RiskResponse(
                score=round(heuristic_score, 4),
                level=level,
                decision=decision,
                confidence=1.0,
            ),
            scores=ScoreBreakdown(
                heuristic=round(heuristic_score, 4),
                supervised=None,
                anomaly=None,
                fusion_version=self._config.defaults.fusion_version,
            ),
            signals=signals,
            explanations=explanations,
            features=features,
            alerts=alert_responses,
            transaction_summary=self._build_summary(request),
            model=ModelResponse(
                artifact_version=artifact.artifact_version or self._config.defaults.artifact_version,
                mode=artifact.mode if artifact.artifact_version else ModelMode.HEURISTIC_ONLY,
                engine_version=__version__,
            ),
            latency_ms=elapsed_ms,
        )

    def _build_summary(self, request: ScoreRequest) -> dict:
        return {
            "amount": request.transaction.amount,
            "currency": request.transaction.currency,
            "channel": request.transaction.channel,
            "product_code": request.transaction.product_code,
            "card_network": request.transaction.card_network,
            "funding_type": request.transaction.funding_type,
        }

    def score_batch(self, request: BatchScoreRequest) -> BatchScoreResponse:
        results = [self.score(item) for item in request.to_score_requests()]
        return BatchScoreResponse(domain=request.domain, results=results)

    def list_alerts(self) -> list[AlertsListItem]:
        return self._alert_store.list_items()
