"""
precompute_candidates.py — ETL Batch Pipeline

This script should be run periodically (e.g., every 15-30 minutes via cron/scheduler)
to precompute recommendation candidates for all active users and store them in Redis.

Usage:
    python precompute_candidates.py

Environment:
    Requires DATABASE_URL, REDIS_HOST, REDIS_PORT to be set in .env
"""

import json
import logging
import time
from app.database.connection import SessionLocal
from app.cache.redis_client import get_redis
from app.repositories.tracking_repo import TrackingRepository
from app.repositories.content_repo import ContentRepository
from sqlalchemy import text

# Setup logging
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s - %(name)s - %(levelname)s - %(message)s",
)
logger = logging.getLogger("PrecomputeCandidates")

# TTL for cached candidates (seconds)
CANDIDATES_TTL = 1800  # 30 minutes
POPULAR_TTL = 900  # 15 minutes
MAX_CANDIDATES_PER_USER = 50


def precompute_popular_items(db, redis_conn):
    """Compute global popular items and store in Redis."""
    content_repo = ContentRepository(db)
    top_items = content_repo.get_top_content_by_engagement(limit=100)
    popular_ids = [item["content_id"] for item in top_items]

    if popular_ids:
        redis_conn.setex(
            "global:popular_items",
            POPULAR_TTL,
            json.dumps(popular_ids),
        )
        logger.info(f"✔ Stored {len(popular_ids)} popular items in Redis")
    else:
        logger.warning("No popular items found in content_metrics")


def precompute_user_candidates(db, redis_conn):
    """For each active user, compute personalized candidates and cache in Redis."""
    # Get active users (users who have events in the last 7 days)
    result = db.execute(text("""
        SELECT DISTINCT user_id
        FROM tracking_events
        WHERE created_at > NOW() - INTERVAL '7 days'
    """))
    active_user_ids = [row[0] for row in result]

    logger.info(f"Found {len(active_user_ids)} active users to precompute candidates for")

    tracking_repo = TrackingRepository(db)
    content_repo = ContentRepository(db)

    computed = 0
    for user_id in active_user_ids:
        try:
            # Get content the user has already seen
            seen_ids = tracking_repo.get_interacted_content_ids(user_id)

            # Get top engaged content excluding already seen
            top_content = content_repo.get_top_content_by_engagement(
                limit=MAX_CANDIDATES_PER_USER,
                exclude_ids=seen_ids if seen_ids else None,
            )

            candidate_ids = [item["content_id"] for item in top_content]

            if candidate_ids:
                cache_key = f"user:{user_id}:candidates"
                redis_conn.setex(
                    cache_key,
                    CANDIDATES_TTL,
                    json.dumps(candidate_ids),
                )
                computed += 1

        except Exception as e:
            logger.error(f"Failed to compute candidates for user {user_id}: {e}")

    logger.info(f"✔ Precomputed candidates for {computed}/{len(active_user_ids)} users")


def run():
    """Main entry point for the ETL pipeline."""
    start = time.time()
    logger.info("=" * 60)
    logger.info("Starting candidate precomputation pipeline...")

    db = SessionLocal()
    redis_conn = get_redis()

    try:
        # Step 1: Global popular items
        precompute_popular_items(db, redis_conn)

        # Step 2: Per-user candidates
        precompute_user_candidates(db, redis_conn)

    except Exception as e:
        logger.error(f"Pipeline failed: {e}")
    finally:
        db.close()

    elapsed = time.time() - start
    logger.info(f"Pipeline completed in {elapsed:.2f}s")
    logger.info("=" * 60)


if __name__ == "__main__":
    run()
