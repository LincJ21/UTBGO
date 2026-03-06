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
