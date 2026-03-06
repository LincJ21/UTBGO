import redis
import json
import logging
from sqlalchemy.orm import Session
from app.repositories.content_repo import ContentRepository
from app.repositories.tracking_repo import TrackingRepository

logger = logging.getLogger(__name__)


class CandidateGenerationService:
    def __init__(self, cache: redis.Redis, db: Session = None):
        self.cache = cache
        self.db = db

    def get_candidates(self, user_id: int, limit: int = 50) -> list[int]:
        """
        Phase 1: Fast Retrieval.
        1. Try precomputed candidates from Redis (fastest path).
        2. Fallback to DB query: top engaged content excluding already-seen items.
        """
        # --- Strategy 1: Redis precomputed candidates ---
        try:
            cache_key = f"user:{user_id}:candidates"
            candidates_json = self.cache.get(cache_key)
            if candidates_json:
                candidates = json.loads(candidates_json)
                if candidates:
                    logger.info(f"Candidates from Redis cache for user {user_id}: {len(candidates)} items")
                    return candidates[:limit]
        except Exception as e:
            logger.warning(f"Redis cache miss for candidates: {e}")

        # --- Strategy 2: DB fallback — top engaged content minus already seen ---
        if self.db:
            try:
                tracking_repo = TrackingRepository(self.db)
                content_repo = ContentRepository(self.db)

                # Get content the user has already interacted with
                seen_ids = tracking_repo.get_interacted_content_ids(user_id)

                # Get top content by engagement, excluding seen
                top_content = content_repo.get_top_content_by_engagement(
                    limit=limit, exclude_ids=seen_ids if seen_ids else None
                )

                candidate_ids = [item["content_id"] for item in top_content]

                if candidate_ids:
                    logger.info(f"Candidates from DB for user {user_id}: {len(candidate_ids)} items")
                    return candidate_ids

            except Exception as e:
                logger.error(f"DB candidate generation failed: {e}")

        return []  # Empty triggers cold start logic in the pipeline

    def get_popular_items(self, limit: int = 10) -> list[int]:
        """Fallback heuristics for Cold Start — uses Redis or DB."""
        # Try Redis first
        try:
            popular = self.cache.get("global:popular_items")
            if popular:
                return json.loads(popular)[:limit]
        except Exception:
            pass

        # DB fallback
        if self.db:
            try:
                content_repo = ContentRepository(self.db)
                top_content = content_repo.get_top_content_by_engagement(limit=limit)
                return [item["content_id"] for item in top_content]
            except Exception as e:
                logger.error(f"DB popular items fallback failed: {e}")

        return []
