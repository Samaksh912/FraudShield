# main.py
# Run with: uvicorn main:app --reload --port 8000
#
# pip install fastapi uvicorn httpx python-dotenv

import asyncio
import os
import httpx
from fastapi import FastAPI, HTTPException, Request
from fastapi.middleware.cors import CORSMiddleware
from dotenv import load_dotenv

load_dotenv()

app = FastAPI(title="FraudShield API", version="0.1.0")

# ── CORS — required so Flutter Web can call this ──────────────────────────────
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)

GEMINI_API_KEY = os.getenv("GEMINI_API_KEY")

# Fix: correct model name (gemini-2.0-flash, not gemini-3-flash-preview)
GEMINI_URL = (
    "https://generativelanguage.googleapis.com/v1beta/models"
    "/gemini-2.0-flash:generateContent"
)

# ── Other device's ML backend ─────────────────────────────────────────────────
# Set BACKEND_URL in your .env file, or replace the default IP here directly.
# The other device must run: uvicorn main:app --host 0.0.0.0 --port 8000
BACKEND_URL = os.getenv("BACKEND_URL", "http://192.168.163.103:8000")  # ← set real IP in .env


# ═══════════════════════════════════════════════════════
# GET /v1/alerts
# Fetches live alerts from the ML backend on the other
# device, then enriches each one with a Gemini reason.
# ═══════════════════════════════════════════════════════
@app.get("/v1/alerts")
async def get_alerts():
    # Step 1: pull real alerts from the other device's backend
    try:
        async with httpx.AsyncClient(timeout=15) as client:
            resp = await client.get(f"{BACKEND_URL}/v1/alerts")
            resp.raise_for_status()
            items = resp.json()["items"]
    except Exception as e:
        raise HTTPException(
            status_code=502,
            detail=f"Could not reach ML backend at {BACKEND_URL}: {e}",
        )

    # Step 2: enrich each alert with a Gemini reason (parallel)
    enriched = await asyncio.gather(
        *[_attach_gemini_reason(item) for item in items],
        return_exceptions=False,
    )
    return {"items": enriched}


async def _attach_gemini_reason(alert: dict) -> dict:
    try:
        reason = await _gemini_reason(alert)
    except Exception:
        reason = None  # never crash the endpoint if Gemini fails
    return {**alert, "ai_reason": reason}


async def _gemini_reason(alert: dict) -> str:
    domain_label = (
        "UPI / digital payment (PaySim)"
        if alert["domain"] == "paysim"
        else "card payment (IEEE-CIS)"
    )
    action = alert["recommended_action"].replace("_", " ")
    risk_display = round(alert["risk_score"] * 100, 1)

    prompt = (
        f"You are a concise fraud analyst AI. Write exactly ONE sentence "
        f"(max 18 words) explaining WHY this transaction was flagged as suspicious. "
        f"Be specific. No preamble.\n\n"
        f"domain: {domain_label}\n"
        f"risk_score: {risk_display}/100\n"
        f"priority: {alert['priority']}\n"
        f"recommended_action: {action}\n"
        f"transaction_id: {alert['transaction_id']}"
    )

    async with httpx.AsyncClient(timeout=15) as client:
        resp = await client.post(
            f"{GEMINI_URL}?key={GEMINI_API_KEY}",
            json={
                "contents": [{"parts": [{"text": prompt}]}],
                "generationConfig": {
                    "maxOutputTokens": 64,
                    "temperature": 0.2,
                },
            },
        )
        resp.raise_for_status()
        data = resp.json()
        return data["candidates"][0]["content"]["parts"][0]["text"].strip()


# ═══════════════════════════════════════════════════════
# GET /v1/health
# ═══════════════════════════════════════════════════════
@app.get("/v1/health")
async def health():
    return {
        "status": "ok",
        "engine_version": "0.1.0",
        "domains": {
            "paysim":   {"mode": "model_plus_rules", "artifact_version": "v1"},
            "ieee_cis": {"mode": "heuristic_only",   "artifact_version": None},
        },
    }


