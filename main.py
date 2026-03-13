# main.py
# Run with: uvicorn main:app --reload --port 8000
#
# pip install fastapi uvicorn httpx python-dotenv

import asyncio
import os
import httpx
from fastapi import FastAPI, HTTPException
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