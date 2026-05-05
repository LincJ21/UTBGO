from fastapi import FastAPI, Request
from fastapi.responses import JSONResponse
from fastapi.middleware.cors import CORSMiddleware
from sqlalchemy.exc import SQLAlchemyError
from app.api import routes
from app.core.config import settings
from app.core.logging import setup_logging
import logging
from prometheus_fastapi_instrumentator import Instrumentator

# Setup structured logging
setup_logging()
logger = logging.getLogger(__name__)

app = FastAPI(
    title=settings.PROJECT_NAME,
    version=settings.VERSION,
    openapi_url=f"{settings.API_V1_STR}/openapi.json"
)

# CORS configuration for production
app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.CORS_ORIGINS,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Prometheus Metrics Instrumentation
# Exposed at /api/v1/metrics (protected by API key via router dependency)
Instrumentator().instrument(app).expose(
    app,
    endpoint="/api/v1/internal/metrics",
    include_in_schema=False,
)

# Global Exception Handlers (RFC 7807 style output)
@app.exception_handler(Exception)
async def global_exception_handler(request: Request, exc: Exception):
    logger.error(f"Unhandled exception: {str(exc)}", exc_info=True)
    return JSONResponse(
        status_code=500,
        content={"type": "about:blank", "title": "Internal Server Error", "status": 500, "detail": "An unexpected error occurred."}
    )

@app.exception_handler(SQLAlchemyError)
async def database_exception_handler(request: Request, exc: SQLAlchemyError):
    logger.error(f"Database error: {str(exc)}")
    # Do not leak DB details to client
    return JSONResponse(
        status_code=503,
        content={"type": "about:blank", "title": "Service Unavailable", "status": 503, "detail": "Database connection error."}
    )

# Include routes
app.include_router(routes.router, prefix=settings.API_V1_STR)

@app.get("/")
async def root():
    return {"message": "Tracking Service API is running securely"}