# ═══════════════════════════════════════════════════════
# GET /v1/transactions
# Returns recent scored transactions from the ML backend.
# Falls back to local demo data if ML backend unreachable.
# ═══════════════════════════════════════════════════════
DEMO_TRANSACTIONS = [
    {"id": "txn_1001",      "domain": "paysim",   "type": "TRANSFER",   "amount": 125000.0, "currency": "INR", "sender": "C123",        "receiver": "C456",      "timestamp": "2025-03-13T10:03:00Z", "risk_score": 0.864, "level": "high"},
    {"id": "txn_card_2001", "domain": "ieee_cis", "type": "PURCHASE",   "amount": 68.5,     "currency": "USD", "sender": "card1_13926", "receiver": "W",         "timestamp": "2025-03-13T09:59:00Z", "risk_score": 0.931, "level": "high"},
    {"id": "txn_1002",      "domain": "paysim",   "type": "PAYMENT",    "amount": 950.0,    "currency": "INR", "sender": "C777",        "receiver": "M123",      "timestamp": "2025-03-13T09:54:00Z", "risk_score": 0.11,  "level": "low"},
    {"id": "txn_card_2002", "domain": "ieee_cis", "type": "PURCHASE",   "amount": 149.99,   "currency": "USD", "sender": "card1_2755",  "receiver": "W",         "timestamp": "2025-03-13T09:46:00Z", "risk_score": 0.58,  "level": "medium"},
    {"id": "txn_1003",      "domain": "paysim",   "type": "TRANSFER",   "amount": 5800.0,   "currency": "INR", "sender": "C901",        "receiver": "C220",      "timestamp": "2025-03-13T09:38:00Z", "risk_score": 0.09,  "level": "low"},
    {"id": "txn_card_2003", "domain": "ieee_cis", "type": "WITHDRAWAL", "amount": 3420.0,   "currency": "USD", "sender": "card1_1188",  "receiver": "MID_2290",  "timestamp": "2025-03-13T09:31:00Z", "risk_score": 0.47,  "level": "medium"},
    {"id": "txn_1004",      "domain": "paysim",   "type": "CASH_OUT",   "amount": 15000.0,  "currency": "INR", "sender": "C990",        "receiver": "M773",      "timestamp": "2025-03-13T09:24:00Z", "risk_score": 0.78,  "level": "high"},
    {"id": "txn_card_2004", "domain": "ieee_cis", "type": "PURCHASE",   "amount": 220.0,    "currency": "USD", "sender": "card1_3312",  "receiver": "MID_0042",  "timestamp": "2025-03-13T09:16:00Z", "risk_score": 0.07,  "level": "low"},
]

@app.get("/v1/transactions")
async def get_transactions():
    try:
        async with httpx.AsyncClient(timeout=10) as client:
            resp = await client.get(f"{BACKEND_URL}/v1/transactions")
            resp.raise_for_status()
            return resp.json()
    except Exception:
        return {"items": DEMO_TRANSACTIONS}


# ═══════════════════════════════════════════════════════
# GET /v1/dashboard
# Aggregated KPI stats. Tries ML backend first, falls back.
# ═══════════════════════════════════════════════════════
DEMO_DASHBOARD = {
    "total_today": 12847,
    "fraud_detected": 142,
    "fraud_rate": 1.11,
    "avg_risk_score": 23.4,
    "alerts_open": 3,
    "model_accuracy": 97.2,
    "fraud_trend": [
        {"day": "Mon", "transactions": 9400,  "fraud": 98},
        {"day": "Tue", "transactions": 10200, "fraud": 115},
        {"day": "Wed", "transactions": 11800, "fraud": 134},
        {"day": "Thu", "transactions": 10900, "fraud": 121},
        {"day": "Fri", "transactions": 13200, "fraud": 158},
        {"day": "Sat", "transactions": 14800, "fraud": 172},
        {"day": "Sun", "transactions": 12847, "fraud": 142},
    ],
    "domain_split": {
        "UPI (PaySim)": 58.4,
        "Card (IEEE-CIS)": 41.6,
    },
    "risk_distribution": [
        {"label": "Low (0-30)",     "count": 9820, "color": "safe"},
        {"label": "Medium (31-60)", "count": 2105, "color": "suspicious"},
        {"label": "High (61-85)",   "count": 780,  "color": "fraud"},
        {"label": "Critical (86+)", "count": 142,  "color": "fraudDim"},
    ],
}

@app.get("/v1/dashboard")
async def get_dashboard():
    try:
        async with httpx.AsyncClient(timeout=10) as client:
            resp = await client.get(f"{BACKEND_URL}/v1/dashboard")
            resp.raise_for_status()
            return resp.json()
    except Exception:
        return DEMO_DASHBOARD


# ═══════════════════════════════════════════════════════
# POST /v1/score
# Forward scoring request to ML backend.
# Falls back to a demo result if backend unreachable.
# ═══════════════════════════════════════════════════════

