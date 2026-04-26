import logging

from fastapi import FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from prometheus_fastapi_instrumentator import Instrumentator
from sqlalchemy.exc import SQLAlchemyError

from app.api import routes
from app.core.config import settings
from app.core.logging import setup_logging
from app.core.scheduler import start_scheduler, shutdown_scheduler

setup_logging()
logger = logging.getLogger(__name__)

app = FastAPI(
    title=settings.PROJECT_NAME,
    version=settings.VERSION,
    openapi_url=f"{settings.API_V1_STR}/openapi.json",
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.CORS_ORIGINS,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Prometheus Metrics — hidden from public OpenAPI schema
Instrumentator().instrument(app).expose(
    app,
    endpoint="/api/v1/internal/metrics",
    include_in_schema=False,
)


@app.exception_handler(Exception)
async def global_exception_handler(request: Request, exc: Exception):
    logger.error("Unhandled exception: %s", exc, exc_info=True)
    return JSONResponse(
        status_code=500,
        content={"type": "about:blank", "title": "Internal Server Error", "status": 500},
    )


@app.exception_handler(SQLAlchemyError)
async def database_exception_handler(request: Request, exc: SQLAlchemyError):
    logger.error("DB error: %s", exc)
    return JSONResponse(
        status_code=503,
        content={"type": "about:blank", "title": "Database Unavailable", "status": 503},
    )


@app.on_event("startup")
async def startup_event():
    logger.info("Application startup: Triggering APScheduler setup")
    start_scheduler()


@app.on_event("shutdown")
async def shutdown_event():
    logger.info("Application shutdown: Stopping APScheduler")
    shutdown_scheduler()


app.include_router(routes.router, prefix=settings.API_V1_STR)

