from sqlalchemy.orm import Session
from sqlalchemy import text
import logging

logger = logging.getLogger(__name__)


class ContentRepository:
    """Reads content metadata and aggregated metrics from the shared Postgres database."""

    def __init__(self, db: Session):
        self.db = db

    def get_top_content_by_engagement(self, limit: int = 50, exclude_ids: list[int] = None):
        """
        Returns the top content IDs sorted by engagement_rate from content_metrics.
        Optionally excludes content the user has already interacted with.
        """
        if exclude_ids:
            result = self.db.execute(text("""
                SELECT content_id, engagement_rate, total_views, total_likes
                FROM content_metrics
                WHERE content_id != ALL(:exclude_ids)
                ORDER BY engagement_rate DESC, total_views DESC
                LIMIT :limit
            """), {"exclude_ids": exclude_ids, "limit": limit})
        else:
            result = self.db.execute(text("""
                SELECT content_id, engagement_rate, total_views, total_likes
                FROM content_metrics
                ORDER BY engagement_rate DESC, total_views DESC
                LIMIT :limit
            """), {"limit": limit})

        return [dict(row._mapping) for row in result]

    def get_content_features(self, content_ids: list[int]) -> list[dict]:
        """
        Returns feature vectors for a list of content IDs from content_metrics.
        Used by the feature engineering service to build the model input.
        """
        if not content_ids:
            return []

        result = self.db.execute(text("""
            SELECT content_id, total_views, total_likes, total_bookmarks,
                   total_shares, total_comments, avg_watch_time,
                   completion_rate, engagement_rate
            FROM content_metrics
            WHERE content_id = ANY(:content_ids)
        """), {"content_ids": content_ids})

        return [dict(row._mapping) for row in result]

    def get_all_content_ids(self, limit: int = 1000) -> list[int]:
        """Returns all available content IDs (for candidate pool)."""
        result = self.db.execute(text("""
            SELECT content_id FROM content_metrics
            ORDER BY updated_at DESC
            LIMIT :limit
        """), {"limit": limit})
        return [row[0] for row in result]