def _demo_score(payload: dict) -> dict:
    """Generate a realistic demo score response from the payload."""
    domain   = payload.get("domain", "paysim")
    txn      = payload.get("transaction", {})
    amount   = float(txn.get("amount", txn.get("TransactionAmt", 0)))
    is_high  = amount > 50000 if domain == "paysim" else amount > 100

    risk_score = 0.864 if is_high else 0.11
    level      = "high" if risk_score >= 0.7 else ("medium" if risk_score >= 0.4 else "low")
    decision   = "block" if risk_score >= 0.8 else ("review" if risk_score >= 0.4 else "allow")

    return {
        "request_id":      "demo-fallback-001",
        "transaction_id":  txn.get("nameOrig", txn.get("card1", "txn-demo")),
        "domain":          domain,
        "score":           risk_score,
        "level":           level,
        "decision":        decision,
        "confidence":      0.82,
        "scores": {
            "heuristic":      round(risk_score + 0.02, 3),
            "supervised":     round(risk_score - 0.03, 3) if is_high else None,
            "anomaly":        None,
            "fusion_version": "default_v1",
        },
        "signals": [
            {
                "code":      "HIGH_AMOUNT_TO_BALANCE_RATIO",
                "severity":  "high",
                "value":     0.83,
                "threshold": 0.7,
                "message":   "Transfer amount is unusually large relative to sender balance.",
            }
        ] if is_high else [],
        "top_reasons": [
            "Large transfer relative to available balance",
            "New sender-beneficiary pair",
        ] if is_high else [
            "Transaction amount consistent with sender history",
            "No high-risk pattern detected",
        ],
        "feature_contributions": [
            {"feature": "amount_to_orig_balance_ratio", "value": 0.83, "impact": 0.31},
        ] if is_high else [
            {"feature": "amount_to_orig_balance_ratio", "value": 0.01, "impact": -0.10},
        ],
        "features": {
            "type_risk_flag":               1 if is_high else 0,
            "amount_to_orig_balance_ratio": 0.83 if is_high else 0.01,
            "sender_txn_count_24h":         6 if is_high else 1,
        },
        "alerts": [
            {
                "alert_id":           "alrt_demo_001",
                "type":               "suspicious_transaction",
                "priority":           level,
                "status":             "open",
                "recommended_action": decision.replace("block", "block_and_review")
                                              .replace("review", "manual_review")
                                              .replace("allow", "no_action"),
            }
        ] if is_high else [],
        "transaction_summary": {
            "amount":   amount,
            "currency": "INR" if domain == "paysim" else "USD",
            "channel":  "upi" if domain == "paysim" else "card",
        },
        "model": {
            "artifact_version": "v1",
            "mode":             "model_plus_rules" if is_high else "heuristic_only",
            "engine_version":   "0.1.0",
        },
        "latency_ms": 24,
    }


@app.post("/v1/score")
async def score_transaction(request: Request):
    payload = await request.json()
    try:
        async with httpx.AsyncClient(timeout=30) as client:
            resp = await client.post(
                f"{BACKEND_URL}/v1/score",
                json=payload,
            )
            resp.raise_for_status()
            return resp.json()
    except Exception:
        # ML backend unreachable or returned an error — use demo scoring
        return _demo_score(payload)


@app.get("/v1/score")
async def score_info():
    """Info endpoint so GET /v1/score doesn't return 405."""
    return {
        "endpoint": "POST /v1/score",
        "description": "Submit a transaction payload for fraud scoring.",
        "example_body": {
            "domain": "paysim",
            "transaction": {
                "step": 278, "type": "TRANSFER", "amount": 125000,
                "nameOrig": "C123", "nameDest": "C456",
                "oldbalanceOrg": 150000, "newbalanceOrig": 25000,
            },
        },
    }


# ═══════════════════════════════════════════════════════
# GET /v1/analytics
# Model performance metrics. Tries ML backend, falls back.
# ═══════════════════════════════════════════════════════
DEMO_ANALYTICS = {
    "model_metrics": {
        "PaySim (UPI)":    {"precision": 97.8, "recall": 96.2, "f1": 97.0, "pr_auc": 98.4, "model": "XGBoost"},
        "IEEE-CIS (Card)": {"precision": 95.1, "recall": 93.8, "f1": 94.4, "pr_auc": 97.1, "model": "XGBoost + Anomaly"},
    },
    "feature_importance": {
        "PaySim": [
            {"feature": "amount_to_orig_balance_ratio", "importance": 0.31},
            {"feature": "sender_dest_pair_novelty",     "importance": 0.27},
            {"feature": "sender_txn_count_24h",         "importance": 0.18},
            {"feature": "sender_amount_zscore_7d",      "importance": 0.12},
            {"feature": "orig_balance_consistency_error","importance": 0.07},
            {"feature": "type_risk_flag",               "importance": 0.05},
        ],
        "IEEE-CIS": [
            {"feature": "new_device_for_uid",      "importance": 0.34},
            {"feature": "uid_txn_count_24h",       "importance": 0.24},
            {"feature": "email_domain_mismatch",   "importance": 0.17},
            {"feature": "amt_to_uid_median_ratio", "importance": 0.13},
            {"feature": "uid_prior_frequency",     "importance": 0.07},
            {"feature": "identity_present",        "importance": 0.05},
        ],
    },
}

@app.get("/v1/analytics")
async def get_analytics():
    try:
        async with httpx.AsyncClient(timeout=10) as client:
            resp = await client.get(f"{BACKEND_URL}/v1/analytics")
            resp.raise_for_status()
            return resp.json()
    except Exception:
        return DEMO_ANALYTICS
