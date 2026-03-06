import logging
import redis

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from sqlalchemy import text

from app.api import schemas
from app.cache.redis_client import get_redis
from app.core.security import verify_api_key
from app.database.connection import get_db
from app.pipelines.inference_pipeline import InferencePipeline

logger = logging.getLogger(__name__)

# Enforce API Key on all routes in this router
router = APIRouter(dependencies=[Depends(verify_api_key)])

@router.post("/recommendations", response_model=schemas.RecommendationResponse)
async def get_recommendations(
    req: schemas.RecommendationRequest,
    db: Session = Depends(get_db),
    cache: redis.Redis = Depends(get_redis)
):
    """
    Generate personalized recommendations asynchronously.
    Executes the Inference Pipeline: Retrieval -> Feature Fetch -> LGBM Ranking.
    """
    pipeline = InferencePipeline(db, cache)
    recs = pipeline.run(req.user_id, limit=req.limit)
    return {"user_id": req.user_id, "recommendations": recs}

@router.get("/health")
async def health_check(
    db: Session = Depends(get_db),
    cache: redis.Redis = Depends(get_redis)
):
    """Deep health check validating DB and Redis"""
    health_status = {"status": "healthy", "database": "unknown", "redis": "unknown"}
    is_fully_healthy = True
    
    try:
        db.execute(text("SELECT 1"))
        health_status["database"] = "connected"
    except Exception:
        health_status["database"] = "offline"
        is_fully_healthy = False
        
    try:
        if cache.ping():
            health_status["redis"] = "connected"
    except Exception:
        health_status["redis"] = "offline"
        is_fully_healthy = False
        
    if not is_fully_healthy:
        raise HTTPException(status_code=503, detail=health_status)
        
    return health_status
