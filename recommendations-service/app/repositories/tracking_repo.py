from sqlalchemy.orm import Session
from sqlalchemy import text
import logging

logger = logging.getLogger(__name__)


class TrackingRepository:
    """Reads tracking event data from the shared Postgres database."""

    def __init__(self, db: Session):
        self.db = db

    def get_user_interactions(self, user_id: int, limit: int = 200):
        """Returns recent tracking events for a given user."""
        result = self.db.execute(text("""
            SELECT content_id, event_type, event_value, created_at
            FROM tracking_events
            WHERE user_id = :user_id
            ORDER BY created_at DESC
            LIMIT :limit
        """), {"user_id": user_id, "limit": limit})
        return [dict(row._mapping) for row in result]

    def get_interacted_content_ids(self, user_id: int) -> list[int]:
        """Returns distinct content IDs the user has interacted with (for exclusion)."""
        result = self.db.execute(text("""
            SELECT DISTINCT content_id
            FROM tracking_events
            WHERE user_id = :user_id
        """), {"user_id": user_id})
        return [row[0] for row in result]

    def get_user_positive_content_ids(self, user_id: int) -> list[int]:
        """Returns content IDs the user liked, bookmarked, or watched significantly."""
        result = self.db.execute(text("""
            SELECT DISTINCT content_id
            FROM tracking_events
            WHERE user_id = :user_id
              AND event_type IN ('like', 'bookmark', 'view')
        """), {"user_id": user_id})
        return [row[0] for row in result]

    def count_user_events(self, user_id: int) -> int:
        """Returns total event count for a user (used for cold start detection)."""
        result = self.db.execute(text("""
            SELECT COUNT(*) FROM tracking_events WHERE user_id = :user_id
        """), {"user_id": user_id})
        return result.scalar() or 0
