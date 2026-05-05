"""
Tracking Service — Event processing layer.

Architecture:
  1. Primary path: Publish event to Redis queue → Worker consumes and saves to Postgres.
  2. Fallback path: If Redis is down, save directly to Postgres synchronously.
"""

import json
import logging

from app.api.schemas import TrackingEventCreate
from app.cache.redis_client import get_redis
from app.core.config import settings
from app.database.connection import SessionLocal
from app.repositories.tracking_repo import TrackingRepository
from app.services.metrics_service import update_content_metrics

logger = logging.getLogger(__name__)

redis_client = get_redis()


def publish_event_to_queue(event: TrackingEventCreate):
    """
    Publishes an event to the Redis queue for asynchronous processing.
    Falls back to synchronous DB save if Redis is unavailable.
    """
    try:
        event_json = event.model_dump_json() if hasattr(event, "model_dump_json") else json.dumps(event.dict())
        redis_client.lpush(settings.REDIS_QUEUE_NAME, event_json)
        logger.info("Queued event to Redis: user=%d, type=%s", event.user_id, event.event_type)
    except Exception as e:
        logger.error("Failed to queue event to Redis: %s. Falling back to sync DB save.", e)
        _save_event_sync(event)


def _save_event_sync(event: TrackingEventCreate):
    """
    Fallback: saves directly to Postgres when Redis is unavailable.
    Ensures no events are ever silently dropped.
    """
    db = SessionLocal()
    try:
        repo = TrackingRepository(db)
        repo.save_event(event)
        update_content_metrics(db, event.content_id, event.event_type)
        db.commit()
        logger.info("Sync-saved event (Redis fallback): user=%d, type=%s", event.user_id, event.event_type)
    except Exception as e:
        db.rollback()
        logger.error("Sync save also failed (event LOST): %s", e)
    finally:
        db.close()
