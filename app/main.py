from fastapi import FastAPI

from app.api import build_api_router
from app.config import load_config


def create_app() -> FastAPI:
    config = load_config()
    app = FastAPI(title="Layer Fraud Detection MVP", version="0.1.0")
    app.include_router(build_api_router(), prefix=config.api.prefix)
    return app


app = create_app()

