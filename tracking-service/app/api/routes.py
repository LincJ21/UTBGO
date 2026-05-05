from fastapi import APIRouter, Depends, status
from sqlalchemy.orm import Session
from sqlalchemy import text
from app.api import schemas
from app.database.connection import get_db
from app.core.security import verify_api_key

router = APIRouter(dependencies=[Depends(verify_api_key)])

@router.post("/events", status_code=status.HTTP_202_ACCEPTED, response_model=schemas.TrackingEventResponse)
async def track_event(
    event: schemas.TrackingEventCreate
):
    """
    Ingests a tracking event asynchronously.
    Returns 202 immediately, DB writing happens via Redis Queue + Worker.
    """
    from app.services.tracking_service import publish_event_to_queue
    publish_event_to_queue(event)
    return {"status": "accepted", "message": "Event queued for processing"}


@router.post("/watch-time", status_code=status.HTTP_202_ACCEPTED, response_model=schemas.WatchTimeResponse)
async def track_watch_time(
    data: schemas.WatchTimeCreate,
):
    """
    Records how many seconds a user watched a piece of content.
    Queues a synthetic 'view' event via Redis so the worker handles DB persistence
    with its own DB session (avoids using request-scoped session in background tasks).
    """
    from app.services.tracking_service import publish_event_to_queue

    # Create a synthetic tracking event from the watch time data
    synthetic_event = schemas.TrackingEventCreate(
        user_id=data.user_id,
        content_id=data.content_id,
        event_type="view",
        event_value=data.watched_seconds,
        metadata={"source": "watch_time"},
    )
    publish_event_to_queue(synthetic_event)
    return {"status": "accepted", "message": "Watch time queued for processing"}


@router.get("/health")
async def health_check(db: Session = Depends(get_db)):
    """Deep health check validating DB connection"""
    is_db_up = False
    try:
        db.execute(text("SELECT 1"))
        is_db_up = True
    except Exception:
        pass

    if is_db_up:
        return {"status": "healthy", "database": "connected"}

    from fastapi import HTTPException
    raise HTTPException(status_code=503, detail="Service Unavailable: Database offline")


@router.get("/internal/analytics/overview")
async def get_analytics_overview(db: Session = Depends(get_db)):
    """
    Returns high-level content analytics (Top 10 videos by engagement and views).
    Protected by API Key dependency on the router.
    """
    try:
        # Top 10 by total views
        top_views_q = text("SELECT content_id, total_views FROM content_metrics ORDER BY total_views DESC LIMIT 10")
        top_views = db.execute(top_views_q).fetchall()
        
        # Top 10 by engagement rate
        top_eng_q = text("SELECT content_id, engagement_rate FROM content_metrics WHERE total_views > 10 ORDER BY engagement_rate DESC LIMIT 10")
        top_eng = db.execute(top_eng_q).fetchall()
        
        return {
            "status": "success",
            "data": {
                "top_by_views": [{"content_id": r[0], "views": r[1]} for r in top_views],
                "top_by_engagement": [{"content_id": r[0], "engagement_rate": r[1]} for r in top_eng]
            }
        }
    except Exception as e:
        import logging
        logger = logging.getLogger(__name__)
        logger.error(f"Error fetching analytics: {e}")
        from fastapi import HTTPException
        raise HTTPException(status_code=500, detail="Internal Server Error fetching analytics")
