"""
Tracking Worker — Consumes events from Redis queue and persists to Postgres.

Features:
  - Graceful shutdown on SIGTERM/SIGINT
  - Dead-letter queue (DLQ) for failed events
  - Content metrics aggregation on each event
  - Exponential backoff on errors
"""

import json
import logging
import signal
import sys
import time

from app.api.schemas import TrackingEventCreate
from app.cache.redis_client import get_redis
from app.core.config import settings
from app.database.connection import SessionLocal
from app.repositories.tracking_repo import TrackingRepository
from app.services.metrics_service import update_content_metrics

# Setup logging
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s - %(name)s - %(levelname)s - %(message)s",
)
logger = logging.getLogger("TrackingWorker")

# Dead-letter queue name
DLQ_NAME = f"{settings.REDIS_QUEUE_NAME}:dlq"

# Graceful shutdown flag
_shutdown = False


def _handle_signal(signum, frame):
    """Sets the shutdown flag so the main loop exits cleanly."""
    global _shutdown
    logger.info("Received shutdown signal (%s). Finishing current event...", signum)
    _shutdown = True


# Register signal handlers
signal.signal(signal.SIGTERM, _handle_signal)
signal.signal(signal.SIGINT, _handle_signal)


def _process_event(redis_conn, event_data: bytes):
    """Processes a single event: parse → save to DB → update metrics."""
    data = json.loads(event_data)
    event = TrackingEventCreate(**data)

    db = SessionLocal()
    try:
        repo = TrackingRepository(db)
        repo.save_event(event)
        update_content_metrics(db, event.content_id, event.event_type)
        db.commit()
        logger.info("Saved event: user=%d, type=%s, content=%d", event.user_id, event.event_type, event.content_id)
    except Exception as e:
        db.rollback()
        logger.error("DB error processing event: %s", e)
        # Send to DLQ so the failed event is not lost
        try:
            redis_conn.lpush(DLQ_NAME, event_data)
            logger.warning("Event moved to DLQ: %s", DLQ_NAME)
        except Exception:
            logger.critical("Failed to send event to DLQ — event LOST: %s", event_data[:200])
    finally:
        db.close()


def run_worker():
    """Main worker loop with graceful shutdown and exponential backoff."""
    logger.info("Worker started — Redis: %s:%d, Queue: %s", settings.REDIS_HOST, settings.REDIS_PORT, settings.REDIS_QUEUE_NAME)

    redis_conn = get_redis()
    backoff = 1  # seconds

    while not _shutdown:
        try:
            # BLPOP: blocking pop with timeout (allows checking _shutdown flag)
            result = redis_conn.blpop(settings.REDIS_QUEUE_NAME, timeout=5)

            if result:
                _, event_data = result
                _process_event(redis_conn, event_data)
                backoff = 1  # reset backoff on success

        except KeyboardInterrupt:
            break
        except Exception as e:
            logger.error("Worker iteration failed: %s — retrying in %ds", e, backoff)
            time.sleep(backoff)
            backoff = min(backoff * 2, 30)  # exponential backoff, max 30s

    logger.info("Worker shut down gracefully.")


if __name__ == "__main__":
    run_worker()
